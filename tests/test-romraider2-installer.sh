#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT HUP INT TERM
archive_root=RomRaider2_ECU_Studio_1.1.0_Linux_x64
source_root=$test_root/source/$archive_root
install_root=$test_root/data/romraider2-ecu-studio
legacy_root=$test_root/data/bergerraider-ecu-studio

mkdir -p \
    "$source_root/bin" \
    "$source_root/lib/runtime" \
    "$source_root/lib/app/lib/linux/64" \
    "$source_root/config" \
    "$source_root/customize" \
    "$source_root/logs" \
    "$source_root/roms" \
    "$source_root/repositories"
touch \
    "$source_root/lib/runtime/release" \
    "$source_root/lib/app/RomRaider2.jar" \
    "$source_root/lib/app/lib/linux/64/j2534.so"
printf '%s\n' \
    '<settings><files><def_dir path="definitions"/></files><logger>' \
    '<protocol name="SSM" transport="ISO9141" module="ECU" fastpoll="false" library=""/>' \
    '</logger></settings>' >"$source_root/config/settings.default.xml"
printf 'linux=j2534.so\n' >"$source_root/customize/j2534Libraries.properties"
printf '[JavaOptions]\njava-options=-Dromraider2.settings.dir=$APPDIR/../../config/user\n' \
    >"$source_root/lib/app/RomRaider2.cfg"
printf '#!/bin/sh\nprintf "%%s\\n" "$@" >"$ROMRAIDER2_TEST_ARGS"\n' \
    >"$source_root/bin/RomRaider2"
chmod +x "$source_root/bin/RomRaider2"

archive_sha=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb

mkdir -p "$legacy_root/config/user" "$legacy_root/logs"
touch "$legacy_root/.installed-by-subaru-ecu-tools"
printf '<settings migrated="true"/>\n' >"$legacy_root/config/user/settings.xml"
printf 'legacy log\n' >"$legacy_root/logs/preserved.csv"

ROMRAIDER2_INSTALL_ROOT="$install_root" \
ROMRAIDER2_LEGACY_INSTALL_ROOT="$legacy_root" \
ROMRAIDER2_SOURCE_ROOT="$source_root" \
ROMRAIDER2_SHA256="$archive_sha" \
    "$repo_root/linux/install-romraider2" >"$test_root/install.log"

test -x "$install_root/bin/RomRaider2"
test -f "$install_root/lib/runtime/release"
test -f "$install_root/lib/app/RomRaider2.jar"
test -f "$install_root/config/user/settings.xml"
test ! -e "$install_root/definitions"
grep -F 'migrated="true"' "$install_root/config/user/settings.xml" >/dev/null
test -f "$install_root/logs/preserved.csv"
test ! -e "$legacy_root"
test -f "$install_root/.installed-by-subaru-ecu-tools"
grep -Fx "$archive_sha" "$install_root/.release-sha256" >/dev/null
grep -F 'RomRaider2 1.1.0 release candidate installed' "$test_root/install.log" >/dev/null

ROMRAIDER2_INSTALL_ROOT="$install_root" \
ROMRAIDER2_SOURCE_ROOT="$source_root" \
ROMRAIDER2_SHA256="$archive_sha" \
    "$repo_root/linux/install-romraider2" >"$test_root/recheck.log"
grep -F 'already current' "$test_root/recheck.log" >/dev/null
test "$(find "$test_root/data" -maxdepth 1 -name 'romraider2-ecu-studio.backup-*' | wc -l)" -eq 0

printf '%s\n' \
    '<settings preserved="true"><logger>' \
    '<serial port="ttyS0" refresh="true"/>' \
    '<protocol name="OBD" transport="ISO15765" module="ECU" fastpoll="false" library=""/>' \
    '<profile path="definitions/Foz/Profiles/aem-uego-9600.xml"/>' \
    '</logger></settings>' >"$install_root/config/user/settings.xml"
