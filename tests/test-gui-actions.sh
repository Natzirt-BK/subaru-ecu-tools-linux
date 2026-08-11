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
        ECU_TOOLS_INSTALLER="$installer" ECU_TOOLS_SKIP_UPDATE_PROMPT=1 \
        ECU_TOOLS_MUSIC_PLAYER="$test_root/no-music" \
        TEST_TRACE="$trace" \
        "$repo_root/linux/setup-cachyos-gui.sh" >"$output" 2>&1
    grep -F -- "$expected" "$trace" >/dev/null
    grep -F 'Select an option:' "$output" >/dev/null
}

run_choice recommended '1y' '--yes-all'
run_choice clean '2y' '--clean-install --yes'
run_choice check '3' '--check'
run_choice uninstall '4y' '--uninstall --yes'

printf '1n' | TERM=dumb SUBARU_SETUP_INPUT_DEVICE=/dev/stdin \
    ECU_TOOLS_INSTALLER="$installer" ECU_TOOLS_SKIP_UPDATE_PROMPT=1 \
    ECU_TOOLS_MUSIC_PLAYER="$test_root/no-music" \
    TEST_TRACE="$test_root/cancel.trace" \
    "$repo_root/linux/setup-cachyos-gui.sh" >/dev/null
test ! -e "$test_root/cancel.trace"

run_choice invalid_then_check 'x3' '--check'
grep -F 'Unknown selection. Press 1, 2, 3, 4, or Q.' \
    "$test_root/invalid_then_check.output" >/dev/null

mkdir -p "$test_root/data/applications"
touch "$test_root/data/applications/subaru-ecu-tools-setup.desktop"
updater=$test_root/updater
cat >"$updater" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >"$TEST_UPDATE_TRACE"
EOF
chmod +x "$updater"
printf 'y' | TERM=dumb SUBARU_SETUP_INPUT_DEVICE=/dev/stdin \
    XDG_DATA_HOME="$test_root/data" ECU_TOOLS_INSTALLER="$installer" \
    ECU_TOOLS_UPDATER="$updater" TEST_UPDATE_TRACE="$test_root/update.trace" \
    "$repo_root/linux/setup-cachyos-gui.sh" >"$test_root/update.output" 2>&1
grep -Fx -- '--continue-setup' "$test_root/update.trace" >/dev/null
grep -F 'Update Subaru & Evo ECU Tools before continuing?' \
    "$test_root/update.output" >/dev/null

printf 'n3' | TERM=dumb SUBARU_SETUP_INPUT_DEVICE=/dev/stdin \
    XDG_DATA_HOME="$test_root/data" ECU_TOOLS_INSTALLER="$installer" \
    ECU_TOOLS_UPDATER="$updater" TEST_TRACE="$test_root/no-update.trace" \
    "$repo_root/linux/setup-cachyos-gui.sh" >"$test_root/no-update.output" 2>&1
grep -Fx -- '--check' "$test_root/no-update.trace" >/dev/null
grep -F 'Continuing without updating is not recommended.' \
    "$test_root/no-update.output" >/dev/null

music_player=$test_root/music-player
cat >"$music_player" <<'EOF'
#!/bin/sh
printf 'started\n' >"$TEST_MUSIC_TRACE"
EOF
cat >"$test_root/pw-play" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$music_player" "$test_root/pw-play"
printf '1y' | PATH="$test_root:$PATH" TERM=dumb \
    SUBARU_SETUP_INPUT_DEVICE=/dev/stdin ECU_TOOLS_INSTALLER="$installer" \
    ECU_TOOLS_MUSIC_PLAYER="$music_player" ECU_TOOLS_SKIP_UPDATE_PROMPT=1 \
    TEST_TRACE="$test_root/music-install.trace" \
    TEST_MUSIC_TRACE="$test_root/music.trace" \
    "$repo_root/linux/setup-cachyos-gui.sh" >"$test_root/music.output" 2>&1
i=0
while [ ! -e "$test_root/music.trace" ] && [ "$i" -lt 50 ]; do
    sleep 0.01
    i=$((i + 1))
