#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT HUP INT TERM
archive_root=BergerRaider_ECU_Studio_1.1.0_Linux_x64
source_root=$test_root/source/$archive_root
install_root=$test_root/data/bergerraider-ecu-studio
legacy_root=$test_root/data/bergerraider-ecu-studio-preview-1

mkdir -p \
    "$source_root/bin" \
    "$source_root/lib/runtime" \
    "$source_root/lib/app/lib/linux/64" \
    "$source_root/config" \
    "$source_root/customize" \
    "$source_root/logs" \
    "$source_root/roms" \
    "$source_root/repositories" \
    "$source_root/definitions/Evo" \
    "$source_root/definitions/Evo/release/EcuFlash" \
    "$source_root/definitions/Evo/release/RomRaider" \
    "$source_root/definitions/Foz/Editor" \
    "$source_root/definitions/Foz/Logger" \
    "$source_root/definitions/Foz/Profiles"
touch \
    "$source_root/lib/runtime/release" \
    "$source_root/lib/app/BergerRaider.jar" \
    "$source_root/lib/app/lib/linux/64/j2534.so" \
    "$source_root/definitions/Evo/88780008_MUT2_logger.xml" \
    "$source_root/definitions/Evo/release/EcuFlash/88780008_Final_v6.xml" \
    "$source_root/definitions/Evo/release/EcuFlash/evo9base.xml" \
    "$source_root/definitions/Evo/release/RomRaider/88780008_RomRaider_Final_v4.xml" \
    "$source_root/definitions/Foz/Editor/Z2WC412I_DM23100_RR.xml" \
    "$source_root/definitions/Foz/Logger/logger_METRIC_EN_v370.xml" \
    "$source_root/definitions/Foz/Profiles/foz-6mt-swap-validation.xml" \
    "$source_root/definitions/Foz/Profiles/shinji.xml"
printf '%s\n' \
    '<settings><logger>' \
    '<protocol name="SSM" transport="ISO9141" module="ECU" fastpoll="false" library=""/>' \
    '<profile path="definitions/Foz/Profiles/shinji.xml"/>' \
    '</logger></settings>' >"$source_root/config/settings.foz.xml"
printf 'linux=j2534.so\n' >"$source_root/customize/j2534Libraries.properties"
printf '[JavaOptions]\njava-options=-Dbergerraider.settings.dir=$APPDIR/../../config/user\n' \
    >"$source_root/lib/app/BergerRaider.cfg"
printf '#!/bin/sh\nprintf "%%s\\n" "$@" >"$BERGERRAIDER_TEST_ARGS"\n' \
    >"$source_root/bin/BergerRaider"
chmod +x "$source_root/bin/BergerRaider"

archive_sha=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb

mkdir -p "$legacy_root/config/user" "$legacy_root/logs"
touch "$legacy_root/.installed-by-subaru-ecu-tools"
printf '<settings migrated="true"/>\n' >"$legacy_root/config/user/settings.xml"
printf 'legacy log\n' >"$legacy_root/logs/preserved.csv"

BERGERRAIDER_INSTALL_ROOT="$install_root" \
BERGERRAIDER_LEGACY_INSTALL_ROOT="$legacy_root" \
BERGERRAIDER_SOURCE_ROOT="$source_root" \
BERGERRAIDER_SHA256="$archive_sha" \
    "$repo_root/linux/install-bergerraider" >"$test_root/install.log"

test -x "$install_root/bin/BergerRaider"
test -f "$install_root/lib/runtime/release"
test -f "$install_root/lib/app/BergerRaider.jar"
test -f "$install_root/config/user/settings.xml"
test -f "$install_root/definitions/Foz/Profiles/foz-6mt-swap-validation.xml"
grep -F 'migrated="true"' "$install_root/config/user/settings.xml" >/dev/null
test -f "$install_root/logs/preserved.csv"
test ! -e "$legacy_root"
test -f "$install_root/.installed-by-subaru-ecu-tools"
grep -Fx "$archive_sha" "$install_root/.release-sha256" >/dev/null
grep -F 'BergerRaider 1.1.0 release candidate installed' "$test_root/install.log" >/dev/null

