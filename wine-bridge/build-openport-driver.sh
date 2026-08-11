#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_file="$root/wine-bridge/openport_driver.c"
loader_file="$root/wine-bridge/wine_unix_loader.c"
unix_file="$root/wine-bridge/openport_unixlib.c"
output_dir="$root/build-wine-bridge"
: "${LLVM_MINGW_ROOT:=/opt/llvm-mingw}"
: "${WINEBUILD:=winebuild}"
: "${WINE_CRT0:=/usr/lib/wine/i386-windows/libwinecrt0.a}"
compiler="$LLVM_MINGW_ROOT/bin/x86_64-w64-mingw32-gcc"
compiler32="$LLVM_MINGW_ROOT/bin/i686-w64-mingw32-gcc"
ddk_include="$LLVM_MINGW_ROOT/x86_64-w64-mingw32/include/ddk"

mkdir -p "$output_dir"
"$compiler" -DOPENPORT_KERNEL_BUILD -I"$ddk_include" -I/usr/include/wine -I"$root/wine-bridge" \
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

# EcuFlash is 32-bit. These split Wine builtins expose its J2534 API while
# implementing the protocol in the native 64-bit libusb library.
crt_object_dir="$output_dir/winecrt0-i386"
mkdir -p "$crt_object_dir"
(cd "$crt_object_dir" && ar x "$WINE_CRT0" unix_lib.o)
"$compiler32" -shared -Wl,--allow-multiple-definition \
    -I/usr/include/wine -I/usr/include/wine/windows -I"$root/wine-bridge" \
    -o "$output_dir/op20pt32.dll" \
    "$root/wine-bridge/frontend.c" "$crt_object_dir/unix_lib.o" \
    "$root/wine-bridge/op20pt32.def" -lntdll
"$WINEBUILD" --builtin -m32 -F op20pt32.dll "$output_dir/op20pt32.dll"
"$compiler32" -O2 -o "$output_dir/j2534-probe.exe" "$root/wine-bridge/probe.c"
"$compiler32" -O2 -o "$output_dir/openport-device-probe.exe" \
    "$root/wine-bridge/device_probe.c" -lsetupapi -ladvapi32
cc -O2 -fPIC -shared -I/usr/include/wine -I/usr/include/wine/windows \
    -I/usr/include/libusb-1.0 -I"$root/wine-bridge" -I"$root/j2534" \
    -o "$output_dir/op20pt32.so" \
    "$root/wine-bridge/unixlib.c" "$root/j2534/j2534.c" -lusb-1.0
mkdir -p "$output_dir/winedll/i386-windows"
for name in op20pt32 j2534; do
    install -m 0644 "$output_dir/op20pt32.dll" \
        "$output_dir/winedll/i386-windows/$name.dll"
    install -m 0755 "$output_dir/op20pt32.so" \
        "$output_dir/winedll/x86_64-unix/$name.so"
done

file "$output_dir/openport.sys"
file "$output_dir/openport.so"
sha256sum "$output_dir/openport.sys"
sha256sum "$output_dir/openport.so"
file "$output_dir/op20pt32.dll"
file "$output_dir/op20pt32.so"
sha256sum "$output_dir/op20pt32.dll"
sha256sum "$output_dir/op20pt32.so"
file "$output_dir/j2534-probe.exe"
sha256sum "$output_dir/j2534-probe.exe"
file "$output_dir/openport-device-probe.exe"
sha256sum "$output_dir/openport-device-probe.exe"
