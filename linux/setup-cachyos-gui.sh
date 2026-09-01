#!/usr/bin/env bash
set -euo pipefail

# Kept at the historical filename so existing desktop shortcuts continue to work.
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
installer=${ECU_TOOLS_INSTALLER:-$script_dir/install-cachyos.sh}
updater=${ECU_TOOLS_UPDATER:-$script_dir/update-cachyos.sh}
music_player=${ECU_TOOLS_MUSIC_PLAYER:-$script_dir/play-installer-chiptune}
installed_setup=${XDG_DATA_HOME:-$HOME/.local/share}/applications/subaru-ecu-tools-setup.desktop
export ECU_TOOLS_FORCE_COLOR=${ECU_TOOLS_FORCE_COLOR:-1}
export ECU_TOOLS_MENU_LAUNCHER=${ECU_TOOLS_MENU_LAUNCHER:-$script_dir/setup-cachyos-gui.sh}

if [[ ! -x "$installer" ]]; then
    printf 'Cannot find the Ecu Tools by NatZirt installer: %s\n' "$installer" >&2
    exit 1
fi

if [[ -t 1 && "${TERM:-}" != dumb && \
      ( "$ECU_TOOLS_FORCE_COLOR" == 1 || -z "${NO_COLOR:-}" ) ]]; then
    reset=$'\033[0m'; bold=$'\033[1m'; dim=$'\033[2m'
    blue=$'\033[38;5;39m'; cyan=$'\033[38;5;51m'; green=$'\033[38;5;82m'
    yellow=$'\033[38;5;220m'; red=$'\033[38;5;196m'; purple=$'\033[38;5;135m'
else
    reset=; bold=; dim=; blue=; cyan=; green=; yellow=; red=; purple=
fi

cleanup_terminal() { printf '%b' "$reset"; }
trap cleanup_terminal EXIT HUP INT TERM

# The documented curl command feeds the bootstrap script through standard input.
# Always take interactive keys from the controlling terminal instead of that pipe.
input_device=${SUBARU_SETUP_INPUT_DEVICE:-/dev/tty}
if ! exec 3<"$input_device"; then
    printf 'Setup needs an interactive terminal for menu input.\n' >&2
    exit 1
fi

draw_banner() {
    [[ ! -t 1 || "${TERM:-}" == dumb ]] || printf '\033[2J\033[H'
    printf '%b' "$blue$bold"
    cat <<'EOF'
       ╭──────────────────────────────────────────────╮
       │         Ecu Tools by NatZirt // Linux        │
       ├──────────────────────────────────────────────┤
       │     SUBARU • MITSUBISHI LANCER EVOLUTION     │
       │      ECU EDITING • LOGGING • DIAGNOSTICS     │
       ╰──────────────────────────────────────────────╯
EOF
    printf '%b           ◆ ◆ ◆ ◆ ◆ ◆ ◆ ◆ ◆ ◆ ◆ ◆%b\n\n' "$purple" "$reset"
    printf '  %b✓ Safe setup only%b — this installer never reads or writes an ECU.\n\n' \
        "$green$bold" "$reset"
}

read_key() {
    local key
    IFS= read -rsn1 -u 3 key || return 1
    printf '%s' "$key"
}

setup_music_process_active() {
    local music_pid=${SUBARU_SETUP_MUSIC_PID:-}
    [[ "$music_pid" =~ ^[0-9]+$ ]] && kill -0 "$music_pid" 2>/dev/null
}

pause_installer_music_keys() {
    local attempt state=
    setup_music_process_active || return 0
    kill -USR1 "$SUBARU_SETUP_MUSIC_PID" 2>/dev/null || return 0
    for ((attempt=0; attempt<30; attempt++)); do
        [[ -r "${SUBARU_SETUP_MUSIC_STATE_FILE:-}" ]] && \
            IFS= read -r state <"$SUBARU_SETUP_MUSIC_STATE_FILE" || state=
        [[ "$state" == paused ]] && return 0
        setup_music_process_active || return 0
        sleep 0.01
    done
}

resume_installer_music_keys() {
    setup_music_process_active || return 0
    kill -USR2 "$SUBARU_SETUP_MUSIC_PID" 2>/dev/null || true
}

mute_installer_music() {
    setup_music_process_active || return 0
    kill "$SUBARU_SETUP_MUSIC_PID" 2>/dev/null || true
    wait "$SUBARU_SETUP_MUSIC_PID" 2>/dev/null || true
    unset SUBARU_SETUP_MUSIC_PID
    export SUBARU_SETUP_MUSIC_MUTED=1
    printf '\n  %b♪ Installer music muted.%b\n\n' "$purple$bold" "$reset"
}

confirm() {
    local prompt=$1 key
    while true; do
        printf '%b%s%b %b[Y/N]%b ' "$bold" "$prompt" "$reset" "$yellow$bold" "$reset"
        key=$(read_key) || return 1
        case "$key" in
            y|Y) printf '%bY%b\n' "$green$bold" "$reset"; return 0 ;;
            n|N) printf '%bN%b\n' "$red$bold" "$reset"; return 1 ;;
            m|M) mute_installer_music ;;
            *) printf '\n  Press Y or N, or M to mute.\n' ;;
        esac
    done
}

