#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
mode=install
install_deps=false
install_udev=false
install_ecuflash=false
assume_yes=false

usage() {
    cat <<'EOF'
Usage: linux/install-cachyos.sh [options]

  --check          Check the system without building or installing anything
  --install-deps   Install missing CachyOS/Arch packages with sudo pacman
  --install-udev   Install the OpenPort 2.0 udev rule with sudo
  --install-ecuflash  Download and open Tactrix's official EcuFlash installer
  --yes-all        Select every optional installation component
  --uninstall      Remove files installed by Subaru ECU Tools
  --yes            Do not prompt before --uninstall
  -h, --help       Show this help

The default builds the bridge and installs user files under ~/.local.
It never installs RomRaider, ROMs, definitions, or vehicle firmware.
EOF
}

while (($#)); do
    case "$1" in
        --check) mode=check ;;
        --install-deps) install_deps=true ;;
        --install-udev) install_udev=true ;;
        --install-ecuflash) install_ecuflash=true ;;
        --yes-all) install_deps=true; install_udev=true; install_ecuflash=true ;;
        --uninstall) mode=uninstall ;;
        --yes) assume_yes=true ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

log_stamp=$(date +%Y%m%d-%H%M%S)
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/subaru-ecu-tools-linux"
if [[ "$mode" == uninstall ]]; then
    log_file="/tmp/subaru-ecu-tools-uninstall-$log_stamp.log"
else
    mkdir -p "$state_dir"
    log_file="$state_dir/setup-$log_stamp.log"
    ln -sfn "$(basename -- "$log_file")" "$state_dir/latest.log"
fi
exec > >(tee -a "$log_file") 2>&1
github_repo=Natzirt-BK/subaru-ecu-tools-linux
offer_error_report() {
    local answer report_file issue_url

    [[ -r /dev/tty ]] || return 0
    read -r -p "Upload this error log in a public GitHub issue so the maintainer can investigate? [y/N] " answer </dev/tty || return 0
    [[ "$answer" == [yY] || "$answer" == [yY][eE][sS] ]] || return 0

    if ! command -v gh >/dev/null 2>&1; then
        echo "Automatic upload requires GitHub CLI. Install 'github-cli', run 'gh auth login', then retry."
        echo "No log was uploaded. Your log remains at: $log_file"
        return 0
    fi
    if ! gh auth status --hostname github.com >/dev/null 2>&1; then
        echo "GitHub CLI is not signed in. Run 'gh auth login', then retry."
        echo "No log was uploaded. Your log remains at: $log_file"
        return 0
    fi

    report_file=$(mktemp /tmp/subaru-ecu-tools-report.XXXXXX)
    {
        echo "The installer offered to submit this report after a failed run."
        echo
        echo "Installer log (last 50,000 bytes):"
        echo '```text'
        tail -c 50000 "$log_file"
        echo
        echo '```'
    } >"$report_file"
    if issue_url=$(gh issue create --repo "$github_repo" \
        --title "Automated installer error report ($log_stamp)" \
        --body-file "$report_file"); then
        echo "Error report uploaded: $issue_url"
    else
        echo "GitHub upload failed. Your log remains at: $log_file" >&2
    fi
    rm -f -- "$report_file"
}
log_result() {
    local status=$?
    trap - EXIT
    if ((status)); then
        echo
        echo "Subaru ECU Tools stopped with status $status."
        echo "Share this diagnostic log when requesting help: $log_file"
        offer_error_report
    else
        echo "Diagnostic log: $log_file"
    fi
    exit "$status"
}
trap log_result EXIT

bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
data_root="${XDG_DATA_HOME:-$HOME/.local/share}"
data_dir="$data_root/subaru-ecu-tools-linux"
applications_dir="$data_root/applications"
cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/subaru-ecu-tools-linux"
ecuflash_prefix="${ECUFLASH_WINEPREFIX:-$data_root/ecuflash-proton}"
default_source_dir="$HOME/.local/src/subaru-ecu-tools-linux"

