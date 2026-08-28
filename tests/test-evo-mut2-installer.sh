#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT HUP INT TERM
archive_root=RomRaider_MUT2_88780008_Release_v1.0.1
source_root=$test_root/source/$archive_root
install_root=$test_root/data/romraider-mut2-evo-88780008

mkdir -p \
    "$source_root/app/jre32/bin" \
    "$source_root/app/lib/linux/32" \
    "$source_root/app/i18n/com/romraider" \
    "$source_root/definitions/RomRaider_Logger" \
    "$source_root/definitions/RomRaider_Profiles"
touch \
    "$source_root/app/RomRaider-MUT2-88780008-32.jar" \
    "$source_root/app/lib/linux/32/j2534.so" \
    "$source_root/app/i18n/com/romraider/ECUExec.properties" \
    "$source_root/definitions/RomRaider_Logger/88780008_MUT2_logger.xml" \
    "$source_root/definitions/RomRaider_Profiles/88780008_MUT2_Tuning_Profile.xml"
for executable in START_LOGGER_LINUX.sh START_EDITOR_LINUX.sh app/jre32/bin/java; do
    printf '#!/bin/sh\nexit 0\n' >"$source_root/$executable"
    chmod +x "$source_root/$executable"
done

archive_sha=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

EVO_MUT2_INSTALL_ROOT="$install_root" \
EVO_MUT2_SOURCE_ROOT="$source_root" \
EVO_MUT2_SHA256="$archive_sha" \
    "$repo_root/linux/install-evo-romraider-mut2" >"$test_root/install.log"

test -x "$install_root/START_LOGGER_LINUX.sh"
test -x "$install_root/app/jre32/bin/java"
test -f "$install_root/.installed-by-subaru-ecu-tools"
grep -Fx "$archive_sha" "$install_root/.release-sha256" >/dev/null
grep -F 'Optional Evo MUT-Raider-II installed' "$test_root/install.log" >/dev/null

EVO_MUT2_INSTALL_ROOT="$install_root" \
EVO_MUT2_SOURCE_ROOT="$source_root" \
EVO_MUT2_SHA256="$archive_sha" \
    "$repo_root/linux/install-evo-romraider-mut2" >"$test_root/recheck.log"
grep -F 'already current' "$test_root/recheck.log" >/dev/null
test "$(find "$test_root/data" -maxdepth 1 -name 'romraider-mut2-evo-88780008.backup-*' | wc -l)" -eq 0

grep -F 'romraider-mut2-evo-88780008-v1.0.1' \
    "$repo_root/linux/install-evo-romraider-mut2" >/dev/null
grep -F '27a026afbe25d0759c15d29daa27b7003e9e4de903dde8507aa920457f4c005f' \
    "$repo_root/linux/install-evo-romraider-mut2" >/dev/null

echo 'Optional Evo RomRaider installer tests passed.'