start_installer_music() {
    local runtime_root attempt state=
    # Keep one music controller for the lifetime of this setup terminal. The
    # installer returns here by exec, so the exported PID also prevents a
    # user-muted session from starting again when the menu is redrawn.
    [[ "${SUBARU_SETUP_MUSIC_MUTED:-0}" != 1 ]] || return 0
    [[ -z "${SUBARU_SETUP_MUSIC_PID:-}" ]] || return 0
    [[ -x "$music_player" ]] && command -v pw-play >/dev/null 2>&1 || return 0
    runtime_root=${XDG_RUNTIME_DIR:-/tmp}
    export SUBARU_SETUP_MUSIC_STATE_FILE="$runtime_root/subaru-ecu-tools-music-${BASHPID}-${RANDOM}.state"
    ECU_TOOLS_MUSIC_CAPTURE_KEYS=0 \
        ECU_TOOLS_MUSIC_STATE_FILE="$SUBARU_SETUP_MUSIC_STATE_FILE" \
        "$music_player" >/dev/null 2>&1 &
    export SUBARU_SETUP_MUSIC_PID=$!
    # Do not signal the controller until it has installed its signal traps.
    # This also keeps very small test doubles from being killed at startup.
    for ((attempt=0; attempt<30; attempt++)); do
        [[ -r "$SUBARU_SETUP_MUSIC_STATE_FILE" ]] && \
            IFS= read -r state <"$SUBARU_SETUP_MUSIC_STATE_FILE" || state=
        [[ "$state" == active ]] && break
        setup_music_process_active || break
        sleep 0.01
    done
    printf '  %b♪ Installer music is running quietly in the background.%b\n' \
        "$purple$bold" "$reset"
    printf '  Press %bM%b in this setup terminal at any time to mute it.\n\n' \
        "$yellow$bold" "$reset"
}

menu_line() {
    local text=$1 style=${2:-} line
    while IFS= read -r line || [[ -n "$line" ]]; do
        printf '  %b│%b %b%-53s%b%b│%b\n' \
            "$blue" "$reset" "$style" "$line" "$reset" "$blue" "$reset"
    done < <(printf '%s\n' "$text" | fold -s -w 53)
}

draw_menu() {
    printf '  %b╭─ SETUP MENU ─────────────────────────────────────────╮%b\n' "$blue$bold" "$reset"
    menu_line '[1] INSTALL / REPAIR                  RECOMMENDED' "$cyan$bold"
    menu_line '    EcuFlash 1.44 for Subaru/Mitsubishi ECUs.'
    menu_line '    RomRaider DimeMod, definitions + OpenPort.'
    menu_line '    Checks dependencies, files + live cable access.'
    menu_line '[2] CLEAN REINSTALL' "$cyan$bold"
    menu_line '    Rebuild the managed EcuFlash/RomRaider stack.'
    menu_line '[3] SYSTEM CHECK' "$cyan$bold"
    menu_line '    Check EcuFlash, J2534, launchers + OpenPort USB.'
    menu_line '[4] UNINSTALL                    [Q] EXIT' "$cyan$bold"
    menu_line '[5] RomRaider2 1.1.0 RC3' "$purple$bold"
    menu_line '    Modern RomRaider update.'
    menu_line '    For Subaru and Mitsubishi Lancer Evolution.'
    menu_line '    Includes new editor, logger + analysis features.'
    printf '  %b╰──────────────────────────────────────────────────────╯%b\n\n' "$blue$bold" "$reset"
    printf '%b  Select an option: %b' "$yellow$bold" "$reset"
}

draw_banner
start_installer_music
pause_installer_music_keys
if [[ -f "$installed_setup" && "${ECU_TOOLS_SKIP_UPDATE_PROMPT:-0}" != 1 ]]; then
    printf '  %bRecommended:%b check for installer and compatibility updates first.\n' \
        "$green$bold" "$reset"
    printf '  Y = update now (recommended); N = continue without updating (not recommended).\n\n'
    if confirm 'Update Ecu Tools by NatZirt before continuing?'; then
        [[ -x "$updater" ]] || {
            printf 'Cannot find the updater: %s\n' "$updater" >&2
            exit 1
        }
        resume_installer_music_keys
        exec "$updater" --continue-setup
    fi
    printf '  %bContinuing without updating is not recommended.%b\n\n' \
        "$yellow$bold" "$reset"
fi
while true; do
    draw_menu
    choice=$(read_key) || exit 0
    printf '%s\n\n' "$choice"
    case "$choice" in
        1|2|3|4|5|6|q|Q) break ;;
        m|M) mute_installer_music ;;
        *)
            printf '%b  Unknown selection.%b Press 1, 2, 3, 4, 5, or Q.\n\n' \
                "$red$bold" "$reset" >&2
            ;;
    esac
done

case "$choice" in
    1)
        confirm 'Install or repair the recommended tools?' || exit 0
        resume_installer_music_keys
        exec "$installer" --yes-all
        ;;
    2)
        printf '  This replaces installer-managed applications, bridge files, runtime, and cache.\n'
        printf '  Your ROMs, definitions, and logs are preserved.\n\n'
        confirm 'Continue with a clean reinstall?' || exit 0
        resume_installer_music_keys
        exec "$installer" --clean-install --yes
        ;;
    3) resume_installer_music_keys; exec "$installer" --check ;;
    4)
        printf '  Your ROMs, definitions, and logs are preserved.\n\n'
        confirm 'Remove installer-managed ECU tools?' || exit 0
        resume_installer_music_keys
        exec "$installer" --uninstall --yes
        ;;
    5)
        printf '  Release candidate; validated tools remain installed through vehicle qualification.\n\n'
        confirm 'Install or update RomRaider2 1.1.0 RC3?' || exit 0
        resume_installer_music_keys
        exec "$installer" --install-romraider2
        ;;
    q|Q) resume_installer_music_keys; printf 'Setup closed.\n' ;;
esac
