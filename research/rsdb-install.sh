#!/usr/bin/env bash
set -Eeuo pipefail
KVER=7.3.4-300.fc45.x86_64
[[ $EUID = 0 && $(uname -r) = "$KVER" ]] || { echo "Run as root on $KVER"; exit 1; }
DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="/usr/lib/modules/$KVER/updates/kait2en-wireless"
BACKUP="/var/lib/kait2en-rsdb-diagnostics/$KVER"
modules=(brcmutil brcmfmac brcmfmac-wcc brcmfmac-cyw brcmfmac-bca)
restore() {
    for m in "${modules[@]}"; do
        [[ -f "$BACKUP/$m.ko.xz" ]] || return 1
    done
    for m in "${modules[@]}"; do
        install -m644 "$BACKUP/$m.ko.xz" "$TARGET/$m.ko.xz"
    done
    depmod -a "$KVER"
    dracut --force "/boot/initramfs-$KVER.img" "$KVER"
}
case "${1:-}" in
install)
    (cd "$DIR" && sha256sum -c SHA256SUMS)
    [[ ! -e "$BACKUP" ]] || { echo "Backup already exists; rollback first"; exit 1; }
    for m in "${modules[@]}"; do
        [[ -f "$TARGET/$m.ko.xz" && -f "$DIR/modules/$m.ko.xz" ]]
        [[ "$(modinfo -F vermagic "$DIR/modules/$m.ko.xz")" = "$KVER "* ]]
    done
    mkdir -p "$BACKUP"
    for m in "${modules[@]}"; do
        cp -p "$TARGET/$m.ko.xz" "$BACKUP/"
    done
    (cd "$BACKUP" && sha256sum *.ko.xz > SHA256SUMS)
    install -m755 "$DIR/rsdb-install.sh" "$BACKUP/rollback.sh"
    trap 'echo "Installation failed; attempting restoration" >&2; restore || echo "Manual rollback required" >&2' ERR
    for m in "${modules[@]}"; do
        install -m644 "$DIR/modules/$m.ko.xz" "$TARGET/$m.ko.xz"
    done
    depmod -a "$KVER"
    dracut --force "/boot/initramfs-$KVER.img" "$KVER"
    trap - ERR
    echo "Installed. Reboot with Ethernet available. Offline rollback: sudo $BACKUP/rollback.sh rollback"
    ;;
rollback)
    (cd "$BACKUP" && sha256sum -c SHA256SUMS)
    restore
    echo "Original modules restored. Reboot. Backup retained at $BACKUP."
    ;;
*) echo "Usage: $0 install|rollback"; exit 2;;
esac
