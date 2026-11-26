# BCM4364 multi-channel concurrency investigation

## Established evidence
Apple BCM4364, brcmfmac, patched NetworkManager 1.58.1-3.fc45.
Secondary AP works alone; STA+AP both ch36/80 works with traffic (150–280 Mbps
download, ~110 Mbps upload). STA ch112/80 + AP ch36/80 reports active but
the phone cannot discover the AP. One failure does not establish that every
form of MCC is broken.

## Driver audit
Upstream brcmfmac feature.h distinguishes MCHAN (concurrent P2P) and RSDB
(real simultaneous dual band). cfg80211.c advertises two channels when
RSDB or P2P+MCHAN is enabled. Two-channel support therefore does not establish
arbitrary simultaneous same-band channels.
Sources:
https://codebrowser.dev/linux/linux/drivers/net/wireless/broadcom/brcm80211/brcmfmac/feature.h.html
https://codebrowser.dev/linux/linux/drivers/net/wireless/broadcom/brcm80211/brcmfmac/cfg80211.c.html

In brcmf_cfg80211_start_ap inspect radio DOWN/APSTA conditions, secondary BSS
classification (mbss), chanspec setting and SET_SSID/BSS activation.
Compare exact loaded KaiT2en source and firmware capabilities first.
Next kernel experiment if needed: instrument ifidx, bsscfgidx, mbss, requested
chanspec and read-back chanspec after AP start, without logging key material.
No speculative firmware writes, regulatory bypass, feature forcing or module
replacement at this stage.

## Controlled tests (legal indoor channels)
Keep Ethernet connected for transitions. Stop companion timer/service if
installed. Clone Hotspot-Concurrent to Hotspot-MCC-Test; preserve baseline.
Verify phone discovery, association, local traffic and internet forwarding
with mobile data off and Ethernet disconnected after association.

| Case | STA | AP | Result |
|---|---|---|---|
| SCC baseline | 5 GHz 36/80 | 5 GHz 36/80 | Passed |
| Cross-band | 2.4 GHz | 5 GHz 36/80 | Pending |
| Cross-band reverse | 5 GHz 36/80 | 2.4 GHz 6/20 | Pending |
| Same-band control | 5 GHz 36/20 | 5 GHz 36/20 | Pending |
| Disjoint non-DFS | 5 GHz 44/20 | 5 GHz 36/20 | Pending |
| Reverse start order | same disjoint channels | AP first | Pending |
| Original failure | 5 GHz 112/80 | 5 GHz 36/80 | Invisible SSID |

Start cross-band without changing router. For disjoint non-DFS comparison,
temporarily configure router 44/20; restore 36/80 afterward.
Cross-band success narrows the issue to same-band operation but is not proof
of RSDB by itself. If needed, use an independent Wi-Fi adapter to capture
beacon presence and channel. Do not change kernel settings blindly.

## Capture
Run sudo bash research/collect-mcc.sh wlp5s0 ap0. No changes to system.
Review private SSIDs and MACs before sharing logs.
If debugfs is unavailable, report it.

## Rollback
Down the test profile and reconnect the validated 5GHz uplink and
Hotspot-Concurrent at channel 36/80. Delete only the test profile if desired.
