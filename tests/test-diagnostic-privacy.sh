#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

HOME=/home/privateperson USER=privateperson LOGNAME=privateperson \
    "$repo_root/linux/redact-diagnostics" >"$test_root/report" <<'EOF'
Hostname: secret-workstation
User and groups: uid=1000(privateperson) groups=1000(privateperson)
Home: /home/privateperson
Failure log: /home/privateperson/.local/state/example.log
Contact: driver@example.test
Peer endpoints: 192.168.50.44 and fe80::1
Adapter address: 02:42:ac:11:00:02
Device Serial Number: TA123456789
ID_SERIAL_SHORT=TA123456789
DEVPATH=/devices/pci0000:00/usb1/1-2
Download failed: https://example.test/file?token=private-token
J2534 bridge test failed with status 7.
EOF

for private_value in privateperson secret-workstation driver@example.test \
    192.168.50.44 02:42:ac:11:00:02 TA123456789 private-token; do
    if grep -F "$private_value" "$test_root/report" >/dev/null; then
        echo "Diagnostic sanitizer leaked: $private_value" >&2
        exit 1
    fi
done
! grep -F 'fe80::1' "$test_root/report" >/dev/null
grep -F 'J2534 bridge test failed with status 7.' "$test_root/report" >/dev/null
grep -F '[email]' "$test_root/report" >/dev/null
grep -F '[ip]' "$test_root/report" >/dev/null
grep -F '[mac]' "$test_root/report" >/dev/null
grep -F '[query-redacted]' "$test_root/report" >/dev/null

engine=$repo_root/linux/install-cachyos.sh
grep -F 'Create a shareable diagnostic report?' "$engine" >/dev/null
grep -F 'Review it, then attach it' "$engine" >/dev/null
! grep -F 'gh issue create' "$engine" >/dev/null
! grep -F 'Upload this error log in a public GitHub issue' "$engine" >/dev/null

echo 'Diagnostic privacy tests passed.'
