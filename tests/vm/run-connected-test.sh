#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "$0")/../.." && pwd)
launcher=${ECUFLASH_LAUNCHER:-$HOME/.local/bin/launch-ecuflash}
prefix=${XDG_DATA_HOME:-$HOME/.local/share}/ecuflash-proton
data_root=${XDG_DATA_HOME:-$HOME/.local/share}/subaru-ecu-tools-linux
wineserver=$data_root/runtime/ecuflash-winegdk-11.1/files/bin/wineserver
test_seconds=${ECUFLASH_CONNECTED_TEST_SECONDS:-20}
runtime_dir=${XDG_RUNTIME_DIR:-/tmp}
stop_marker=$(mktemp "$runtime_dir/ecuflash-qualified-stop.XXXXXX")
launcher_output=$(mktemp "$runtime_dir/ecuflash-connected-launch.XXXXXX")
launcher_pid=

cleanup() {
    local status=$?
    trap - EXIT HUP INT TERM
    if [[ -n "$launcher_pid" ]] && kill -0 "$launcher_pid" 2>/dev/null; then
        touch "$stop_marker"
        WINEPREFIX="$prefix" "$wineserver" -k >/dev/null 2>&1 || true
        wait "$launcher_pid" 2>/dev/null || true
    fi
    rm -f -- "$stop_marker" "$launcher_output"
    exit "$status"
}
trap cleanup EXIT HUP INT TERM

[[ -x "$launcher" ]] || {
    echo "Installed EcuFlash launcher is missing: $launcher" >&2
    exit 1
}
[[ -x "$wineserver" ]] || {
    echo "Packaged Wine server is missing: $wineserver" >&2
    exit 1
}
lsusb -d 0403:cc4d >/dev/null 2>&1 || {
    echo 'OpenPort 2.0 is not visible in Linux.' >&2
    exit 1
}

rm -f -- "$stop_marker"
ECUFLASH_TEST_STOP_MARKER="$stop_marker" "$launcher" \
    >"$launcher_output" 2>&1 &
launcher_pid=$!
sleep "$test_seconds"
if ! kill -0 "$launcher_pid" 2>/dev/null; then
    set +e
    wait "$launcher_pid"
    launcher_status=$?
    set -e
    echo "EcuFlash exited before the ${test_seconds}-second connected test completed (status $launcher_status)." >&2
    sed -n '1,160p' "$launcher_output" >&2
    exit 1
fi

"$repo_root/tests/vm/verify-installed.sh"
touch "$stop_marker"
WINEPREFIX="$prefix" "$wineserver" -k >/dev/null 2>&1 || true
if ! wait "$launcher_pid"; then
    echo 'The EcuFlash launcher did not recognize the intentional test shutdown.' >&2
    sed -n '1,160p' "$launcher_output" >&2
    exit 1
fi
launcher_pid=

echo
echo 'PASS  connected EcuFlash test closed without a false failure dialog'
