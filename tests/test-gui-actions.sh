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
    printf '%s' "$keys" | TERM=dumb ECU_TOOLS_INSTALLER="$installer" TEST_TRACE="$trace" \
        "$repo_root/linux/setup-cachyos-gui.sh" >"$output"
    grep -F -- "$expected" "$trace" >/dev/null
    grep -F 'Select an option (no Enter required)' "$output" >/dev/null
}

run_choice recommended '1y' '--yes-all'
run_choice clean '2y' '--clean-install --yes'
run_choice check '3' '--check'
run_choice uninstall '4y' '--uninstall --yes'

printf '1n' | TERM=dumb ECU_TOOLS_INSTALLER="$installer" TEST_TRACE="$test_root/cancel.trace" \
    "$repo_root/linux/setup-cachyos-gui.sh" >/dev/null
test ! -e "$test_root/cancel.trace"

engine=$repo_root/linux/install-cachyos.sh
grep -F 'read -rsn1 key </dev/tty' "$engine" >/dev/null
grep -F 'Briefly describe what went wrong (optional' "$engine" >/dev/null
grep -F 'tail -c 24000' "$engine" >/dev/null
grep -F 'tail -c 3500' "$engine" >/dev/null
grep -F 'The complete ready-to-share report remains at:' "$engine" >/dev/null
grep -F 'wait_for_stable_openport' "$engine" >/dev/null
grep -F '"$cache_root/ecuflash-j2534-probe.log"' "$engine" >/dev/null
grep -F 'LD_LIBRARY_PATH="/usr/lib32' "$repo_root/linux/launch-romraider" >/dev/null
grep -F "grep -q 'J2534 DLL Version: 1\\.02\\.4870'" "$engine" >/dev/null
grep -F 'official Tactrix J2534 library' "$engine" >/dev/null
grep -F 'subaru-ecu-tools.menu' "$engine" >/dev/null
grep -F 'X-Subaru-Evo-ECU-Tools' "$repo_root/linux/subaru-ecu-tools.menu" >/dev/null
! grep -F "WINEDLLOVERRIDES='op20pt32,j2534=b'" "$engine" >/dev/null
! grep -F 'WINEDLLOVERRIDES="op20pt32,j2534=b' "$repo_root/linux/launch-ecuflash" >/dev/null
grep -F '"$data_dir/winedll/i386-windows/op20pt32.dll"' "$engine" >/dev/null

echo 'Terminal setup action tests passed.'
