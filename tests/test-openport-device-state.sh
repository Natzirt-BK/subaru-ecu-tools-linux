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
tail -1 "$trace_file" | grep -q 'openport2-device-absent.reg$'

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
grep -q '^\[-HKEY_LOCAL_MACHINE.*CurrentControlSet\\Enum\\USB' \
    "$repo_root/wine-bridge/openport2-device-absent.reg"

echo 'OpenPort physical-device state tests passed.'