BERGERRAIDER_INSTALL_ROOT="$install_root" \
BERGERRAIDER_SOURCE_ROOT="$source_root" \
BERGERRAIDER_SHA256="$archive_sha" \
    "$repo_root/linux/install-bergerraider" >"$test_root/recheck.log"
grep -F 'already current' "$test_root/recheck.log" >/dev/null
test "$(find "$test_root/data" -maxdepth 1 -name 'bergerraider-ecu-studio.backup-*' | wc -l)" -eq 0

printf '%s\n' \
    '<settings preserved="true"><logger>' \
    '<serial port="ttyS0" refresh="true"/>' \
    '<protocol name="OBD" transport="ISO15765" module="ECU" fastpoll="false" library=""/>' \
    '<profile path="definitions/Foz/Profiles/aem-uego-9600.xml"/>' \
    '</logger></settings>' >"$install_root/config/user/settings.xml"
updated_sha=dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
BERGERRAIDER_INSTALL_ROOT="$install_root" \
BERGERRAIDER_SOURCE_ROOT="$source_root" \
BERGERRAIDER_SHA256="$updated_sha" \
    "$repo_root/linux/install-bergerraider" >"$test_root/update.log"
grep -F 'preserved="true"' "$install_root/config/user/settings.xml" >/dev/null
grep -F '<serial port="" refresh="true"/>' \
    "$install_root/config/user/settings.xml" >/dev/null
grep -F '<protocol name="SSM" transport="ISO9141"' \
    "$install_root/config/user/settings.xml" >/dev/null
grep -F '<profile path="definitions/Foz/Profiles/shinji.xml"/>' \
    "$install_root/config/user/settings.xml" >/dev/null
grep -F 'Migrated the obsolete Forester OBD logger default' \
    "$test_root/update.log" >/dev/null
test -f "$install_root/logs/preserved.csv"
grep -Fx "$updated_sha" "$install_root/.release-sha256" >/dev/null
test "$(find "$test_root/data" -maxdepth 1 -name 'bergerraider-ecu-studio.backup-*' | wc -l)" -eq 1

mkdir -p "$test_root/home" "$test_root/sysfs" "$test_root/dev"
HOME="$test_root/home" \
XDG_STATE_HOME="$test_root/state-home" \
BERGERRAIDER_HOME="$install_root" \
BERGERRAIDER_MODE=logger \
BERGERRAIDER_TEST_ARGS="$test_root/java-args" \
OPENPORT_USB_SYSFS_ROOT="$test_root/sysfs" \
OPENPORT_USB_DEV_ROOT="$test_root/dev" \
    "$repo_root/linux/launch-bergerraider"
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
BERGERRAIDER_SOURCE_ROOT="$source_root" \
BERGERRAIDER_SHA256="$updated_sha" \
SUBARU_SETUP_NO_PAUSE=1 \
    "$repo_root/linux/install-cachyos.sh" --install-bergerraider \
    >"$test_root/full-install.log"
test -x "$test_root/full-data/bergerraider-ecu-studio/bin/BergerRaider"
test -x "$test_root/full-bin/launch-bergerraider"
test -f "$test_root/full-data/applications/bergerraider-editor.desktop"
test -f "$test_root/full-data/applications/bergerraider-logger.desktop"
test -L "$test_root/full-home/Documents/Subaru & Evo ECU Tools/BergerRaider/Definitions"
grep -F 'PREPARING BERGERRAIDER LAUNCHERS' \
    "$test_root/full-install.log" >/dev/null
if grep -Fq 'Checking dependencies' "$test_root/full-install.log"; then
    echo 'BergerRaider-only install unexpectedly entered the shared dependency check.' >&2
    exit 1
fi

grep -F 'bergerraider-1.1.0-rc1' \
    "$repo_root/linux/install-bergerraider" >/dev/null
grep -F 'b1abdf62c60196c45d54e48cb1467548b76b4e93f8fe12d30f5d00fa214517c7' \
    "$repo_root/linux/install-bergerraider" >/dev/null

echo 'BergerRaider installer tests passed.'
