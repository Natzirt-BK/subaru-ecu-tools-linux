#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_file="$root/wine-bridge/openport_driver.c"
loader_file="$root/wine-bridge/wine_unix_loader.c"
unix_file="$root/wine-bridge/openport_unixlib.c"
output_dir="$root/build-wine-bridge"
: "${LLVM_MINGW_ROOT:=/opt/llvm-mingw}"
: "${WINEBUILD:=winebuild}"
compiler="$LLVM_MINGW_ROOT/bin/x86_64-w64-mingw32-gcc"
ddk_include="$LLVM_MINGW_ROOT/x86_64-w64-mingw32/include/ddk"

mkdir -p "$output_dir"
"$compiler" -I"$ddk_include" -I/usr/include/wine -I"$root/wine-bridge" \
    -shared -nostdlib \
    -Wl,--subsystem,native -Wl,--entry,DriverEntry \
    -o "$output_dir/openport.sys" "$source_file" "$loader_file" -lntoskrnl -lntdll
"$WINEBUILD" \
    --builtin -m64 -F openport.sys "$output_dir/openport.sys"

cc -fPIC -shared -I/usr/include/wine -I/usr/include/wine/windows \
    -I/usr/include/libusb-1.0 \
    -I"$root/wine-bridge" -o "$output_dir/openport.so" "$unix_file" \
    -lusb-1.0 -lpthread

# WINEDLLPATH uses Wine's split builtin layout.  Keep it synchronized with
# the primary artifacts so EcuFlash cannot silently load a stale driver.
mkdir -p "$output_dir/winedll/x86_64-windows" "$output_dir/winedll/x86_64-unix"
install -m 0644 "$output_dir/openport.sys" "$output_dir/winedll/x86_64-windows/openport.sys"
install -m 0755 "$output_dir/openport.so" "$output_dir/winedll/x86_64-unix/openport.so"

file "$output_dir/openport.sys"
file "$output_dir/openport.so"
sha256sum "$output_dir/openport.sys"
sha256sum "$output_dir/openport.so"
