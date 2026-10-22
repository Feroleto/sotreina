# Sourced by deploy.sh/logs.sh. On WSL the iPhone stays on Windows (Apple
# Devices' usbmux service on 127.0.0.1:27015, exposed to WSL by a netsh
# portproxy; see README): usbipd + the WSL usbmuxd hangs on install. Point
# libimobiledevice/xtool at the Windows host unless the caller already chose.
if [[ -z "${USBMUXD_SOCKET_ADDRESS:-}" ]] && grep -qi microsoft /proc/version 2>/dev/null; then
    export USBMUXD_SOCKET_ADDRESS="$(ip route list default | awk '{print $3}'):27015"
fi
