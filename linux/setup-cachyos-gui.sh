#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ -x "$script_dir/install-cachyos.sh" ]]; then
    installer="$script_dir/install-cachyos.sh"
else
    installer="$script_dir/subaru-ecu-tools-install"
fi
if [[ ! -x "$installer" ]]; then
    echo "Cannot find the Subaru ECU Tools command-line installer." >&2
    exit 1
fi

if ! command -v kdialog >/dev/null || ! command -v konsole >/dev/null; then
    echo "The graphical setup requires KDialog and Konsole." >&2
    echo "Install them with: sudo pacman -S --needed kdialog konsole" >&2
    exit 1
fi
if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "No graphical desktop session was detected." >&2
    exit 1
fi

choice=$(kdialog --title "Subaru ECU Tools" --menu \
    "Choose what you want to do. No option writes to an ECU." \
    check "Check this CachyOS system only" \
    install "Install the Linux tuning tools") || exit 0

if [[ "$choice" == check ]]; then
    exec konsole --hold -e "$installer" --check
fi

args=()
if kdialog --title "Subaru ECU Tools" --yesno \
    "Install any missing CachyOS packages? This may ask for your sudo password."; then
    args+=(--install-deps)
fi
if kdialog --title "Subaru ECU Tools" --yesno \
    "Install the Tactrix OpenPort 2.0 USB permission rule? This may ask for your sudo password."; then
    args+=(--install-udev)
fi
if kdialog --title "Subaru ECU Tools" --yesno \
    "Download EcuFlash 1.44.4870 from Tactrix and open its installer in Wine?"; then
    args+=(--install-ecuflash)
fi

summary="The setup will build and install the Wine bridge and launchers."
((${#args[@]})) && summary+=$'\n\nSelected options: '"${args[*]}"
if ! kdialog --title "Confirm Subaru ECU Tools setup" --yesno \
    "$summary

This only prepares the computer. It will not read or write an ECU."; then
    exit 0
fi

exec konsole --hold -e "$installer" "${args[@]}"
