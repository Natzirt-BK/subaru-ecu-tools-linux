#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
installer=$repo_root/linux/install-cachyos.sh
bridge_builder=$repo_root/wine-bridge/build-openport-driver.sh
workflow=$repo_root/.github/workflows/validate.yml

# The 32-bit J2534 Wine builtin is linked from Debian's i386 startup archive.
# The amd64 development package contains only x86_64 libwinecrt0 archives.
grep -F 'libwine-dev libwine-dev:i386 gcc-mingw-w64' "$installer" >/dev/null
grep -F 'libwine-dev libwine-dev:i386 wine64-tools gcc-mingw-w64' \
    "$installer" >/dev/null
grep -F 'libwine-dev libwine-dev:i386 gcc-mingw-w64' "$workflow" >/dev/null
grep -F '/usr/lib/i386-linux-gnu/wine/i386-windows/libwinecrt0.a' \
    "$bridge_builder" >/dev/null
test -f "$repo_root/wine-bridge/wine_unixlib_compat.h"
! grep -R -E '#include <(wine/)?unixlib\.h>' "$repo_root/wine-bridge" >/dev/null

echo 'Debian dependency tests passed.'
