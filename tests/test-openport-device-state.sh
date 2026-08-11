#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT HUP INT TERM

mkdir -p "$test_root/bin" "$test_root/sysfs" "$test_root/prefix"
trace_file=$test_root/regedit.trace
cat >"$test_root/bin/fake-wine" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$TRACE_FILE"
case "$*" in 'reg query '*) exit 1 ;; esac
EOF
chmod +x "$test_root/bin/fake-wine"

run_sync() {
    TRACE_FILE="$trace_file" \
    ECUFLASH_WINE="$test_root/bin/fake-wine" \
    ECUFLASH_WINEPREFIX="$test_root/prefix" \
    OPENPORT_REGISTRY_DIR="$repo_root/wine-bridge" \
    OPENPORT_USB_SYSFS_ROOT="$test_root/sysfs" \
        "$repo_root/linux/sync-openport-device-state"
}

state=$(run_sync)
[ "$state" = disconnected ]
grep -q 'openport2-device-absent.reg$' "$trace_file"

mkdir -p "$test_root/sysfs/1-2"
printf '%s\n' 0403 >"$test_root/sysfs/1-2/idVendor"
printf '%s\n' cc4d >"$test_root/sysfs/1-2/idProduct"
state=$(run_sync)
[ "$state" = connected ]
tail -1 "$trace_file" | grep -q 'openport2-device-present.reg$'

if grep -q 'CurrentControlSet\\Enum\\USB' "$repo_root/wine-bridge/openport2-wine.reg" \
   "$repo_root/wine-bridge/openport-driver-wine.reg"; then
    echo 'Static bridge registry must not enumerate a USB device.' >&2
    exit 1
fi
grep -q '^\[-HKEY_LOCAL_MACHINE.*CurrentControlSet\\Enum\\USB\\VID_0403&PID_CC4D\]$' \
    "$repo_root/wine-bridge/openport2-device-absent.reg"
if grep -q '272&256' "$repo_root/wine-bridge/openport2-device-absent.reg"; then
    echo 'Disconnected cleanup must not depend on a machine-specific USB instance.' >&2
    exit 1
fi

# Cached descriptors can survive unplug. Reuse requires membership in libusb's
# current device list, not merely readable descriptor metadata.
grep -q 'libusb_get_device_list' "$repo_root/wine-bridge/openport_unixlib.c"
grep -q 'devices\[i\] == opened' "$repo_root/wine-bridge/openport_unixlib.c"
grep -q 'libusb_open(devices\[i\], &usb_device)' "$repo_root/wine-bridge/openport_unixlib.c"
grep -q 'openport: found 0403:cc4d.*open=%d' "$repo_root/wine-bridge/openport_unixlib.c"
if grep -q 'libusb_get_device_descriptor(libusb_get_device(usb_device)' \
    "$repo_root/wine-bridge/openport_unixlib.c"; then
    echo 'Stale-handle validation still relies on cached USB descriptor metadata.' >&2
    exit 1
fi

echo 'OpenPort physical-device state tests passed.'

# A running EcuFlash session must synchronize Wine once when physical USB state
# changes. EcuFlash itself does not refresh its cached Task Info until restart.
monitor_sysfs=$test_root/monitor-sysfs
monitor_log=$test_root/monitor.log
monitor_trace=$test_root/monitor.trace
mkdir -p "$monitor_sysfs"
cat >"$test_root/bin/fake-sync" <<'EOF'
#!/bin/sh
printf 'sync\n' >>"$MONITOR_TRACE"
EOF
chmod +x "$test_root/bin/fake-sync"
MONITOR_TRACE="$monitor_trace" OPENPORT_USB_SYSFS_ROOT="$monitor_sysfs" \
OPENPORT_POLL_SECONDS=0.05 OPENPORT_INITIAL_STATE=disconnected \
OPENPORT_REGISTRY_DIR="$repo_root/wine-bridge" OPENPORT_STATE_LOG="$monitor_log" \
OPENPORT_STATE_SYNC="$test_root/bin/fake-sync" \
ECUFLASH_WINE="$test_root/bin/fake-wine" ECUFLASH_WINEPREFIX="$test_root/prefix" \
    "$repo_root/linux/monitor-openport-state" &