done
grep -Fx 'started' "$test_root/music.trace" >/dev/null
grep -F 'Press M in this setup terminal at any time to mute it.' \
    "$test_root/music.output" >/dev/null

engine=$repo_root/linux/install-cachyos.sh
grep -F 'Removed the redundant Update shortcut; Setup now offers updates first.' \
    "$engine" >/dev/null
! grep -F 'subaru-ecu-tools-update;' "$engine" >/dev/null
test ! -e "$repo_root/linux/subaru-ecu-tools-update.desktop"
grep -F 'exec env ECU_TOOLS_SKIP_UPDATE_PROMPT=1' \
    "$repo_root/linux/update-cachyos.sh" >/dev/null
test -x "$repo_root/linux/play-installer-chiptune"
grep -q '^start_installer_music()' \
    "$repo_root/linux/setup-cachyos-gui.sh" >/dev/null
! grep -F "confirm 'Play an original retro installer chiptune during setup?'" \
    "$repo_root/linux/setup-cachyos-gui.sh" >/dev/null
grep -F 'export SUBARU_SETUP_MUSIC_PID=$!' \
    "$repo_root/linux/setup-cachyos-gui.sh" >/dev/null
grep -q '^stop_setup_music()' "$engine"
! grep -q '^poll_setup_music_key()' "$engine"
! grep -F -- '--separate --nofork' "$repo_root/linux/setup-cachyos-gui.sh" >/dev/null
grep -F 'track_title=Arpanauts' "$repo_root/linux/play-installer-chiptune" >/dev/null
grep -F 'track_artist='"'"'Eric Skiff'"'" \
    "$repo_root/linux/play-installer-chiptune" >/dev/null
grep -F 'Creative Commons Attribution 4.0' \
    "$repo_root/linux/installer-music-CREDITS.md" >/dev/null
grep -F 'music_volume=${ECU_TOOLS_MUSIC_VOLUME:-0.12}' \
    "$repo_root/linux/play-installer-chiptune" >/dev/null
grep -F 'm|M)' "$repo_root/linux/play-installer-chiptune" >/dev/null
grep -q '^pause_setup_music_keys()' "$engine"
grep -q '^resume_setup_music_keys()' "$engine"
grep -q '^run_with_music_keys_paused()' "$engine"
! grep -F 'track_url=' "$repo_root/linux/play-installer-chiptune" >/dev/null
printf '%s  %s\n' \
    9e74d37101f54f11a8816b1031d0967e55dc011da7fb01fb56f3729e62ca25eb \
    "$repo_root/linux/assets/arpanauts-eric-skiff.mp3" | sha256sum -c --status -
cat >"$test_root/pw-play" <<'EOF'
#!/bin/sh
exec sleep 30
EOF
chmod +x "$test_root/pw-play"
printf 'M\n' | PATH="$test_root:$PATH" TERM=dumb timeout 10 \
    script -q -e -c "$repo_root/linux/play-installer-chiptune" /dev/null \
    >/dev/null 2>&1
