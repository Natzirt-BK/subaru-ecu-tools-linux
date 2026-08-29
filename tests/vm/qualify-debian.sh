#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
report_dir=${XDG_STATE_HOME:-$HOME/.local/state}/subaru-ecu-tools-qualification
report=$report_dir/debian-qualification-$(date +%Y%m%d-%H%M%S).txt
mkdir -p "$report_dir"
exec > >(tee "$report") 2>&1

section() { printf '\n== %s ==\n' "$*"; }
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; exit 1; }

section 'Debian baseline'
grep -Eq '^ID=debian$' /etc/os-release || fail 'guest is not Debian'
[[ "$(dpkg --print-architecture)" == amd64 ]] || fail 'guest is not Debian amd64'
systemctl is-active --quiet gdm3 || fail 'GNOME display manager is not active'
printf 'OS: '; grep '^PRETTY_NAME=' /etc/os-release
printf 'Desktop: '; systemctl get-default
pass 'Debian 13 amd64 GNOME guest is ready'

section 'Repository syntax and unit tests'
cd "$repo_root"
bash -n bootstrap-cachyos.sh bootstrap-debian.sh linux/*.sh \
    linux/install-bergerraider tests/vm/*.sh
sh -n linux/launch-ecuflash linux/launch-evoscan linux/launch-romraider \
    linux/launch-bergerraider \
    linux/monitor-openport-state linux/sync-openport-device-state \
    wine-bridge/build-openport-driver.sh tests/*.sh
for test_script in tests/test-*.sh; do "$test_script"; done
git diff --check 2>/dev/null || true
pass 'repository scripts and unit tests'

section 'Debian dependencies and native bridge build'
./linux/install-debian.sh --check --install-deps || fail 'Debian dependency check'
./wine-bridge/build-openport-driver.sh
file build-wine-bridge/openport.sys build-wine-bridge/openport.so \
    build-wine-bridge/op20pt32.dll build-wine-bridge/op20pt32.so \
    build-wine-bridge/j2534-probe.exe build-wine-bridge/openport-device-probe.exe
pass 'Debian Wine/OpenPort bridge build'

section 'Non-flashing support-file installation'
./linux/install-debian.sh --install-deps
test -x "$HOME/.local/bin/launch-ecuflash"
test -x "$HOME/.local/bin/launch-romraider"
test -f "$HOME/.local/share/applications/subaru-ecu-tools-setup.desktop"
grep -q 'GROUP="dialout"' /etc/udev/rules.d/99-openport2.rules 2>/dev/null || \
    printf 'INFO  udev rule not installed in non-hardware qualification\n'
pass 'Debian launchers and desktop integration'

printf '\nDebian qualification complete. No ECU was read, written, or flashed.\n'
printf 'Report: %s\n' "$report"
