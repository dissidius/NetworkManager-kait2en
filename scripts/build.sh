#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root=$PWD
nvr=1.58.1-3.fc45
top="$root/work/rpmbuild"
mkdir -p "$top"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS} "$root/out"/{original,patched}
cd "$root/work"
dnf5 download --srpm "NetworkManager-$nvr"
srpm="$PWD/NetworkManager-$nvr.src.rpm"
test -s "$srpm"
rpm -qp --qf '%{NAME} %{VERSION}-%{RELEASE}\n' "$srpm" | grep -Fx "NetworkManager $nvr"
rpm -ivh --define "_topdir $top" "$srpm"
cp "$root/scripts/apply-quirk.py" "$top/SOURCES/kait2en-apply-quirk.py"
python3 - "$top/SPECS/NetworkManager.spec" <<'PY'
import re, sys
from pathlib import Path
p = Path(sys.argv[1])
s = p.read_text()
assert not re.search(r"(?im)^Source9999\s*:", s)
s, n = re.subn(r"(?im)^(Release\s*:[^\n]+)$",
               r"\1\nSource9999: kait2en-apply-quirk.py", s, count=1)
assert n == 1
prep = re.search(r"(?m)^%prep\s*$", s)
assert prep
end = re.search(r"(?m)^%(?:build|generate_buildrequires|install|check|package|description|files|clean|changelog)\b", s[prep.end():])
assert end
i = prep.end() + end.start()
s = s[:i] + '\npython3 "%{SOURCE9999}" "%{_topdir}/kait2en-generated.patch"\n\n' + s[i:]
p.write_text(s)
PY
dnf5 -y builddep "$srpm"
# Preserve the stock NVR for this experiment so the existing i686 libnm
# remains compatible. Only the daemon and Wi-Fi plugin will be installed.
cd "$root/out/original"
dnf5 download "NetworkManager-$nvr.x86_64" "NetworkManager-wifi-$nvr.x86_64"
for name in NetworkManager NetworkManager-wifi; do
    f="$PWD/$name-$nvr.x86_64.rpm"
    test -s "$f"
    rpm -qp --qf '%{NAME} %{VERSION}-%{RELEASE} %{ARCH}\n' "$f" | grep -Fx "$name $nvr x86_64"
done
cd "$root"
rpmbuild -ba --define "_topdir $top" "$top/SPECS/NetworkManager.spec" 2>&1 | tee "$root/out/build.log"
cp "$top/kait2en-generated.patch" "$root/out/"
for name in NetworkManager NetworkManager-wifi; do
    f="$top/RPMS/x86_64/$name-$nvr.x86_64.rpm"
    test -s "$f"
    cp "$f" "$root/out/patched/"
done
cp "$top/SRPMS/NetworkManager-$nvr.src.rpm" "$root/out/patched/"
cd "$root/out"
sha256sum original/*.rpm patched/*.rpm kait2en-generated.patch > SHA256SUMS
