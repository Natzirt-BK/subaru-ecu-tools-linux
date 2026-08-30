#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT HUP INT TERM
mkdir -p \
    "$test_root/bin" \
    "$test_root/data/applications" \
    "$test_root/data/subaru-ecu-tools-linux/runtime" \
    "$test_root/data/ecuflash-proton" \
    "$test_root/data/romraider-dm20" \
    "$test_root/data/romraider-mut2-evo-88780008" \
    "$test_root/data/subaru-evo-ecu-definitions" \
    "$test_root/cache/subaru-ecu-tools-linux" \
    "$test_root/state/subaru-ecu-tools-linux" \
    "$test_root/home/Documents/Subaru & Evo ECU Tools/Evo RomRaider MUT-II" \
    "$test_root/home/ROMs"
touch \
    "$test_root/bin/launch-ecuflash" \
    "$test_root/bin/launch-romraider-evo-mut2" \
    "$test_root/bin/install-evo-romraider-mut2" \
    "$test_root/data/applications/romraider-evo-mut2-editor.desktop" \
    "$test_root/data/applications/romraider-evo-mut2-logger.desktop" \
    "$test_root/data/subaru-ecu-tools-linux/runtime/stale" \
    "$test_root/data/ecuflash-proton/stale-registry" \
    "$test_root/data/romraider-dm20/separately-installed" \
    "$test_root/data/romraider-mut2-evo-88780008/.installed-by-subaru-ecu-tools" \
    "$test_root/data/subaru-evo-ecu-definitions/user-definition.xml" \
    "$test_root/state/subaru-ecu-tools-linux/existing.log" \
    "$test_root/home/ROMs/user-rom.bin"
ln -s "$test_root/data/romraider-mut2-evo-88780008" \
    "$test_root/home/Documents/Subaru & Evo ECU Tools/Evo RomRaider MUT-II/Definitions"
ln -s "$test_root/data/romraider-mut2-evo-88780008/RELEASE_NOTES.md" \
    "$test_root/home/Documents/Subaru & Evo ECU Tools/Evo RomRaider MUT-II/Release Notes.md"
printf '%s\n' 'ID=arch' 'PRETTY_NAME="Test Arch"' >"$test_root/os-release"

cat >"$test_root/bin/pacman" <<'EOF'
#!/bin/sh
exit 1
EOF
cat >"$test_root/bin/sudo" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "$test_root/bin/pacman" "$test_root/bin/sudo"

set +e
PATH="$test_root/bin:$PATH" \
HOME="$test_root/home" \
XDG_BIN_HOME="$test_root/bin" \
XDG_DATA_HOME="$test_root/data" \
XDG_CACHE_HOME="$test_root/cache" \
XDG_STATE_HOME="$test_root/state" \
SUBARU_SETUP_NO_PAUSE=1 NO_COLOR=1 \
ECU_TOOLS_OS_RELEASE="$test_root/os-release" \
    "$repo_root/linux/install-cachyos.sh" --clean-install --yes \
    >"$test_root/clean-install.log" 2>&1
status=$?
set -e
[ "$status" -ne 0 ]

[ ! -e "$test_root/data/subaru-ecu-tools-linux" ]
[ ! -e "$test_root/data/ecuflash-proton" ]
[ ! -e "$test_root/bin/launch-ecuflash" ]
[ ! -e "$test_root/bin/launch-romraider-evo-mut2" ]
[ ! -e "$test_root/bin/install-evo-romraider-mut2" ]
[ ! -e "$test_root/data/applications/romraider-evo-mut2-editor.desktop" ]
[ ! -e "$test_root/data/applications/romraider-evo-mut2-logger.desktop" ]
[ -e "$test_root/data/romraider-dm20/separately-installed" ]
[ ! -e "$test_root/data/romraider-mut2-evo-88780008" ]
[ ! -e "$test_root/home/Documents/Subaru & Evo ECU Tools/Evo RomRaider MUT-II" ]
[ -e "$test_root/data/subaru-evo-ecu-definitions/user-definition.xml" ]
[ -e "$test_root/state/subaru-ecu-tools-linux/existing.log" ]
[ -e "$test_root/home/ROMs/user-rom.bin" ]
perl -CSD -Mutf8 -0777 -e '
    my $text = <>;
    $text =~ s/[║\s]+/ /g;
    exit(index($text, "Old installer-managed application and runtime state removed.") < 0 ? 1 : 0);
' "$test_root/clean-install.log"
! grep -q '\[ INPUT \]' "$test_root/clean-install.log"

echo 'Clean-install scope tests passed.'