if [[ "$mode" == uninstall ]]; then
    echo "Subaru ECU Tools will remove:"
    printf '  %s\n' \
        "$bin_dir/launch-ecuflash" \
        "$bin_dir/launch-romraider" \
        "$data_dir" \
        "$ecuflash_prefix" \
        "$cache_root" \
        "$state_dir" \
        "$applications_dir/ecuflash.desktop" \
        "$applications_dir/romraider-editor.desktop" \
        "$applications_dir/romraider-logger.desktop" \
        "$applications_dir/subaru-ecu-tools-setup.desktop" \
        "/etc/udev/rules.d/99-openport2.rules"
    if [[ "$repo_root" == "$default_source_dir" ]]; then
        printf '  %s\n' "$default_source_dir"
    fi
    echo "RomRaider DimeMod, ROMs, definitions, logs, and shared packages are preserved."

    if ! $assume_yes; then
        read -r -p "Remove these Subaru ECU Tools files? [y/N] " answer
        [[ "$answer" == [yY] || "$answer" == [yY][eE][sS] ]] || {
            echo "Uninstall cancelled."
            exit 0
        }
    fi

    rm -f -- \
        "$bin_dir/launch-ecuflash" \
        "$bin_dir/launch-romraider" \
        "$applications_dir/ecuflash.desktop" \
        "$applications_dir/romraider-editor.desktop" \
        "$applications_dir/romraider-logger.desktop" \
        "$applications_dir/subaru-ecu-tools-setup.desktop"
    rm -rf -- "$data_dir" "$ecuflash_prefix" "$cache_root" "$state_dir"
    if [[ -e /etc/udev/rules.d/99-openport2.rules ]]; then
        sudo rm -f -- /etc/udev/rules.d/99-openport2.rules
        sudo udevadm control --reload-rules
        sudo udevadm trigger --subsystem-match=usb
    fi
    command -v update-desktop-database >/dev/null && \
        update-desktop-database "$applications_dir" >/dev/null 2>&1 || true
    if [[ "$repo_root" == "$default_source_dir" ]]; then
        rm -rf -- "$default_source_dir"
    fi
    echo "Subaru ECU Tools removal completed."
    echo "The final removal log is outside the installed paths: $log_file"
    exit 0
fi

if [[ ! -r /etc/os-release ]]; then
    echo "Cannot identify this Linux distribution." >&2
    exit 1
fi
# shellcheck disable=SC1091
source /etc/os-release
os_family="${ID:-} ${ID_LIKE:-}"
if [[ "$os_family" != *cachyos* && "$os_family" != *arch* ]]; then
    echo "Warning: designed for CachyOS/Arch; detected ${PRETTY_NAME:-unknown}." >&2
fi

packages=(base-devel curl libusb wine llvm-mingw)
missing=()
for package in "${packages[@]}"; do
    pacman -Q "$package" &>/dev/null || missing+=("$package")
done

