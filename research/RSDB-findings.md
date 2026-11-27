# RSDB hardware findings (2026-11-27)

Device: Apple BCM4364, Fedora 45, KaiT2en wireless patch series through 0027.
Firmware cap includes rsdb, dualband, ap, sta, hp2p, awdl. Driver feature
mask 040c38a4 includes RSDB; no MCHAN, MBSS or standard P2P.
The whole-word capability patch is correct: hp2p is not standard P2P.
Debugfs is mounted; actual entries are ieee80211/phy0/{features,fwcap}.
CONFIG_BRCMDBG and CONFIG_BRCM_TRACING are disabled in Fedora kernel config.

Reproduction:
- 5GHz ch36/80 STA + 2.4GHz ch6/20 AP: SSID invisible, both interfaces
  temporarily report ch6, later STA reports ch36 again.
- 2.4GHz ch9/20 STA verified by association and 5/5 router ping, followed
  by 5GHz ch36/80 AP: STA becomes unassociated and both interfaces report
  ch36. Router ping recovers after disruption (5/10 replies); no AP
  stations and SSID invisible. NetworkManager reports both active.
- Standalone virtual AP with Ethernet and SCC ch36/80 remain validated.
These findings are not proof of physical beacon absence (no independent
packet capture) or a hardware limitation. Same-band MCHAN remains unproven.

Upstream source audit (not yet exact Fedora/KaiT2en source):
- feature.c detects RSDB by probing rsdb_mode; feature flag is not a
  measurement of active independent radio operation.
- cfg80211.c start_ap skips the global DOWN/apsta=0 branch for secondary
  RSDB AP, but still issues SET_AP, chanspec, UP, SET_SSID. Inspect those
  operations and readback, not just the DOWN branch.
- request_ap_if tries multiple interface_create ABI versions; identify
  which succeeds and whether firmware assigns a separate core/BSS.
- stop_ap issues DOWN, SET_AP=0, UP on ordinary AP paths; test fresh boot
  and activation order to separate stale state from start-path defects.

Next: obtain exact installed wireless module build script/source provenance.
Instrument scalar-only readbacks of rsdb_mode, apsta, chanspec on primary
and AP around the AP start operations, with return codes, ifidx and
bsscfgidx. Verify ABI before interpreting any returned RSDB data.
No changes to firmware settings or force-enabling features before that.
Do not log security material or raw firmware buffers.

Sources:
https://codebrowser.dev/linux/linux/drivers/net/wireless/broadcom/brcm80211/brcmfmac/feature.c.html
https://codebrowser.dev/linux/linux/drivers/net/wireless/broadcom/brcm80211/brcmfmac/cfg80211.c.html
