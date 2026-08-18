#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_file="$root/wine-bridge/openport_driver.c"
loader_file="$root/wine-bridge/wine_unix_loader.c"
unix_file="$root/wine-bridge/openport_unixlib.c"
output_dir="$root/build-wine-bridge"
: "${LLVM_MINGW_ROOT:=/opt/llvm-mingw}"

first_executable() {
    for candidate do
        if [ -x "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
        if command -v "$candidate" >/dev/null 2>&1; then
            command -v "$candidate"
            return 0
        fi
    done
    return 1
}

first_directory() {
    for candidate do
        if [ -d "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

first_file() {
    for candidate do
        if [ -f "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

compiler=${MINGW64_CC:-}
[ -n "$compiler" ] || compiler=$(first_executable \
    "$LLVM_MINGW_ROOT/bin/x86_64-w64-mingw32-gcc" \
    x86_64-w64-mingw32-gcc) || {
    echo 'Missing x86_64 MinGW C compiler.' >&2
    exit 1
}
compiler32=${MINGW32_CC:-}
[ -n "$compiler32" ] || compiler32=$(first_executable \
    "$LLVM_MINGW_ROOT/bin/i686-w64-mingw32-gcc" \
    i686-w64-mingw32-gcc) || {
    echo 'Missing i686 MinGW C compiler.' >&2
    exit 1
}
ddk_include=${MINGW64_DDK_INCLUDE:-}
[ -n "$ddk_include" ] || ddk_include=$(first_directory \
    "$LLVM_MINGW_ROOT/x86_64-w64-mingw32/include/ddk" \
    /usr/x86_64-w64-mingw32/include/ddk) || {
    echo 'Missing MinGW DDK headers.' >&2
    exit 1
}
wine_include=${WINE_INCLUDE:-}
[ -n "$wine_include" ] || wine_include=$(first_directory /usr/include/wine) || {
    echo 'Missing Wine development headers.' >&2
    exit 1
}
wine_windows_include=${WINE_WINDOWS_INCLUDE:-}
[ -n "$wine_windows_include" ] || wine_windows_include=$(first_directory \
    /usr/include/wine/windows /usr/include/wine/wine/windows) || {
    echo 'Missing Wine Windows development headers.' >&2
    exit 1
}
WINEBUILD=${WINEBUILD:-}
[ -n "$WINEBUILD" ] || WINEBUILD=$(first_executable winebuild winebuild-stable) || {
    echo 'Missing winebuild (Wine developer tools).' >&2
    exit 1
}
WINE_CRT0=${WINE_CRT0:-}
[ -n "$WINE_CRT0" ] || WINE_CRT0=$(first_file \
    /usr/lib/wine/i386-windows/libwinecrt0.a \
    /usr/lib/x86_64-linux-gnu/wine/i386-windows/libwinecrt0.a \
    /usr/lib/x86_64-linux-gnu/wine/libwinecrt0.a) || {
    echo 'Missing Wine i386 startup library (libwinecrt0.a).' >&2
    exit 1
}
libusb_include=${LIBUSB_INCLUDE:-/usr/include/libusb-1.0}
[ -f "$libusb_include/libusb.h" ] || {
    echo "Missing libusb development header: $libusb_include/libusb.h" >&2
    exit 1
}
for required_tool in ar cc file install sha256sum; do
    command -v "$required_tool" >/dev/null 2>&1 || {
        echo "Missing required build tool: $required_tool" >&2
        exit 1
    }
done

if [ "${1:-}" = --check ]; then
    printf 'MINGW64_CC=%s\nMINGW32_CC=%s\nMINGW64_DDK_INCLUDE=%s\n' \
        "$compiler" "$compiler32" "$ddk_include"
    printf 'WINE_INCLUDE=%s\nWINE_WINDOWS_INCLUDE=%s\nWINEBUILD=%s\nWINE_CRT0=%s\n' \
        "$wine_include" "$wine_windows_include" "$WINEBUILD" "$WINE_CRT0"
    printf 'LIBUSB_INCLUDE=%s\n' "$libusb_include"
    exit 0
fi
[ "$#" -eq 0 ] || {
    echo "Usage: $0 [--check]" >&2
    exit 2
}

mkdir -p "$output_dir"
"$compiler" -DOPENPORT_KERNEL_BUILD -I"$ddk_include" -I"$wine_include" \
    -I"$root/wine-bridge" \
    -shared -nostdlib \
    -Wl,--subsystem,native -Wl,--entry,DriverEntry \
    -o "$output_dir/openport.sys" "$source_file" "$loader_file" -lntoskrnl -lntdll
"$WINEBUILD" \
    --builtin -m64 -F openport.sys "$output_dir/openport.sys"

cc -fPIC -shared -I"$wine_include" -I"$wine_windows_include" \
    -I"$libusb_include" \
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
    -I"$wine_include" -I"$wine_windows_include" -I"$root/wine-bridge" \
    -o "$output_dir/op20pt32.dll" \
    "$root/wine-bridge/frontend.c" "$crt_object_dir/unix_lib.o" \
    "$root/wine-bridge/op20pt32.def" -lntdll
"$WINEBUILD" --builtin -m32 -F op20pt32.dll "$output_dir/op20pt32.dll"
"$compiler32" -O2 -o "$output_dir/j2534-probe.exe" "$root/wine-bridge/probe.c"
"$compiler32" -O2 -o "$output_dir/openport-device-probe.exe" \
    "$root/wine-bridge/device_probe.c" -lsetupapi -ladvapi32
cc -O2 -fPIC -shared -I"$wine_include" -I"$wine_windows_include" \
    -I"$libusb_include" -I"$root/wine-bridge" -I"$root/j2534" \
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
