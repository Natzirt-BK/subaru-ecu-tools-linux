#!/usr/bin/env bash
set -euo pipefail

repo_url=https://github.com/Natzirt-BK/subaru-ecu-tools-linux.git
test_root=${XDG_STATE_HOME:-$HOME/.local/state}/subaru-ecu-tools-qualification
run_id=$(date +%Y%m%d-%H%M%S)
checkout=$HOME/subaru-ecu-tools-release-test
report=$test_root/qualification-$run_id.txt
mkdir -p "$test_root"
exec > >(tee "$report") 2>&1

section() { printf '\n== %s ==\n' "$*"; }
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; exit 1; }

section 'New-user environment'
printf 'User: %s\n' "$(id)"
printf 'OS: '
cat /etc/os-release | grep '^PRETTY_NAME=' || true
if id -nG | tr ' ' '\n' | grep -qx uucp; then
    fail 'The baseline user already has an active uucp group; reset the VM snapshot.'
fi
pass 'ordinary user begins without active uucp access'

section 'Public GitHub checkout'
[[ ! -e "$checkout" ]] || fail "$checkout already exists; reset the VM snapshot."
git clone --depth 1 "$repo_url" "$checkout"
cd "$checkout"
revision=$(git rev-parse HEAD)
printf 'Revision: %s\n' "$revision"
pass 'public repository cloned'

section 'Repository tests'
bash -n bootstrap-cachyos.sh bootstrap-debian.sh linux/*.sh \
    linux/install-romraider2 tests/vm/*.sh
sh -n linux/launch-ecuflash linux/launch-evoscan linux/launch-romraider \
    linux/launch-romraider2 \
    linux/monitor-openport-state linux/sync-openport-device-state \
    wine-bridge/build-openport-driver.sh tests/*.sh
for test_script in tests/test-*.sh; do "$test_script"; done
git diff --check
pass 'repository tests'

section 'System readiness'
SUBARU_SETUP_NO_PAUSE=1 ./linux/install-cachyos.sh --check || true

cat <<'EOF'

Automated preflight passed. Continue with the graphical release test:

1. Run: ./bootstrap-cachyos.sh
2. Choose Clean reinstall and accept the official Tactrix license.
3. Confirm the applications appear under Subaru & Evo ECU Tools.
4. With OpenPort unplugged, launch EcuFlash once and close it.
5. On the host, attach OpenPort to this VM.
6. Launch EcuFlash again and leave it open for at least 15 seconds.
7. Run: ./tests/vm/verify-installed.sh

No ECU read or write is part of this qualification.
EOF
printf '\nPreflight report: %s\n' "$report"
