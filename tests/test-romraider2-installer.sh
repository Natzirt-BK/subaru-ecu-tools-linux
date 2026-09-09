#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT HUP INT TERM
archive_root=RomRaider2_ECU_Studio_1.1.9_Linux_x64
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
printf 'RomRaider2 ECU Studio 1.1.9\n' \
    >"$source_root/VERSION.txt"
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

mkdir -p "$legacy_root/config/user/definitions/logger" \
    "$legacy_root/config/user/profiles" "$legacy_root/config/user/recovery" \
    "$legacy_root/definitions" "$legacy_root/profiles" "$legacy_root/logs" \
    "$legacy_root/lib/app" "$legacy_root/bin"
touch "$legacy_root/.installed-by-subaru-ecu-tools"
printf '<settings migrated="true"/>\n' >"$legacy_root/config/user/settings.xml"
printf 'legacy log\n' >"$legacy_root/logs/preserved.csv"
for user_file in config/user/definitions/logger/logger.xml \
        config/user/profiles/profile_backup.xml config/user/recovery/synthetic.workspace \
        config/user/custom-preferences.txt definitions/custom.xml profiles/custom.xml; do
    printf 'synthetic user content: %s\n' "$user_file" >"$legacy_root/$user_file"
done
printf 'unknown custom file\n' >"$legacy_root/personal-notes.txt"
printf 'obsolete executable\n' >"$legacy_root/bin/RomRaider2"
printf 'obsolete jar\n' >"$legacy_root/lib/app/RomRaider2.jar"

ROMRAIDER2_INSTALL_ROOT="$install_root" \
ROMRAIDER2_LEGACY_INSTALL_ROOT="$legacy_root" \
ROMRAIDER2_SOURCE_ROOT="$source_root" \
ROMRAIDER2_SHA256="$archive_sha" \
    "$repo_root/linux/install-romraider2" >"$test_root/install.log"

test -x "$install_root/bin/RomRaider2"
test -f "$install_root/lib/runtime/release"
test -f "$install_root/lib/app/RomRaider2.jar"
test -f "$install_root/config/user/settings.xml"
for user_file in config/user/definitions/logger/logger.xml \
        config/user/profiles/profile_backup.xml config/user/recovery/synthetic.workspace \
        config/user/custom-preferences.txt definitions/custom.xml profiles/custom.xml; do
    cmp "$legacy_root/$user_file" "$install_root/$user_file"
done
cmp "$legacy_root/config/user/settings.xml" "$install_root/config/user/settings.xml"
cmp "$source_root/bin/RomRaider2" "$install_root/bin/RomRaider2"
cmp "$source_root/lib/app/RomRaider2.jar" "$install_root/lib/app/RomRaider2.jar"
test -f "$legacy_root/personal-notes.txt"
grep -F 'Retained predecessor unchanged' "$test_root/install.log" >/dev/null
grep -F 'migrated="true"' "$install_root/config/user/settings.xml" >/dev/null
test -f "$install_root/logs/preserved.csv"
test -d "$legacy_root"
test -f "$install_root/.installed-by-subaru-ecu-tools"
grep -Fx "$archive_sha" "$install_root/.release-sha256" >/dev/null
grep -F 'RomRaider2 1.1.9 installed' "$test_root/install.log" >/dev/null

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
# Current installation wins; do not resurrect files from the retained legacy copy.
printf 'stale file\n' >"$legacy_root/profiles/legacy-only.xml"
printf 'current profile\n' >"$install_root/profiles/custom.xml"
printf 'current unknown custom file\n' >"$install_root/personal-notes.txt"
ROMRAIDER2_INSTALL_ROOT="$install_root" \
ROMRAIDER2_LEGACY_INSTALL_ROOT="$legacy_root" \
ROMRAIDER2_SOURCE_ROOT="$source_root" \
ROMRAIDER2_SHA256="$updated_sha" \
    "$repo_root/linux/install-romraider2" >"$test_root/update.log"
grep -F 'preserved="true"' "$install_root/config/user/settings.xml" >/dev/null
grep -F '<profile path="definitions/Foz/Profiles/aem-uego-9600.xml"/>' \
    "$install_root/config/user/settings.xml" >/dev/null
test ! -e "$install_root/profiles/legacy-only.xml"
grep -Fx 'current profile' "$install_root/profiles/custom.xml" >/dev/null
test -f "$install_root/config/user/definitions/logger/logger.xml"
test -f "$install_root/config/user/recovery/synthetic.workspace"
for backup_root in "$test_root/data"/romraider2-ecu-studio.backup-*; do
    cmp "$backup_root/config/user/settings.xml" "$install_root/config/user/settings.xml"
    cmp "$backup_root/profiles/custom.xml" "$install_root/profiles/custom.xml"
    grep -Fx 'current unknown custom file' "$backup_root/personal-notes.txt" >/dev/null
done
cmp "$source_root/bin/RomRaider2" "$install_root/bin/RomRaider2"
test -f "$install_root/logs/preserved.csv"
grep -Fx "$updated_sha" "$install_root/.release-sha256" >/dev/null
test "$(find "$test_root/data" -maxdepth 1 -name 'romraider2-ecu-studio.backup-*' | wc -l)" -eq 1

