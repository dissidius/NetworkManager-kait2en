#!/usr/bin/env python3
"""Fail-closed, diagnostics-only source instrumentation, no firmware writes."""
import pathlib
import re
import sys

p = pathlib.Path(sys.argv[1]) / "fwil.c"
old = p.read_text()
s = old

def insert_before_return(name, code, anchor="return err;"):
    global s
    m = re.search(r"(?m)^" + name + r"\s*\([^;]*?\)\s*\{", s)
    if not m:
        raise SystemExit("Missing function: " + name)
    end = re.search(r"(?m)^}", s[m.end():])
    if not end:
        raise SystemExit("Missing function end: " + name)
    a, b = m.end(), m.end() + end.start()
    body = s[a:b]
    key = "\t" + anchor
    if body.count(key) != 1:
        raise SystemExit("Ambiguous anchor: " + name)
    s = s[:a] + body.replace(key, code + "\n" + key, 1) + s[b:]

# Use the existing firmware transactions only. No added IOCTLs, no raw buffers.
insert_before_return("brcmf_fil_cmd_data", r'''
	/* KAI RSDB diagnostic: only radio/AP lifecycle commands. */
	if (cmd == BRCMF_C_UP || cmd == BRCMF_C_DOWN ||
	    cmd == BRCMF_C_SET_AP || cmd == BRCMF_C_SET_SSID ||
	    cmd == BRCMF_C_DISASSOC)
		pr_info("KAI_RSDB cmd if=%d bss=%d cmd=%u set=%d ret=%d\n",
			ifp->ifidx, ifp->bsscfgidx, cmd, set, err);
''', "if (ifp->fwil_fwerr)")
# Log named operations on both normal and bsscfg paths. Only scalar channel/
# mode values; RSDB ABI may use a struct, so report its length and status only.
for scope in ("iovar", "bsscfg"):
    for direction in ("set", "get"):
        code = r'''
	if (!strcmp(name, "chanspec") || !strcmp(name, "apsta") ||
	    !strcmp(name, "rsdb_mode") || !strcmp(name, "bss") ||
	    !strcmp(name, "interface_create") || !strcmp(name, "interface_remove") ||
	    !strcmp(name, "ssid") || !strcmp(name, "join")) {
		pr_info("KAI_RSDB SCOPE DIRECTION if=%d bss=%d name=%s len=%u ret=%d\n",
			ifp->ifidx, ifp->bsscfgidx, name, len, err);
		if (!err && data && len == sizeof(__le32) &&
		    (!strcmp(name, "chanspec") || !strcmp(name, "apsta"))) {
			__le32 scalar;
			memcpy(&scalar, data, sizeof(scalar));
			pr_info("KAI_RSDB SCOPE DIRECTION if=%d bss=%d name=%s value=0x%x\n",
				ifp->ifidx, ifp->bsscfgidx, name, le32_to_cpu(scalar));
		}
	}
'''.replace("SCOPE", scope).replace("DIRECTION", direction)
        insert_before_return("brcmf_fil_" + scope + "_data_" + direction, code)

p.write_text(s)
print("Instrumented existing firmware transactions in", p)
