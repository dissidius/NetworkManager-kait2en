# NetworkManager-kait2en

Experimental Fedora 45 compatibility build for Apple T2 Broadcom Wi-Fi AP mode.

## Background
On BCM4364, conventional WPA2-PSK/CCMP with hostapd and a NetworkManager shared bridge works, including DHCP and internet access. Mixed WPA-PSK/WPA-PSK-SHA256 repeatedly fails during the four-way handshake. SHA256 alone has completed a handshake once; its isolated reliability remains unverified. This is a diagnostic workaround, not a proven root-cause fix.

The approach is informed by the [postmarketOS brcmfmac AP quirk](https://git.mrlokop.dev/MRLokop/pmaports/commit/260c54a893995f0c0b9d10d33a78215409a36ef4) and [PureOS](https://source.puri.sm/pureos/packages/network-manager/-/blob/pureos/latest/debian/patches/pureos/wifi-Disable-WPA-PSK-SHA256-in-AP-mode.patch). The generated change suppresses the extra SHA256 AKM for brcmfmac in WPA-PSK AP mode when PMF is not required. It does not change client mode, required-PMF configurations, or other drivers. Scope is driver-wide, not yet Apple PCI-ID-specific.

## CI
The workflow targets Fedora 45 x86_64, using the exact distribution source RPM (NetworkManager 1.58.1-3.fc45), Fedora's existing patches, and the normal RPM build/tests. The transformation fails on unexpected source structure. Build artifacts include the actual generated source diff, modified source RPM, patched daemon and Wi-Fi plugin, matching stock daemon/plugin for rollback, checksums and build log.

For the initial experiment only, the patched RPMs intentionally retain the stock NEVR so the existing x86_64 and i686 libnm packages and other plugins remain compatible. Do not distribute this as an ordinary package update. A production release requires a distinct version and a multilib-compatible packaging strategy.

## Testing / installation
Do not install until the CI build succeeds and the generated patch has been reviewed. Keep a wired connection and the stock rollback packages locally; do not replace NetworkManager or Wi-Fi packages remotely over the affected Wi-Fi link. Only test on the exact matching Fedora version and architecture. Experimental RPMs are unsigned; SHA256 checksums detect corruption, not provenance. Official Fedora updates can replace this experiment.

The first objective is native GNOME hotspot operation; simultaneous Wi-Fi/AP and 5 GHz are separate tests. No personal logs, Wi-Fi passwords or MAC addresses are included in this repository.
