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
grep -F 'SUBARU • LANCER EVOLUTION • ECU SOFTWARE' \
    "$repo_root/linux/setup-cachyos-gui.sh" >/dev/null

echo 'Public-content and branding tests passed.'
