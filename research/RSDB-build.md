# BCM4364 RSDB diagnostic build 1

Exact Fedora 45 kernel 7.3.4-300.fc45.x86_64; pinned KaiT2en commit
ba0f3f6ebd510f742f6165b13d2fce13ddda6977; 27 installed patch hashes enforced.
Source RPM + kernel-devel from Fedora Koji. Diagnostic changes only:
allowlisted lifecycle firmware command and IOVAR status logging; scalar
chanspec/apsta values when exactly 4 bytes. RSDB mode ABI is not assumed.
No new firmware reads or writes, no radio/regulatory changes, no raw
security buffers. Existing driver may have unrelated verbose debugging;
do not enable FIL hex-dump logging.

The five Wi-Fi modules are rebuilt as a set. No Bluetooth, NetworkManager
or persistent KaiT2en hook changes. Unsigned experimental modules; existing
custom module acceptance/signing policy still applies. Do not disable
Secure Boot or change kernel policy to install. Build success is not
hardware validation. Use wired fallback and know how to boot a previous
kernel or rescue environment before installation. No module hot unload.
Verify SHA256SUMS and review generated patch before installation.

    sudo bash rsdb-install.sh install
    sudo reboot

Recreate ap0 after reboot if absent:
    sudo iw dev wlp5s0 interface add ap0 type __ap
    sudo ip link set ap0 up
    sudo nmcli device set ap0 managed yes

Test working SCC then failing cross-band once. After each test:
    iw dev
    iw dev wlp5s0 link
    sudo journalctl -k -b --no-pager | grep KAI_RSDB

Offline rollback:
    sudo /var/lib/kait2en-rsdb-diagnostics/7.3.4-300.fc45.x86_64/rollback.sh rollback
    sudo reboot

Rollback preserves backup. To reinstall after successful rollback, manually
archive the backup directory first. If boot fails, use another kernel or
rescue environment and restore the five backed-up files to the original
module directory for the target kernel, then depmod and regenerate its
initramfs. The script intentionally rejects other running kernels.
