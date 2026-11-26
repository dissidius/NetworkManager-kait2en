#!/usr/bin/env bash
# Read-only; review identifying information before sharing.
set -u
export LC_ALL=C
sta="${1:-wlp5s0}"
ap="${2:-ap0}"
echo '=== Kernel and module ==='
uname -r
modinfo -F filename brcmfmac
modinfo -F vermagic brcmfmac
if command -v ethtool >/dev/null; then ethtool -i "$sta"; fi
echo '=== Firmware features (if exposed) ==='
for root in /sys/kernel/debug/brcmfmac /sys/kernel/debug/ieee80211; do
    [ -d "$root" ] || continue
    while IFS= read -r f; do
        printf '\n--- %s ---\n' "$f"
        cat "$f"
    done < <(find "$root" -maxdepth 5 -type f \( -name features -o -name fwcap \) 2>/dev/null)
done
echo '=== Module feature mask ==='
if [ -r /sys/module/brcmfmac/parameters/feature_disable ]; then
    cat /sys/module/brcmfmac/parameters/feature_disable
fi
echo '=== Wireless state ==='
iw dev
iw reg get
iw list
iw dev "$sta" link
iw dev "$ap" station dump
nmcli -f NAME,TYPE,DEVICE connection show --active
echo '=== Kernel messages ==='
journalctl -k -b --since '5 minutes ago' --no-pager | grep -iE 'brcmfmac|brcmf_|cfg80211|chanspec|bsscfg|mchan|rsdb|ap0' || :
echo 'Review SSIDs, MACs and other identifying details before sharing.'
