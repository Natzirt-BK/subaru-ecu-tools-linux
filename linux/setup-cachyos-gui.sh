#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ -x "$script_dir/install-cachyos.sh" ]]; then
    installer="$script_dir/install-cachyos.sh"
else
    installer="$script_dir/subaru-ecu-tools-install"
fi
if [[ ! -x "$installer" ]]; then
    echo "Cannot find the Subaru & Evo ECU Tools command-line installer." >&2
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

add_definition_options() {
    local make year model source units custom_file

    make=$(kdialog --title "Vehicle definitions" --menu \
        "Choose the vehicle family. Exact Editor matching is performed by ROM ID." \
        Subaru "Subaru" \
        Mitsubishi "Mitsubishi Lancer Evolution") || return 0
    year=$(kdialog --title "Vehicle year" --inputbox \
        "Enter the four-digit model year (recorded for guidance and support):" "2008") || return 0
    if [[ "$make" == Subaru ]]; then
        model=$(kdialog --title "Subaru model" --menu "Choose the closest model family." \
            Impreza "Impreza / WRX / STI" Forester "Forester" Legacy "Legacy / Liberty" \
            Outback "Outback" Baja "Baja" BRZ "BRZ" Other "Other Subaru") || return 0
        source=$(kdialog --title "Editor definition channel" --menu \
            "Official is recommended. Beta and Alpha are experimental and used at your discretion." \
            official "Official RomRaider 0.8.3.1b (Recommended)" \
            stable "Community Stable" beta "Community Beta (Experimental)" \
            alpha "Community Alpha (Highly experimental)") || return 0
        if [[ "$source" == beta || "$source" == alpha ]]; then
            kdialog --title "Confirm experimental definitions" --warningyesno \
                "$source definitions may contain incomplete or incorrect table addresses and can contribute to engine or ECU damage if trusted blindly. Continue at your discretion?" || return 0
        fi
        args+=(--install-definitions "$source")
    else
        model=$(kdialog --title "Lancer Evolution model" --menu "Choose the closest model family." \
            "Evo V" "Lancer Evolution V" "Evo VI" "Lancer Evolution VI" \
            "Evo VII" "Lancer Evolution VII" "Evo VIII" "Lancer Evolution VIII" \
            "Evo IX" "Lancer Evolution IX" "Evo X" "Lancer Evolution X" \
            Ralliart "Lancer Ralliart" Other "Other Mitsubishi") || return 0
        kdialog --title "Experimental Mitsubishi definitions" --msgbox \
            "There is no vetted all-model Mitsubishi RomRaider Editor pack equivalent to the Subaru pack. Select an XML matched to your exact ROM ID. The official v370 Logger pack will still be installed; a Mitsubishi-specific Logger XML can also be selected."
        custom_file=$(kdialog --title "Select Mitsubishi Editor definition XML" \
            --getopenfilename "$HOME/Downloads" "*.xml|RomRaider XML definitions (*.xml)") || return 0
        [[ -n "$custom_file" ]] || return 0
        args+=(--install-definitions official --custom-editor-definition "$custom_file")
        if kdialog --title "Mitsubishi Logger definition" --yesno \
            "Do you also have a Logger XML matched to this vehicle?"; then
            custom_file=$(kdialog --title "Select Mitsubishi Logger definition XML" \
                --getopenfilename "$HOME/Downloads" "*.xml|RomRaider Logger XML (*.xml)") || true
            [[ -z "${custom_file:-}" ]] || args+=(--custom-logger-definition "$custom_file")
        fi
    fi
    units=$(kdialog --title "Definition units" --menu "Choose display units." \
        metric "Metric" standard "US standard" imperial "Imperial") || units=metric
    args+=(--definition-units "$units" --vehicle-make "$make" --vehicle-year "$year" --vehicle-model "$model")
}

choice=$(kdialog --title "Subaru & Evo ECU Tools" --menu \
    "Choose an action. Setup only prepares this computer; it never reads or writes an ECU." \
    recommended "Install recommended tools" \
    clean "Clean reinstall (fix stale files)" \
    customize "Customize installation" \
    update "Update and verify installed tools" \
    check "Check this computer" \
    uninstall "Uninstall") || exit 0

if [[ "$choice" == check ]]; then
    exec konsole -e "$installer" --check
fi
if [[ "$choice" == update ]]; then
    exec konsole -e "$script_dir/update-cachyos.sh"
fi
if [[ "$choice" == uninstall ]]; then
    if kdialog --title "Remove Subaru & Evo ECU Tools" --warningyesno \
        "Remove launchers, desktop entries, the Wine bridge, EcuFlash/EvoScan Wine prefix, cache, USB rule, and default source checkout?\n\nROMs, definitions, logs, and separately supplied packages will be preserved."; then
        exec konsole -e "$installer" --uninstall --yes
    fi
    exit 0
fi
if [[ "$choice" == recommended ]]; then
    if kdialog --title "Install recommended tools" --yesno \
        "Install EcuFlash, RomRaider DimeMod, official definitions, the OpenPort bridge, USB permissions, and required packages?\n\nExisting verified downloads will be reused. Setup does not communicate with the ECU."; then
        exec konsole -e "$installer" --yes-all
    fi
    exit 0
fi
if [[ "$choice" == clean ]]; then
    if kdialog --title "Clean reinstall" --warningyesno \
        "Remove all installer-managed EcuFlash/EvoScan, Wine runtime, bridge, launchers, cache, and installer-managed RomRaider files, then install fresh copies?\n\nROMs, definitions, logs, and separately installed software will be preserved. Setup does not communicate with the ECU."; then
        exec konsole -e "$installer" --clean-install --yes
    fi
    exit 0
fi

args=()
components=$(kdialog --title "Customize installation" --checklist \
    "Choose only what you need. Required bridge files are always installed." \
    deps "System dependencies (sudo may be required)" on \
    udev "OpenPort 2.0 USB permissions (sudo may be required)" on \
    romraider "RomRaider DimeMod Editor and Logger" on \
    ecuflash "EcuFlash with a startup-tested Wine runtime" on) || exit 0
[[ "$components" == *'"deps"'* ]] && args+=(--install-deps)
[[ "$components" == *'"udev"'* ]] && args+=(--install-udev)
if [[ "$components" == *'"romraider"'* ]]; then
    args+=(--install-romraider)
    if kdialog --title "RomRaider definitions" --yesno \
        "Install and automatically configure Editor and Logger definitions now?"; then
        add_definition_options
    fi
fi
[[ "$components" == *'"ecuflash"'* ]] && args+=(--install-ecuflash)
if kdialog --title "Optional EvoScan" --yesno \
    "Add a purchased EvoScan installer? Linux support is experimental."; then
    evoscan_file=$(kdialog --title "Select purchased EvoScan installer" \
        --getopenfilename "$HOME/Downloads" "*.exe *.msi|Windows installers (*.exe *.msi)") || true
    [[ -n "${evoscan_file:-}" ]] && args+=(--evoscan-installer "$evoscan_file")
fi

if ! kdialog --title "Confirm custom installation" --yesno \
    "Start the selected installation? A terminal will show progress and save a diagnostic log.\n\nSetup does not communicate with the ECU."; then
    exit 0
fi

exec konsole -e "$installer" "${args[@]}"
