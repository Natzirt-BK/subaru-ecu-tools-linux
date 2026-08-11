#!/usr/bin/env bash
set -euo pipefail

state_root=${XDG_STATE_HOME:-$HOME/.local/state}/subaru-ecu-tools-linux
prefix=${XDG_DATA_HOME:-$HOME/.local/share}/ecuflash-proton
data_root=${XDG_DATA_HOME:-$HOME/.local/share}/subaru-ecu-tools-linux
expected_dll=f432084801762d919a3c31974616e097562424470003edc4f4fb843df34103cf
result=0

check() {
    local description=$1
    shift
    if "$@"; then printf 'PASS  %s\n' "$description"
    else printf 'FAIL  %s\n' "$description"; result=1
    fi
}

latest_ecuflash_log=$(find "$prefix/drive_c/users" -type f \
    -path '*/OpenECU/EcuFlash/logs/*' -printf '%T@ %p\n' 2>/dev/null | \
    sort -nr | head -1 | cut -d' ' -f2- || true)

check 'installed EcuFlash executable' test -f \
    "$prefix/drive_c/Program Files (x86)/OpenECU/EcuFlash/ecuflash.exe"
check 'packaged Wine runtime' test -x "$data_root/runtime/ecuflash-winegdk-11.1/files/bin/wine"
check 'official Tactrix DLL checksum' bash -c \
    "printf '%s  %s\\n' '$expected_dll' '$prefix/drive_c/windows/syswow64/op20pt32.dll' | sha256sum -c - >/dev/null"
check 'OpenPort visible in Linux' bash -c "lsusb -d 0403:cc4d >/dev/null"
check 'fresh EcuFlash application log exists' test -n "$latest_ecuflash_log"
if [[ -n "$latest_ecuflash_log" ]]; then
    if [[ -n "${ECUFLASH_LOG_NOT_OLDER_THAN:-}" ]]; then
        check 'EcuFlash log belongs to this test launch' bash -c \
            "[[ \$(stat -c %Y \"\$1\") -ge \$2 ]]" _ \
            "$latest_ecuflash_log" "$ECUFLASH_LOG_NOT_OLDER_THAN"
    fi
    check 'EcuFlash loaded official J2534 DLL' grep -q 'J2534 DLL Version: 1\.02\.4870' "$latest_ecuflash_log"
    check 'EcuFlash read the adapter serial' grep -q 'Device Serial Number:' "$latest_ecuflash_log"
    check 'EcuFlash has no final no-device error' bash -c \
        "! tail -80 '$latest_ecuflash_log' | grep -qi 'J2534 error.*no devices available'"
fi
check 'installer diagnostic log exists' test -e "$state_root/latest.log"

printf '\nEcuFlash log: %s\n' "${latest_ecuflash_log:-none}"
printf 'Installer log: %s/latest.log\n' "$state_root"
exit "$result"
