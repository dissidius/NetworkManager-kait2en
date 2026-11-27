# AP-first test and build provenance

Hardware test 2026-11-27: wlp5s0 manually disconnected, secondary AP
started on 5 GHz channel 36/80; then STA connected to 2.4 GHz channel
9/20. After 15 seconds iw showed both intended channels, actual STA
association at 2452 MHz, 144.4 Mbps RX/TX, and 10/10 gateway pings.
AP station dump was empty and phone no longer discovered the hotspot.
The activation order is not a sufficient workaround. No independent
beacon capture was made.

Kernel 7.3.4-300.fc45.x86_64, matching kernel-devel tree installed.
Module path updates/kait2en-wireless/brcmfmac.ko.xz. Debugfs revinfo:
BCM4364/0 (wcc), corerev 58, phyrev 26, boardid 0x081d, boardrev P770.
Installed builder at /usr/local/libexec/kait2en/wireless/{install-wireless.sh,lib.sh}.
Upstream main scripts/fedora/install-wireless.sh builds brcmutil, brcmfmac,
wcc/cyw/bca and selected Bluetooth modules; current upstream includes
CONFIG_BRCMDBG=y and KCPPFLAGS=-DDEBUG -DCONFIG_BRCMDBG=1.
Compare installed scripts and patch-series hashes before reproducing
this exact module build; upstream main may have changed since installation.

Historical RSDB support (8abffd8173a1c64eaa951f2527635c12b5a4ecc3)
describes firmware-managed RSDB except AP configuration. Do not assume
that writing rsdb_mode is needed or safe without checking ABI.
First instrument AP/STA command return codes and readbacks; preserve
stock regulatory restrictions and all KaiT2en changes. No driver build
or fix has been validated yet.

References:
https://github.com/kaiT2en/KaiT2en-Fedora/blob/main/scripts/fedora/install-wireless.sh
https://git.zx2c4.com/wireguard-linux/commit/?id=8abffd8173a1c64eaa951f2527635c12b5a4ecc3