if ((${#missing[@]})); then
    echo "Missing packages: ${missing[*]}"
    if $install_deps; then
        sudo pacman -S --needed "${missing[@]}"
    else
        echo "Re-run with --install-deps, or install them with:"
        echo "  sudo pacman -S --needed ${missing[*]}"
    fi
fi

checks_failed=0
check_path() {
    local description=$1 path=$2
    if [[ -e "$path" ]]; then
        printf 'OK: %s\n' "$description"
    else
        printf 'MISSING: %s (%s)\n' "$description" "$path"
        checks_failed=1
    fi
}

check_path "LLVM-MinGW compiler" /opt/llvm-mingw/bin/x86_64-w64-mingw32-gcc
check_path "LLVM-MinGW DDK headers" /opt/llvm-mingw/x86_64-w64-mingw32/include/ddk
check_path "Wine headers" /usr/include/wine/windows
check_path "libusb headers" /usr/include/libusb-1.0/libusb.h
command -v winebuild >/dev/null || { echo "MISSING: winebuild"; checks_failed=1; }
command -v cc >/dev/null || { echo "MISSING: C compiler"; checks_failed=1; }

if [[ "$mode" == check ]]; then
    check_data_root="${XDG_DATA_HOME:-$HOME/.local/share}"
    check_ecuflash="$check_data_root/ecuflash-proton/drive_c/Program Files (x86)/OpenECU/EcuFlash/ecuflash.exe"
    check_romraider="$check_data_root/romraider-dm20"
    [[ -f "$check_ecuflash" ]] && echo "OK: EcuFlash installed" || \
        echo "NOT INSTALLED: EcuFlash"
    if [[ -f "$check_romraider/RomRaider.jar" && -x "$check_romraider/jre32/bin/java" ]]; then
        echo "OK: RomRaider DimeMod with bundled 32-bit Java detected"
    else
        echo "NOT INSTALLED: complete RomRaider DimeMod Linux package"
    fi
    id -nG | tr ' ' '\n' | grep -qx uucp && echo "OK: user is in uucp group" || \
        echo "MISSING: user is not in uucp group (required by the Logger shortcut)"
    command -v lsusb >/dev/null && \
        lsusb -d 0403:cc4d >/dev/null 2>&1 && \
        echo "OK: Tactrix OpenPort 2.0 detected" || \
        echo "INFO: OpenPort 2.0 is not currently detected (safe to connect later)."
    exit "$checks_failed"
fi

if ((${#missing[@]})) && ! $install_deps; then
    echo "Dependencies are incomplete; no files were installed." >&2
    exit 1
fi
if ((checks_failed)); then
    echo "Build prerequisites are incomplete; no files were installed." >&2
    exit 1
fi

LLVM_MINGW_ROOT=/opt/llvm-mingw WINEBUILD=$(command -v winebuild) \
    "$repo_root/wine-bridge/build-openport-driver.sh"

install -d "$bin_dir" "$data_dir/winedll/x86_64-windows" \
    "$data_dir/winedll/x86_64-unix" "$applications_dir"
install -m 0755 "$repo_root/linux/launch-ecuflash" "$bin_dir/launch-ecuflash"
install -m 0755 "$repo_root/linux/launch-romraider" "$bin_dir/launch-romraider"
install -m 0644 "$repo_root/build-wine-bridge/winedll/x86_64-windows/openport.sys" \
    "$data_dir/winedll/x86_64-windows/openport.sys"
install -m 0755 "$repo_root/build-wine-bridge/winedll/x86_64-unix/openport.so" \
    "$data_dir/winedll/x86_64-unix/openport.so"

for desktop in ecuflash romraider-editor romraider-logger subaru-ecu-tools-setup; do
    sed -e "s|@BINDIR@|$bin_dir|g" \
        -e "s|@SETUP@|$repo_root/linux/setup-cachyos-gui.sh|g" \
        "$repo_root/linux/$desktop.desktop" \
        > "$applications_dir/$desktop.desktop"
done
command -v update-desktop-database >/dev/null && \
    update-desktop-database "$applications_dir" >/dev/null 2>&1 || true

if $install_udev; then
    if ! getent group uucp >/dev/null; then
        echo "The required uucp device-access group does not exist." >&2
        exit 1
    fi
    sudo install -m 0644 "$repo_root/linux/99-openport2.rules" \
        /etc/udev/rules.d/99-openport2.rules
    sudo usermod -aG uucp "$USER"
    sudo udevadm control --reload-rules
    sudo udevadm trigger --subsystem-match=usb
    echo "Added $USER to uucp. Log out and back in before using the Logger."
fi

if $install_ecuflash; then
    ecuflash_url=https://www.tactrix.com/downloads/ecuflash_1444870_win.exe
    ecuflash_sha256=e9242d8882530fc320164f13e4107ceff9c862f5bd2e66debdbebe4895fffa0b
    ecuflash_installer="$cache_root/ecuflash_1444870_win.exe"
    mkdir -p "$cache_root"

    if [[ ! -f "$ecuflash_installer" ]] || \
       ! printf '%s  %s\n' "$ecuflash_sha256" "$ecuflash_installer" | sha256sum -c - >/dev/null 2>&1; then
        echo "Downloading the complete, unmodified EcuFlash 1.44.4870 installer from Tactrix..."
        curl --fail --location --output "$ecuflash_installer" "$ecuflash_url"
    fi
    printf '%s  %s\n' "$ecuflash_sha256" "$ecuflash_installer" | sha256sum -c -

    ecuflash_wine="${ECUFLASH_WINE:-wine}"
    echo "Opening Tactrix's installer. Review and accept its license in the installer."
    WINEPREFIX="$ecuflash_prefix" "$ecuflash_wine" "$ecuflash_installer"

    ecuflash_dir="$ecuflash_prefix/drive_c/Program Files (x86)/OpenECU/EcuFlash"
    if [[ ! -f "$ecuflash_dir/ecuflash.exe" ]]; then
        echo "EcuFlash installation was not completed; setup cannot report success." >&2
        exit 1
    fi

    echo "Testing EcuFlash startup for 12 seconds. Leave its window open..."
    smoke_log="$cache_root/ecuflash-startup.log"
    set +e
    (
        cd "$ecuflash_dir" || exit 1
        timeout 12s env WINEPREFIX="$ecuflash_prefix" \
            WINEDLLPATH="$data_dir/winedll" WINEDEBUG=-all \
            "$ecuflash_wine" ecuflash.exe
    ) >"$smoke_log" 2>&1
    smoke_status=$?
    set -e
    ecuflash_wineserver="$(dirname -- "$(command -v "$ecuflash_wine" 2>/dev/null || printf '%s' "$ecuflash_wine")")/wineserver"
    [[ -x "$ecuflash_wineserver" ]] && \
        WINEPREFIX="$ecuflash_prefix" "$ecuflash_wineserver" -k >/dev/null 2>&1 || true
    if [[ $smoke_status -ne 124 ]]; then
        echo "EcuFlash failed its startup test (status $smoke_status)." >&2
        echo "Diagnostic log: $smoke_log" >&2
        exit 1
    fi
    echo "OK: EcuFlash remained running for the complete startup test."
fi

echo
echo "Installed user tools successfully."
echo "  Launchers: $bin_dir"
echo "  Wine bridge: $data_dir/winedll"
echo "  Desktop entries: $applications_dir"
if ! $install_udev; then
    echo "OpenPort permissions were not changed. Re-run with --install-udev if needed."
fi
if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
    echo "Add $bin_dir to PATH before launching from a terminal."
fi
echo "Set ECUFLASH_WINEPREFIX/ECUFLASH_WINE and ROMRAIDER_HOME when defaults differ."
echo "Start with cable discovery and a supervised read-only ECU test."
