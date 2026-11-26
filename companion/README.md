# KaiT2en Wi-Fi Companion (experimental v0.1)

Separate opt-in RPM; does not replace the tested NetworkManager authentication build.
Only Apple BCM4364 PCI 4464 with brcmfmac is accepted. No firmware, regulatory
country, driver parameter, password or primary connection changes.

## Hardware evidence

- Native 5 GHz/80 MHz WPA2 AP, channel 36: ~600 Mbps download over Ethernet.
- Secondary AP works standalone.
- STA channel 112 and AP channel 36: NM active, SSID invisible to phone.
- STA + AP both channel 36/80 MHz: connected phone, wireless-only internet
  ~150–280 Mbps download and ~110 Mbps upload. Separate links ~780–866 Mbps.
- MCC not established; cross-band and two non-DFS 5 GHz channels untested.

## Setup

Install the companion RPM only after CI and with Ethernet available. The
existing patched NetworkManager is required for the confirmed WPA2 workaround.
Keep the original NM RPMs for rollback. This companion is unsigned in CI.

The existing dedicated profile Hotspot-Concurrent is used by default. To set
up on a fresh machine, clone a known-good secure AP profile and bind the clone:
```sh
sudo nmcli connection clone Hotspot-5GHz Hotspot-Concurrent
sudo nmcli connection modify Hotspot-Concurrent connection.interface-name ap0 \
  802-11-wireless.cloned-mac-address preserve connection.autoconnect no \
  ipv4.method shared
```
Choose a distinct SSID and a strong password via GNOME or nm-connection-editor.
Do not publish screenshots showing passwords or QR codes.

Edit /etc/kait2en-wifi.conf if the interface/profile names differ. Verify the
actual country is configured correctly for your location (the service never
sets or overrides the regulatory domain). 5 GHz channels 36–48 are indoor-only
in Albania; use only where permitted. The first version allows 2.4 GHz 1–11
at 20 MHz, or 5 GHz 36–48 at matching 20/40/80 MHz, also checking reported
PHY channel restrictions. DFS, other channels and 160 MHz are deliberately
not synchronized. This is conservative, not a substitute for regulatory checks.

```sh
sudo /usr/libexec/kait2en-wifi --dry-run
sudo systemctl start kait2en-wifi.service
sudo journalctl -u kait2en-wifi.service -n 30 --no-pager
sudo systemctl enable --now kait2en-wifi.timer
```
The timer creates missing ap0 and prepares the named profile when the uplink
is connected. It does not automatically activate an inactive hotspot.
An active named profile is restarted if its saved channel needs updating;
clients will briefly disconnect. On an unsupported uplink it stops that
profile and leaves it off; it does not block manual activation during the
timer interval. Primary-interface APs and other active virtual profiles are
not managed. With no Wi-Fi uplink it leaves the user's profile untouched.

GNOME shows the virtual adapter as a second Wi-Fi device. Start/stop the
dedicated profile with nmcli if GNOME chooses a different saved hotspot:
```sh
sudo nmcli connection up Hotspot-Concurrent ifname ap0
sudo nmcli connection down Hotspot-Concurrent
```

The timer retries missing interfaces after reboot/resume. Actual hardware
resume, roaming races, initial creation timing and GNOME profile selection
are not yet validated; this is polling-based, not a native GNOME patch.
No automatic activation at startup. No automatic deletion of a user-owned
profile or interface on package removal.

## Stop / uninstall

```sh
sudo systemctl disable --now kait2en-wifi.timer
sudo systemctl stop kait2en-wifi.service
sudo dnf remove kait2en-wifi-companion
```
To remove the virtual interface too, if it is your dedicated test AP:
```sh
sudo nmcli connection down Hotspot-Concurrent
sudo iw dev ap0 del
```
Keep the saved profile for future testing or delete it explicitly. The original
Hotspot and Hotspot-5GHz profiles are untouched. Reboot also removes the
temporary interface when the timer is disabled.
