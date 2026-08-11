#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT HUP INT TERM
installer=$test_root/installer

cat >"$installer" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >"$TEST_TRACE"
EOF
chmod +x "$installer"

run_choice() {
    name=$1
    keys=$2
    expected=$3
    trace=$test_root/$name.trace
    output=$test_root/$name.output
    printf '%s' "$keys" | TERM=dumb SUBARU_SETUP_INPUT_DEVICE=/dev/stdin \
        ECU_TOOLS_INSTALLER="$installer" TEST_TRACE="$trace" \
        "$repo_root/linux/setup-cachyos-gui.sh" >"$output" 2>&1
    grep -F -- "$expected" "$trace" >/dev/null
    grep -F 'Select an option:' "$output" >/dev/null
}

run_choice recommended '1y' '--yes-all'
run_choice clean '2y' '--clean-install --yes'
run_choice check '3' '--check'
run_choice uninstall '4y' '--uninstall --yes'

printf '1n' | TERM=dumb SUBARU_SETUP_INPUT_DEVICE=/dev/stdin \
    ECU_TOOLS_INSTALLER="$installer" TEST_TRACE="$test_root/cancel.trace" \
    "$repo_root/linux/setup-cachyos-gui.sh" >/dev/null
test ! -e "$test_root/cancel.trace"

run_choice invalid_then_check 'x3' '--check'
grep -F 'Unknown selection. Press 1, 2, 3, 4, or Q.' \
    "$test_root/invalid_then_check.output" >/dev/null

engine=$repo_root/linux/install-cachyos.sh
grep -F 'read -rsn1 key </dev/tty' "$engine" >/dev/null
grep -F 'setup_interactive=false' "$engine" >/dev/null
test "$(grep -F -c '$setup_interactive || return 0' "$engine")" -eq 1
! grep -F '[[ -t 0 || -t 1 ]] || return 0' "$engine" >/dev/null
grep -F 'Briefly describe what went wrong (optional' "$engine" >/dev/null
grep -F 'tail -c 18000' "$engine" >/dev/null
grep -F '*j2534-probe.log) log_bytes=12000' "$engine" >/dev/null
! grep -F 'WINEDEBUG=-all,+loaddll' "$engine" >/dev/null
grep -F 'The complete ready-to-share report remains at:' "$engine" >/dev/null
grep -F 'OpenPort USB access diagnostics:' "$engine" >/dev/null
grep -F 'effective write access:' "$engine" >/dev/null
grep -F 'processes using node:' "$engine" >/dev/null
grep -F 'Verbose OpenPort USB descriptor:' "$engine" >/dev/null
grep -F 'first 16,000 bytes; may include adapter serial and host USB details' "$engine" >/dev/null
grep -F 'Failure-only Wine OpenPort driver/PnP trace' "$engine" >/dev/null
grep -F 'ecuflash-post-probe-startup.log' "$engine" >/dev/null
grep -F 'wait_for_stable_openport' "$engine" >/dev/null
grep -F 'stop_wine_prefix "$ecuflash_wine" "$ecuflash_prefix"' "$engine" >/dev/null
grep -F 'restarting Wine and retrying once' "$engine" >/dev/null
grep -F '"$cache_root/ecuflash-j2534-probe.log"' "$engine" >/dev/null
grep -F 'LD_LIBRARY_PATH="/usr/lib32' "$repo_root/linux/launch-romraider" >/dev/null
grep -F "grep -q 'J2534 DLL Version: 1\\.02\\.4870'" "$engine" >/dev/null
grep -F 'official Tactrix J2534 library' "$engine" >/dev/null
grep -F 'WINAPI *open_fn' "$repo_root/wine-bridge/probe.c" >/dev/null
grep -F 'subaru-ecu-tools.menu' "$engine" >/dev/null
grep -F 'X-Subaru-Evo-ECU-Tools' "$repo_root/linux/subaru-ecu-tools.menu" >/dev/null
! grep -F "WINEDLLOVERRIDES='op20pt32,j2534=b'" "$engine" >/dev/null
! grep -F 'WINEDLLOVERRIDES="op20pt32,j2534=b' "$repo_root/linux/launch-ecuflash" >/dev/null
grep -F 'start /wait /unix' "$repo_root/linux/launch-ecuflash" >/dev/null
grep -F 'monitor-openport-state' "$repo_root/linux/launch-ecuflash" >/dev/null
grep -F '"$wine_server" -w' "$repo_root/linux/launch-ecuflash" >/dev/null
grep -F 'ECUFLASH_TEST_STOP_MARKER' "$repo_root/linux/launch-ecuflash" >/dev/null
grep -F 'ECUFLASH_LOG_NOT_OLDER_THAN' "$repo_root/tests/vm/verify-installed.sh" >/dev/null
grep -F '"$data_dir/winedll/i386-windows/op20pt32.dll"' "$engine" >/dev/null
grep -F -- '-print 2>/dev/null | sed -n' "$engine" >/dev/null
grep -F 'evoscan_wine="${EVOSCAN_WINE:-$ecuflash_runtime_dir/files/bin/wine}"' \
    "$engine" >/dev/null
! grep -F '$wine_runtime_dir/bin/wine' "$engine" >/dev/null
grep -F 'stop_wine_prefix "$update_wine" "$ecuflash_prefix" "$update_refresh_log"' \
    "$engine" >/dev/null

echo 'Terminal setup action tests passed.'
