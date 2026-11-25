#!/usr/bin/env python3
"""Generate a narrowly scoped, fail-closed brcmfmac AP workaround.

Based on the PureOS/postmarketOS approach. Only optional-PMF WPA-PSK
AP configurations on brcmfmac are affected; required PMF and STA
configurations retain their upstream behavior.
"""
import difflib
import re
import sys
from pathlib import Path

root = Path.cwd()
symbol = "nm_supplicant_config_add_setting_wireless_security"
config = root / "src/core/supplicant/nm-supplicant-config.c"
header = root / "src/core/supplicant/nm-supplicant-config.h"
wifi = root / "src/core/devices/wifi/nm-device-wifi.c"
assert all(p.is_file() for p in (config, header, wifi)), "Unexpected source layout"
changes = {}
seen = {}
for p in (root / "src").rglob("*"):
    if p.suffix not in (".c", ".h"):
        continue
    old = p.read_text()
    matches = list(re.finditer(r"\b" + symbol + r"\s*\(", old))
    if not matches:
        continue
    new = old
    for m in reversed(matches):
        start = m.end()
        depth = 1
        end = start
        while depth:
            c = old[end]
            depth += (c == "(") - (c == ")")
            end += 1
        args = old[start:end-1]
        comma = args.rfind(",")
        assert comma >= 0, (p, args)
        final = args[comma+1:].strip()
        if p in (config, header):
            assert re.fullmatch(r"GError\s*\*\s*\*\s*error", final), (p, final)
            insert = "gboolean quirk_is_brcmfmac"
        else:
            assert re.fullmatch(r"(?:&?\w+|NULL)", final), (p, final)
            insert = ('nm_streq0(nm_device_get_driver(NM_DEVICE(self)), "brcmfmac")'
                      if p == wifi else "FALSE")
        # Reuse the whitespace immediately following the final comma.
        whitespace = re.match(r"\s*", args[comma+1:]).group()
        replacement = args[:comma+1] + whitespace + insert + "," + args[comma+1:]
        new = new[:start] + replacement + new[end-1:]
    seen[p] = len(matches)
    if p == config:
        pattern = (r"if \(_get_capability\(priv, NM_SUPPL_CAP_TYPE_PMF\)\)"
                   r"(?=\s*g_string_append\(key_mgmt_conf, \" WPA-PSK-SHA256\"\);)")
        new, count = re.subn(
            pattern,
            "if (!(is_ap && quirk_is_brcmfmac\n"
            "                  && pmf != NM_SETTING_WIRELESS_SECURITY_PMF_REQUIRED)\n"
            "                && _get_capability(priv, NM_SUPPL_CAP_TYPE_PMF))",
            new,
        )
        assert count == 1, "WPA-PSK-SHA256 condition changed; manual review required"
        assert "is_ap =" in new
    changes[p] = (old, new)
assert all(seen.get(p) == 1 for p in (config, header, wifi)), seen
patch = []
for p, (old, new) in sorted(changes.items()):
    rel = p.relative_to(root).as_posix()
    patch.extend(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
                                     "a/" + rel, "b/" + rel))
assert patch, "Empty patch"
out = Path(sys.argv[1])
out.write_text("".join(patch))
for p, (_, new) in changes.items():
    p.write_text(new)
print("Applied brcmfmac AP compatibility changes:")
print("".join(patch))
