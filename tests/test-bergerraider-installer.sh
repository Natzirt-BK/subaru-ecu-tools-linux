#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT HUP INT TERM
archive_root=BergerRaider_ECU_Studio_Foundation_Preview_1
source_root=$test_root/source/$archive_root
install_root=$test_root/data/bergerraider-ecu-studio-preview-1

mkdir -p \
    "$source_root/app/jre32/bin" \
    "$source_root/app/lib/linux/32" \
    "$source_root/definitions/Evo/RomRaider_Logger" \
    "$source_root/definitions/Subaru/Editor" \
    "$source_root/definitions/Subaru/Logger"
touch \
    "$source_root/app/BergerRaider-32.jar" \
    "$source_root/app/lib/linux/32/j2534.so" \
    "$source_root/definitions/Evo/RomRaider_Logger/88780008_MUT2_logger.xml" \
    "$source_root/definitions/Subaru/Editor/ecu_defs_METRIC.xml" \
    "$source_root/definitions/Subaru/Logger/logger_METRIC_EN_v370.xml"
for executable in START_LOGGER_LINUX.sh START_EDITOR_LINUX.sh app/jre32/bin/java; do
    printf '#!/bin/sh\nexit 0\n' >"$source_root/$executable"
    chmod +x "$source_root/$executable"
done

archive_sha=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb

BERGERRAIDER_INSTALL_ROOT="$install_root" \
BERGERRAIDER_SOURCE_ROOT="$source_root" \
BERGERRAIDER_SHA256="$archive_sha" \
    "$repo_root/linux/install-bergerraider-preview" >"$test_root/install.log"

test -x "$install_root/START_LOGGER_LINUX.sh"
test -x "$install_root/app/jre32/bin/java"
test -f "$install_root/.installed-by-subaru-ecu-tools"
grep -Fx "$archive_sha" "$install_root/.release-sha256" >/dev/null
grep -F 'Optional BergerRaider preview installed' "$test_root/install.log" >/dev/null

BERGERRAIDER_INSTALL_ROOT="$install_root" \
BERGERRAIDER_SOURCE_ROOT="$source_root" \
BERGERRAIDER_SHA256="$archive_sha" \
    "$repo_root/linux/install-bergerraider-preview" >"$test_root/recheck.log"
grep -F 'already current' "$test_root/recheck.log" >/dev/null
test "$(find "$test_root/data" -maxdepth 1 -name 'bergerraider-ecu-studio-preview-1.backup-*' | wc -l)" -eq 0

grep -F 'bergerraider-foundation-preview-1' \
    "$repo_root/linux/install-bergerraider-preview" >/dev/null
grep -F '7b67c97f49b02f9a9a998d4380fa390e7b964eb144756ed3bd82ff7f60140b77' \
    "$repo_root/linux/install-bergerraider-preview" >/dev/null

echo 'Optional BergerRaider installer tests passed.'
