#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT HUP INT TERM
archive_root=BergerRaider_ECU_Studio_Foundation_Preview_1
source_root=$test_root/source/$archive_root
install_root=$test_root/data/bergerraider-ecu-studio-preview-1

mkdir -p \
    "$source_root/bin" \
    "$source_root/lib/runtime" \
    "$source_root/lib/app/lib/linux/64" \
    "$source_root/config" \
    "$source_root/definitions/Evo" \
    "$source_root/definitions/Foz/Editor" \
    "$source_root/definitions/Foz/Logger"
touch \
    "$source_root/lib/runtime/release" \
    "$source_root/lib/app/BergerRaider.jar" \
    "$source_root/lib/app/lib/linux/64/j2534.so" \
    "$source_root/definitions/Evo/88780008_MUT2_logger.xml" \
    "$source_root/definitions/Foz/Editor/Z2WC412I_DM23100_RR.xml" \
    "$source_root/definitions/Foz/Logger/logger_METRIC_EN_v370.xml"
printf '<settings/>\n' >"$source_root/config/settings.foz.xml"
printf '[JavaOptions]\njava-options=-Dbergerraider.settings.dir=$APPDIR/../../config/user\n' \
    >"$source_root/lib/app/BergerRaider.cfg"
printf '#!/bin/sh\nprintf "%%s\\n" "$@" >"$BERGERRAIDER_TEST_ARGS"\n' \
    >"$source_root/bin/BergerRaider"
chmod +x "$source_root/bin/BergerRaider"

archive_sha=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb

BERGERRAIDER_INSTALL_ROOT="$install_root" \
BERGERRAIDER_SOURCE_ROOT="$source_root" \
BERGERRAIDER_SHA256="$archive_sha" \
    "$repo_root/linux/install-bergerraider-preview" >"$test_root/install.log"

test -x "$install_root/bin/BergerRaider"
test -f "$install_root/lib/runtime/release"
test -f "$install_root/lib/app/BergerRaider.jar"
test -f "$install_root/config/user/settings.xml"
test -f "$install_root/.installed-by-subaru-ecu-tools"
grep -Fx "$archive_sha" "$install_root/.release-sha256" >/dev/null
grep -F 'Optional BergerRaider preview installed' "$test_root/install.log" >/dev/null

BERGERRAIDER_INSTALL_ROOT="$install_root" \
BERGERRAIDER_SOURCE_ROOT="$source_root" \
BERGERRAIDER_SHA256="$archive_sha" \
    "$repo_root/linux/install-bergerraider-preview" >"$test_root/recheck.log"
grep -F 'already current' "$test_root/recheck.log" >/dev/null
test "$(find "$test_root/data" -maxdepth 1 -name 'bergerraider-ecu-studio-preview-1.backup-*' | wc -l)" -eq 0

printf '<settings preserved="true"/>\n' \
    >"$install_root/config/user/settings.xml"
updated_sha=dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
BERGERRAIDER_INSTALL_ROOT="$install_root" \
BERGERRAIDER_SOURCE_ROOT="$source_root" \
BERGERRAIDER_SHA256="$updated_sha" \
    "$repo_root/linux/install-bergerraider-preview" >"$test_root/update.log"
grep -F 'preserved="true"' "$install_root/config/user/settings.xml" >/dev/null
grep -Fx "$updated_sha" "$install_root/.release-sha256" >/dev/null
test "$(find "$test_root/data" -maxdepth 1 -name 'bergerraider-ecu-studio-preview-1.backup-*' | wc -l)" -eq 1

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

grep -F 'bergerraider-foundation-preview-1' \
    "$repo_root/linux/install-bergerraider-preview" >/dev/null
grep -F '7b67c97f49b02f9a9a998d4380fa390e7b964eb144756ed3bd82ff7f60140b77' \
    "$repo_root/linux/install-bergerraider-preview" >/dev/null

echo 'Optional BergerRaider installer tests passed.'
