#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KVER=7.3.4-300.fc45.x86_64
VER=7.3.4
REL=300.fc45
UPSTREAM=ba0f3f6ebd510f742f6165b13d2fce13ddda6977
KOJI="https://kojipkgs.fedoraproject.org/packages/kernel/$VER/$REL"
W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
OUT="$ROOT/out"
mkdir -p "$OUT/modules" "$W/srpm" "$W/unpacked"
dnf5 -y install gcc make git-core patch cpio curl elfutils-libelf-devel \
    openssl-devel flex bison bc perl python3 tar xz kmod binutils rpm-build dwarves
curl --fail --retry 3 -L "$KOJI/x86_64/kernel-devel-$KVER.rpm" -o "$W/devel.rpm"
dnf5 -y install "$W/devel.rpm"
curl --fail --retry 3 -L "$KOJI/src/kernel-$VER-$REL.src.rpm" -o "$W/source.rpm"
(cd "$W/srpm" && rpm2cpio "$W/source.rpm" | cpio -idm --quiet)
tarball=$(find "$W/srpm" -maxdepth 1 -name 'linux-*.tar.xz' -print -quit)
redhat=$(find "$W/srpm" -maxdepth 1 -name 'patch-*-redhat.patch' -print -quit)
[[ -f "$tarball" && -f "$redhat" ]]
tar -xf "$tarball" -C "$W/unpacked"
tree=$(find "$W/unpacked" -mindepth 1 -maxdepth 1 -type d -print -quit)
git -C "$tree" apply "$redhat"
git init "$W/upstream"
git -C "$W/upstream" fetch --depth=1 https://github.com/kaiT2en/KaiT2en-Fedora.git "$UPSTREAM"
git -C "$W/upstream" checkout --detach FETCH_HEAD
patchdir="$W/upstream/patches/runtime/wireless"
mapfile -t patches < <(grep -vE '^$|^#' "$patchdir/series")
mapfile -t hashes < "$ROOT/research/installed-patch-hashes.txt"
[[ "${#patches[@]}" = 27 && "${#hashes[@]}" = 27 ]]
for i in "${!patches[@]}"; do
    p="${patches[i]}"
    [[ "$p" =~ ^[0-9]{4}-[A-Za-z0-9._-]+\.patch$ ]]
    [[ "$p" == "$(printf '%04d' "$((i+1))")-"* ]]
    printf '%s  %s\n' "${hashes[i]}" "$patchdir/$p" | sha256sum -c -
    if patch -d "$tree" -p1 --dry-run --batch --forward --fuzz=3 --no-backup-if-mismatch < "$patchdir/$p" >/dev/null; then
        patch -d "$tree" -p1 --batch --forward --fuzz=3 --no-backup-if-mismatch < "$patchdir/$p"
    elif patch -d "$tree" -p1 --dry-run --batch --reverse --fuzz=3 --no-backup-if-mismatch < "$patchdir/$p" >/dev/null; then
        echo "Already present: $p"
    else
        echo "Patch mismatch: $p" >&2; exit 1
    fi
done
broad="$tree/drivers/net/wireless/broadcom/brcm80211"
cp "$broad/brcmfmac/fwil.c" "$W/fwil.original"
python3 "$ROOT/research/instrument-rsdb.py" "$broad/brcmfmac"
diff -u --label a/drivers/net/wireless/broadcom/brcm80211/brcmfmac/fwil.c "$W/fwil.original" \
    --label b/drivers/net/wireless/broadcom/brcm80211/brcmfmac/fwil.c "$broad/brcmfmac/fwil.c" \
    > "$OUT/rsdb-diagnostics.patch" || [[ $? = 1 ]]
headers="/usr/src/kernels/$KVER"
[[ -r "$headers/.config" ]]
make -j"$(nproc)" -C "$headers" M="$broad/brcmutil" CONFIG_BRCMDBG=y 'KCPPFLAGS=-DDEBUG -DCONFIG_BRCMDBG=1' modules
make -j"$(nproc)" -C "$headers" M="$broad/brcmfmac" \
    KBUILD_EXTRA_SYMBOLS="$broad/brcmutil/Module.symvers" CONFIG_BRCMDBG=y 'KCPPFLAGS=-DDEBUG -DCONFIG_BRCMDBG=1' modules
for mod in brcmutil/brcmutil.ko brcmfmac/brcmfmac.ko brcmfmac/wcc/brcmfmac-wcc.ko brcmfmac/cyw/brcmfmac-cyw.ko brcmfmac/bca/brcmfmac-bca.ko; do
    [[ "$(modinfo -F vermagic "$broad/$mod")" == "$KVER "* ]]
    install -m644 "$broad/$mod" "$OUT/modules/"
    strip --strip-debug "$OUT/modules/${mod##*/}"
    xz --check=crc32 --lzma2=dict=1MiB "$OUT/modules/${mod##*/}"
done
cp "$ROOT/research/rsdb-install.sh" "$OUT/"
cp "$ROOT/research/RSDB-build.md" "$OUT/README.md"
printf 'kernel=%s\nupstream=%s\n' "$KVER" "$UPSTREAM" > "$OUT/build-info.txt"
(cd "$OUT" && sha256sum modules/*.ko.xz rsdb-install.sh rsdb-diagnostics.patch README.md build-info.txt > SHA256SUMS)
