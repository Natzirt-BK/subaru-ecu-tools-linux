#!/usr/bin/env bash
set -euo pipefail

wine_source_url=https://gitlab.winehq.org/wine/wine.git
wine_source_commit=e75ddb5f5d8874eecf8e8c1742e6aaa4db9cd4a3
work_root=${1:-$PWD/ecuflash-wine-build}
source_dir="$work_root/source"
build_dir="$work_root/build"
install_dir="$work_root/ecuflash-wine-11.1"

mkdir -p "$work_root"
if [[ ! -d "$source_dir/.git" ]]; then
    git clone "$wine_source_url" "$source_dir"
fi
git -C "$source_dir" fetch origin "$wine_source_commit"
git -C "$source_dir" checkout --detach "$wine_source_commit"

mkdir -p "$build_dir"
cd "$build_dir"
"$source_dir/configure" \
    --prefix="$install_dir" \
    --enable-archs=i386,x86_64 \
    --disable-tests
make -j"$(nproc)"
make install
cp "$source_dir/COPYING.LIB" "$install_dir/COPYING.LIB"

echo "Wine runtime installed at: $install_dir"