# A migration copy failure must not disturb the active installation or old copy.
mkdir -p "$test_root/fault-bin"
RR2_TEST_REAL_CP=$(command -v cp)
RR2_TEST_REAL_MV=$(command -v mv)
export RR2_TEST_REAL_CP RR2_TEST_REAL_MV
cat >"$test_root/fault-bin/cp" <<'EOF'
#!/bin/sh
case "$*" in *config/user/.*) echo 'Injected migration failure' >&2; exit 71 ;; esac
exec "$RR2_TEST_REAL_CP" "$@"
EOF
chmod +x "$test_root/fault-bin/cp"
if PATH="$test_root/fault-bin:$PATH" \
        ROMRAIDER2_INSTALL_ROOT="$install_root" \
        ROMRAIDER2_LEGACY_INSTALL_ROOT="$legacy_root" \
        ROMRAIDER2_SOURCE_ROOT="$source_root" ROMRAIDER2_SHA256="$archive_sha" \
        "$repo_root/linux/install-romraider2" >"$test_root/copy-failure.log" 2>&1; then
    echo 'Migration copy failure unexpectedly succeeded.' >&2; exit 1
fi
grep -Fx "$updated_sha" "$install_root/.release-sha256" >/dev/null
test -f "$install_root/config/user/definitions/logger/logger.xml"
test -f "$legacy_root/personal-notes.txt"
test "$(find "$test_root/data" -maxdepth 1 -name 'romraider2-ecu-studio.backup-*' | wc -l)" -eq 1
# Disable the copy fault; now fail only final activation, after backup creation.
chmod -x "$test_root/fault-bin/cp"
cat >"$test_root/fault-bin/mv" <<'EOF'
#!/bin/sh
case "$*" in */.romraider2-install.*/RomRaider2_ECU_Studio_*)
    echo 'Injected activation failure' >&2; exit 72 ;;
esac
exec "$RR2_TEST_REAL_MV" "$@"
EOF
chmod +x "$test_root/fault-bin/mv"
if PATH="$test_root/fault-bin:$PATH" \
        ROMRAIDER2_INSTALL_ROOT="$install_root" \
        ROMRAIDER2_LEGACY_INSTALL_ROOT="$legacy_root" \
        ROMRAIDER2_SOURCE_ROOT="$source_root" ROMRAIDER2_SHA256="$archive_sha" \
        "$repo_root/linux/install-romraider2" >"$test_root/move-failure.log" 2>&1; then
    echo 'Activation failure unexpectedly succeeded.' >&2; exit 1
fi
grep -F 'Restored the previous installation' "$test_root/move-failure.log" >/dev/null
grep -Fx "$updated_sha" "$install_root/.release-sha256" >/dev/null
test -f "$install_root/config/user/definitions/logger/logger.xml"
test "$(find "$test_root/data" -maxdepth 1 -name 'romraider2-ecu-studio.backup-*' | wc -l)" -eq 1
test "$(find "$test_root/data" -maxdepth 1 -name '.romraider2-install.*' | wc -l)" -eq 0

# Reject symlinked data roots without writing through them or removing the source.
mkdir -p "$test_root/linked-legacy" "$test_root/external-data"
printf 'outside sentinel\n' >"$test_root/external-data/sentinel"
ln -s "$test_root/external-data" "$test_root/linked-legacy/definitions"
if ROMRAIDER2_INSTALL_ROOT="$test_root/symlink case/new install" \
        ROMRAIDER2_LEGACY_INSTALL_ROOT="$test_root/linked-legacy" \
        ROMRAIDER2_SOURCE_ROOT="$source_root" ROMRAIDER2_SHA256="$archive_sha" \
        "$repo_root/linux/install-romraider2" >"$test_root/symlink-failure.log" 2>&1; then
    echo 'Symlinked migration root unexpectedly succeeded.' >&2; exit 1
fi
test -L "$test_root/linked-legacy/definitions"
grep -Fx 'outside sentinel' "$test_root/external-data/sentinel" >/dev/null
test ! -e "$test_root/symlink case/new install"

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
test ! -e "$test_root/full-home/Documents/Ecu Tools by NatZirt/RomRaider2/Definitions"
grep -F 'PREPARING ROMRAIDER2 LAUNCHERS' \
    "$test_root/full-install.log" >/dev/null
if grep -Fq 'Checking dependencies' "$test_root/full-install.log"; then
    echo 'RomRaider2-only install unexpectedly entered the shared dependency check.' >&2
    exit 1
fi
grep -F '[ RUN  ] Verifying the pinned RomRaider2 application image.' \
    "$test_root/full-install.log" >/dev/null
if grep -q '^  OK RomRaider2 1.1.9' \
        "$test_root/full-install.log"; then
    echo 'Nested RomRaider2 installer output escaped the setup console.' >&2
    exit 1
fi

grep -F 'romraider2-1.1.9' \
    "$repo_root/linux/install-romraider2" >/dev/null
grep -F '00189a0f241c70c9999666ebe2e534bf1d578fa37c9bba58b228164cf4e0f1e2' \
    "$repo_root/linux/install-romraider2" >/dev/null

echo 'RomRaider2 installer tests passed.'