grep -F 'ACCESS GRANTED // SETUP COMPLETE' "$engine" >/dev/null
test "$(grep -c -- '--progress-bar' "$engine")" -eq 4
grep -F -- '--progress-bar' "$repo_root/linux/install-romraider-definitions" >/dev/null
! grep -F 'echo "  Launchers: $bin_dir"' "$engine" >/dev/null
grep -Fx 'Name=Setup' "$repo_root/linux/subaru-ecu-tools-setup.desktop" >/dev/null
grep -Fx 'Name=EcuFlash' "$repo_root/linux/ecuflash.desktop" >/dev/null
grep -Fx 'Name=EvoScan' "$repo_root/linux/evoscan.desktop" >/dev/null
grep -F 'read -rsn1 key </dev/tty' "$engine" >/dev/null
grep -F 'setup_interactive=false' "$engine" >/dev/null
test "$(grep -F -c '$setup_interactive || return 0' "$engine")" -eq 1
! grep -F '[[ -t 0 || -t 1 ]] || return 0' "$engine" >/dev/null
grep -F 'Briefly describe what went wrong (optional' "$engine" >/dev/null
grep -F 'tail -c 12000' "$engine" >/dev/null
grep -F '*j2534-probe.log) log_bytes=10000' "$engine" >/dev/null
! grep -F 'WINEDEBUG=-all,+loaddll' "$engine" >/dev/null
grep -F 'The complete ready-to-share report remains at:' "$engine" >/dev/null
grep -F 'OpenPort USB access diagnostics:' "$engine" >/dev/null
grep -F 'Host and installed-runtime diagnostics:' "$engine" >/dev/null
grep -F 'first 6,000 bytes; may include identifying host' "$engine" >/dev/null
grep -F 'It does not intentionally collect passwords, tokens, SSH keys' "$engine" >/dev/null
grep -F 'ip -brief address' "$engine" >/dev/null
grep -F 'OpenPort native bridge dependencies:' "$engine" >/dev/null
grep -F 'effective write access:' "$engine" >/dev/null
grep -F 'processes using node:' "$engine" >/dev/null
grep -F 'Verbose OpenPort USB descriptor:' "$engine" >/dev/null
grep -F 'first 10,000 bytes; may include adapter serial and host USB details' "$engine" >/dev/null
grep -F 'report_bytes <= 60000' "$engine" >/dev/null
grep -F 'head -c 28000 "$full_report"' "$engine" >/dev/null
grep -F 'tail -c 28000 "$full_report"' "$engine" >/dev/null
grep -F 'Failure-only Wine OpenPort driver/PnP trace' "$engine" >/dev/null
grep -F 'Prime it before the official DLL attempts PassThruOpen' "$engine" >/dev/null
update_prime_line=$(grep -n 'capture_openport_device_probe.*update_wine' "$engine" | head -1 | cut -d: -f1)
test "$update_prime_line" -lt \
    "$(grep -n 'j2534-probe.exe' "$engine" | awk -F: -v prime="$update_prime_line" '$1 > prime {print $1; exit}')"
test "$(grep -n 'capture_openport_device_probe.*update_wine' "$engine" | tail -1 | cut -d: -f1)" \
    -gt "$(grep -n 'capture_verbose_openport_probe.*update_wine' "$engine" | cut -d: -f1)"
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
grep -F 'bridge_device_probe="$ECU_TOOLS_DATA_DIR/tools/openport-device-probe.exe"' \
    "$repo_root/linux/launch-ecuflash" >/dev/null
grep -F '=== Priming OpenPort service before EcuFlash ===' \
    "$repo_root/linux/launch-ecuflash" >/dev/null
prime_line=$(grep -n '"$ECUFLASH_WINE" "$bridge_device_probe"' \
    "$repo_root/linux/launch-ecuflash" | cut -d: -f1)
launch_line=$(grep -n 'start /wait /unix' \
    "$repo_root/linux/launch-ecuflash" | cut -d: -f1)
test "$prime_line" -lt "$launch_line"
grep -F '"$wine_server" -w' "$repo_root/linux/launch-ecuflash" >/dev/null
grep -F 'ECUFLASH_TEST_STOP_MARKER' "$repo_root/linux/launch-ecuflash" >/dev/null
grep -F 'ECUFLASH_TEST_STOP_MARKER="$post_probe_marker"' "$engine" >/dev/null
grep -F 'ECUFLASH_LOG_NOT_OLDER_THAN' "$repo_root/tests/vm/verify-installed.sh" >/dev/null
grep -F '"$data_dir/winedll/i386-windows/op20pt32.dll"' "$engine" >/dev/null
grep -F -- '-print 2>/dev/null | sed -n' "$engine" >/dev/null
grep -F 'evoscan_wine="${EVOSCAN_WINE:-$ecuflash_runtime_dir/files/bin/wine}"' \
    "$engine" >/dev/null
! grep -F '$wine_runtime_dir/bin/wine' "$engine" >/dev/null
grep -F 'stop_wine_prefix "$update_wine" "$ecuflash_prefix" "$update_refresh_log"' \
    "$engine" >/dev/null

echo 'Terminal setup action tests passed.'
