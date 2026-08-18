#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
manager=$repo_root/tests/vm/manage-debian-vm.sh

# Qualification is intentionally noninteractive.  A forced outer PTY makes the
# layout test's nested `script` PTY wait until its timeout instead of exiting.
grep -F 'ssh -T -i "$ssh_key"' "$manager" >/dev/null
! grep -F 'ssh -tt -i "$ssh_key"' "$manager" >/dev/null
grep -F 'UserKnownHostsFile="$ssh_known_hosts"' "$manager" >/dev/null
grep -F 'rm -f -- "$ssh_known_hosts"' "$manager" >/dev/null
grep -F "'  - qemu-guest-agent' '  - linux-image-amd64'" "$manager" >/dev/null
grep -F 'renderer=NetworkManager' "$manager" >/dev/null
grep -F '99-subaru-test-input.cfg' "$manager" >/dev/null

echo 'Debian VM harness tests passed.'