monitor_pid=$!
mkdir -p "$monitor_sysfs/2-1"
printf '%s\n' 0403 >"$monitor_sysfs/2-1/idVendor"
printf '%s\n' cc4d >"$monitor_sysfs/2-1/idProduct"
attempt=0
while [ ! -s "$monitor_trace" ] && [ "$attempt" -lt 40 ]; do
    sleep 0.05
    attempt=$((attempt + 1))
done
kill "$monitor_pid" 2>/dev/null || true
wait "$monitor_pid" 2>/dev/null || true
[ "$(grep -c '^sync$' "$monitor_trace")" -eq 1 ]
grep -q 'disconnected -> connected' "$monitor_log"

echo 'OpenPort live-state monitor tests passed.'

# A clean install adds uucp after setup has already started. Its immediate
# hardware probe must enter the new group instead of failing until next login.
grep -q '^run_with_openport_access()' "$repo_root/linux/install-cachyos.sh"
[ "$(grep -c 'run_with_openport_access env WINEPREFIX=' "$repo_root/linux/install-cachyos.sh")" -eq 6 ]
grep -q 'TAG+="uaccess"' "$repo_root/linux/99-openport2.rules"
grep -q '^openport_raw_access_state()' "$repo_root/linux/launch-ecuflash"
grep -q 'OPENPORT_USB_SYSFS_ROOT' "$repo_root/linux/launch-ecuflash"
grep -q 'OPENPORT_USB_DEV_ROOT' "$repo_root/linux/launch-ecuflash"
grep -q 'Desktop uaccess did not grant access.*uucp fallback group' \
    "$repo_root/linux/launch-ecuflash"
if grep -q '^if ! id -nG.*grep -qx uucp' "$repo_root/linux/launch-ecuflash"; then
    echo 'EcuFlash launcher still treats uucp membership as mandatory.' >&2
    exit 1
fi
grep -q '^openport_raw_access_state()' "$repo_root/linux/launch-romraider"
grep -q 'Desktop uaccess did not grant access.*uucp fallback group' \
    "$repo_root/linux/launch-romraider"
grep -q '^openport_usb_accessible()' "$repo_root/linux/install-cachyos.sh"
grep -q '^openport_usb_node()' "$repo_root/linux/install-cachyos.sh"
grep -q '^verify_openport_usb_access()' "$repo_root/linux/install-cachyos.sh"
grep -q '^wait_for_openport_state()' "$repo_root/linux/install-cachyos.sh"
grep -q '^verify_openport_hotplug_cycle()' "$repo_root/linux/install-cachyos.sh"
grep -q 'OpenPort plug/unplug detection passed' "$repo_root/linux/install-cachyos.sh"
grep -q 'sudo cmp -s.*99-openport2.rules' "$repo_root/linux/install-cachyos.sh"
grep -q 'sudo udevadm settle --timeout=10' "$repo_root/linux/install-cachyos.sh"
grep -q 'udev grants effective read/write access to the connected OpenPort' \
    "$repo_root/linux/install-cachyos.sh"
grep -q 'Current session has raw read/write OpenPort access' \
    "$repo_root/linux/install-cachyos.sh"
if grep -q 'user is not in uucp group (required by the Logger shortcut)' \
    "$repo_root/linux/install-cachyos.sh"; then
    echo 'System check still treats uucp membership as mandatory.' >&2
    exit 1
fi
grep -q '^"HardwareId"=hex(7):' "$repo_root/wine-bridge/openport2-device-present.reg"
grep -q '^"CompatibleIDs"=hex(7):' "$repo_root/wine-bridge/openport2-device-present.reg"
grep -q '^"ConfigFlags"=dword:00000000$' "$repo_root/wine-bridge/openport2-device-present.reg"
grep -q 'capture_openport_device_probe' "$repo_root/linux/install-cachyos.sh"
grep -q 'create_standalone_device' "$repo_root/wine-bridge/openport_driver.c"
grep -q 'IoCreateSymbolicLink' "$repo_root/wine-bridge/openport_driver.c"
grep -q 'Wine may enumerate the registry interface without ever delivering' \
    "$repo_root/wine-bridge/openport_driver.c"

echo 'OpenPort first-login access tests passed.'
