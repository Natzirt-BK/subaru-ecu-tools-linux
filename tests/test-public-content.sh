#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

for obsolete_file in \
    extras/j2534_x86.reg \
    extras/j2534_x64.reg \
    linux/launch-evoscan \
    linux/evoscan.desktop \
    linux/install-bergerraider \
    linux/launch-bergerraider \
    linux/install-evo-romraider-mut2 \
    linux/launch-romraider-evo-mut2; do
    test ! -e "$repo_root/$obsolete_file"
done

git -C "$repo_root" ls-files | \
    grep -E -i '\.(bin|hex|srf|rom)$' >/dev/null && {
        echo 'A vehicle ROM file is tracked in the software repository.' >&2
        exit 1
    }

grep -Fx '# Ecu Tools by NatZirt' "$repo_root/README.md" >/dev/null
grep -Fx 'Name=ECU Tools' \
    "$repo_root/linux/subaru-ecu-tools.directory" >/dev/null
grep -F 'SUBARU • MITSUBISHI LANCER EVOLUTION' \
    "$repo_root/linux/setup-cachyos-gui.sh" >/dev/null

# Public setup must not direct unauthenticated users to a private RR2 package
# repository or silently select development/qualification artifacts.
for public_file in \
    "$repo_root/README.md" \
    "$repo_root/LINUX_ECU_TOOLS.md" \
    "$repo_root/linux/install-romraider2"; do
    if grep -Fq 'github.com/Natzirt-BK/RomRaider2-Releases' "$public_file"; then
        echo "Private RomRaider2 release URL leaked into public setup: $public_file" >&2
        exit 1
    fi
done
grep -F '527418890d35936d5d0f10ff18af9067700d6a78' "$repo_root/README.md" >/dev/null
grep -F 'no public RomRaider2 package URL configured' "$repo_root/README.md" >/dev/null

echo 'Public-content and branding tests passed.'