updated_sha=dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
ROMRAIDER2_INSTALL_ROOT="$install_root" \
ROMRAIDER2_SOURCE_ROOT="$source_root" \
ROMRAIDER2_SHA256="$updated_sha" \
    "$repo_root/linux/install-romraider2" >"$test_root/update.log"
grep -F 'preserved="true"' "$install_root/config/user/settings.xml" >/dev/null
grep -F '<profile path=""/>' \
    "$install_root/config/user/settings.xml" >/dev/null
grep -F 'Cleared references to retired bundled vehicle content' \
    "$test_root/update.log" >/dev/null
test -f "$install_root/logs/preserved.csv"
grep -Fx "$updated_sha" "$install_root/.release-sha256" >/dev/null
test "$(find "$test_root/data" -maxdepth 1 -name 'romraider2-ecu-studio.backup-*' | wc -l)" -eq 1

mkdir -p "$test_root/home" "$test_root/sysfs" "$test_root/dev"
HOME="$test_root/home" \
XDG_STATE_HOME="$test_root/state-home" \
ROMRAIDER2_HOME="$install_root" \
ROMRAIDER2_MODE=logger \
ROMRAIDER2_TEST_ARGS="$test_root/java-args" \
OPENPORT_USB_SYSFS_ROOT="$test_root/sysfs" \
OPENPORT_USB_DEV_ROOT="$test_root/dev" \
    "$repo_root/linux/launch-romraider2"
grep -Fx -- '-logger' "$test_root/java-args" >/dev/null

printf 'ID=cachyos\nPRETTY_NAME="CachyOS test"\n' >"$test_root/os-release"
mkdir -p "$test_root/full-home"
HOME="$test_root/full-home" \
XDG_BIN_HOME="$test_root/full-bin" \
XDG_CACHE_HOME="$test_root/full-cache" \
XDG_CONFIG_HOME="$test_root/full-config" \
XDG_DATA_HOME="$test_root/full-data" \
XDG_STATE_HOME="$test_root/full-state" \
ECU_TOOLS_OS_RELEASE="$test_root/os-release" \
ROMRAIDER2_SOURCE_ROOT="$source_root" \
ROMRAIDER2_SHA256="$updated_sha" \
SUBARU_SETUP_NO_PAUSE=1 \
    "$repo_root/linux/install-cachyos.sh" --install-romraider2 \
    >"$test_root/full-install.log"
test -x "$test_root/full-data/romraider2-ecu-studio/bin/RomRaider2"
test -x "$test_root/full-bin/launch-romraider2"
test -f "$test_root/full-data/applications/romraider2-editor.desktop"
test -f "$test_root/full-data/applications/romraider2-logger.desktop"
test ! -e "$test_root/full-home/Documents/Subaru & Evo ECU Tools/RomRaider2/Definitions"
grep -F 'PREPARING ROMRAIDER2 LAUNCHERS' \
    "$test_root/full-install.log" >/dev/null
if grep -Fq 'Checking dependencies' "$test_root/full-install.log"; then
    echo 'RomRaider2-only install unexpectedly entered the shared dependency check.' >&2
    exit 1
fi
grep -F '[ RUN  ] Verifying the pinned RomRaider2 application image.' \
    "$test_root/full-install.log" >/dev/null
if grep -q '^  OK RomRaider2 1.1.0 release candidate' \
        "$test_root/full-install.log"; then
    echo 'Nested RomRaider2 installer output escaped the setup console.' >&2
    exit 1
fi

grep -F 'romraider2-1.1.0-rc1' \
    "$repo_root/linux/install-romraider2" >/dev/null
grep -F '4c258cafd85cc32f8f97b6fa8485e6b6d2bf4dd34770ac02303c1458fa29a0ac' \
    "$repo_root/linux/install-romraider2" >/dev/null

echo 'RomRaider2 installer tests passed.'
