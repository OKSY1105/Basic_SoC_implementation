#!/usr/bin/env bash
# USB devices for Ubuntu on WSL2 through usbipd-win. WSL2 has no direct USB
# access; this script calls the host's usbipd.exe from Ubuntu (WSL interop)
# so that the board and the USB-UART adapter are used from Ubuntu only.
# Usage: bash scripts/wsl_usb.sh list
#        bash scripts/wsl_usb.sh attach VID:PID|BUSID   (Zybo JTAG/UART = 0403:6010)
#        bash scripts/wsl_usb.sh detach VID:PID|BUSID
#        bash scripts/wsl_usb.sh node VID:PID           (attached device's /dev/bus/usb node
#                                                        must be writable by this user)
#   USBIPD  usbipd.exe path (default /mnt/c/Program Files/usbipd-win/usbipd.exe)
# A new device must be shared once in usbipd-win before its first attach; that
# step needs Windows administrator rights (usbipd bind --busid BUSID). attach
# and detach need no administrator rights. attach waits until the device shows
# in /sys/bus/usb/devices. While attached, the device is not usable on Windows,
# and it is detached when the WSL virtual machine stops.
set -u
U=${USBIPD:-"/mnt/c/Program Files/usbipd-win/usbipd.exe"}

die() { echo "ERROR: $*" >&2; exit 1; }
[ -x "$U" ] || die "usbipd.exe not found: $U (install usbipd-win on the host)"

usbipd_list() { "$U" list 2>/dev/null | tr -d '\r'; }

# Lines of the "Connected:" section only.
connected() { usbipd_list | awk '/^Connected:/ {c = 1; next} /^Persisted:/ {c = 0} c && $1 ~ /^[0-9]+-[0-9.]+$/'; }

in_wsl() {  # VID:PID visible in WSL?
    local d
    for d in /sys/bus/usb/devices/*; do
        [ -f "$d/idVendor" ] || continue
        [ "$(cat "$d/idVendor"):$(cat "$d/idProduct")" = "$1" ] && return 0
    done
    return 1
}

resolve() {  # VID:PID or BUSID -> "BUSID VID:PID state-line"
    local key=$1 lines n
    if [[ $key =~ ^[0-9]+-[0-9.]+$ ]]; then
        lines=$(connected | awk -v k="$key" '$1 == k')
    elif [[ $key =~ ^[0-9a-fA-F]{4}:[0-9a-fA-F]{4}$ ]]; then
        key=$(echo "$key" | tr 'A-F' 'a-f')
        lines=$(connected | awk -v k="$key" 'tolower($2) == k')
    else
        die "expected VID:PID (e.g. 0403:6010) or BUSID (e.g. 1-4), got '$key'"
    fi
    n=$(printf '%s' "$lines" | grep -c . || true)
    [ "$n" -ge 1 ] || die "no connected USB device matches '$1' (bash scripts/wsl_usb.sh list)"
    [ "$n" -eq 1 ] || die "several devices match '$1'; use the BUSID: $(echo "$lines" | awk '{print $1}' | tr '\n' ' ')"
    echo "$lines"
}

cmd=${1:-}
case "$cmd" in
    list)
        echo "== usbipd-win (host)"
        usbipd_list
        echo "== visible in WSL"
        for d in /sys/bus/usb/devices/*; do
            [ -f "$d/idVendor" ] && echo "$(cat "$d/idVendor"):$(cat "$d/idProduct") $(cat "$d/product" 2>/dev/null)"
        done
        ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || true
        ;;
    attach)
        [ $# -eq 2 ] || die "usage: bash scripts/wsl_usb.sh attach VID:PID|BUSID"
        line=$(resolve "$2") || exit 1
        busid=$(echo "$line" | awk '{print $1}')
        vidpid=$(echo "$line" | awk '{print tolower($2)}')
        if in_wsl "$vidpid"; then echo "WSL_USB_ATTACHED busid=$busid vidpid=$vidpid (already)"; exit 0; fi
        case "$line" in
            *"Not shared"*) die "device $busid ($vidpid) is not shared in usbipd-win. Once, in an administrator PowerShell: usbipd bind --busid $busid" ;;
        esac
        "$U" attach --wsl --busid "$busid" || die "usbipd attach --wsl --busid $busid failed"
        for _ in $(seq 1 40); do in_wsl "$vidpid" && break; sleep 0.25; done
        in_wsl "$vidpid" || die "device $busid ($vidpid) is not visible in WSL after attach"
        sleep 1                     # let udev set up the device nodes
        echo "WSL_USB_ATTACHED busid=$busid vidpid=$vidpid"
        ;;
    detach)
        [ $# -eq 2 ] || die "usage: bash scripts/wsl_usb.sh detach VID:PID|BUSID"
        line=$(resolve "$2") || exit 1
        busid=$(echo "$line" | awk '{print $1}')
        vidpid=$(echo "$line" | awk '{print tolower($2)}')
        "$U" detach --busid "$busid" || die "usbipd detach --busid $busid failed"
        for _ in $(seq 1 40); do in_wsl "$vidpid" || break; sleep 0.25; done
        in_wsl "$vidpid" && die "device $busid ($vidpid) is still visible in WSL after detach"
        echo "WSL_USB_DETACHED busid=$busid vidpid=$vidpid"
        ;;
    node)
        # Programs such as the Vivado hw_server run as this user, so the
        # attached device's USB node must be writable (a udev rule does this).
        [ $# -eq 2 ] || die "usage: bash scripts/wsl_usb.sh node VID:PID"
        [[ $2 =~ ^[0-9a-fA-F]{4}:[0-9a-fA-F]{4}$ ]] || die "expected VID:PID, got '$2'"
        vidpid=$(echo "$2" | tr 'A-F' 'a-f')
        node=""
        for d in /sys/bus/usb/devices/*; do
            [ -f "$d/idVendor" ] || continue
            [ "$(cat "$d/idVendor"):$(cat "$d/idProduct")" = "$vidpid" ] || continue
            node=$(printf '/dev/bus/usb/%03d/%03d' "$(cat "$d/busnum")" "$(cat "$d/devnum")")
        done
        [ -n "$node" ] || die "$vidpid is not attached to WSL (bash scripts/wsl_usb.sh attach $vidpid)"
        for _ in $(seq 1 20); do [ -w "$node" ] && break; sleep 0.25; done
        if [ ! -w "$node" ]; then
            vb=${VIVADO_BIN:-/home/sean/Vivado/2024.2/bin}
            echo "ERROR: $node ($vidpid) is not writable by $(id -un): $(ls -l "$node")" >&2
            echo "Add a udev rule for the device once. For Xilinx/Digilent JTAG cables (copies three rule files to /etc/udev/rules.d):" >&2
            echo "  cd $vb/../data/xicom/cable_drivers/lin64/install_script/install_drivers && sudo ./install_drivers" >&2
            echo "then attach again: bash scripts/wsl_usb.sh detach $vidpid && bash scripts/wsl_usb.sh attach $vidpid" >&2
            exit 1
        fi
        echo "WSL_USB_NODE $node vidpid=$vidpid writable_by=$(id -un)"
        ;;
    *)
        sed -n '2,15p' "$0"
        exit 1
        ;;
esac
