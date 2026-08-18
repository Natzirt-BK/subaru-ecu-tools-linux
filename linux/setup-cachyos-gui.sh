#!/usr/bin/env bash
set -euo pipefail

# Kept at the historical filename so existing desktop shortcuts continue to work.
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
installer=${ECU_TOOLS_INSTALLER:-$script_dir/install-cachyos.sh}
updater=${ECU_TOOLS_UPDATER:-$script_dir/update-cachyos.sh}
music_player=${ECU_TOOLS_MUSIC_PLAYER:-$script_dir/play-installer-chiptune}
installed_setup=${XDG_DATA_HOME:-$HOME/.local/share}/applications/subaru-ecu-tools-setup.desktop

if [[ ! -x "$installer" ]]; then
    printf 'Cannot find the Subaru & Evo ECU Tools installer: %s\n' "$installer" >&2
    exit 1
fi

if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-}" != dumb ]]; then
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
       │        SUBARU & EVO ECU TOOLS // LINUX       │
       ├──────────────────────────────────────────────┤
       │        INSTALL • REPAIR • DIAGNOSTICS        │
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

confirm() {
    local prompt=$1 key
    while true; do
        printf '%b%s%b %b[Y/N]%b ' "$bold" "$prompt" "$reset" "$yellow$bold" "$reset"
        key=$(read_key) || return 1
        case "$key" in
            y|Y) printf '%bY%b\n' "$green$bold" "$reset"; return 0 ;;
            n|N) printf '%bN%b\n' "$red$bold" "$reset"; return 1 ;;
            *) printf '\n  Press Y or N.\n' ;;
        esac
    done
}

start_installer_music() {
    local runtime_root
    [[ -x "$music_player" ]] && command -v pw-play >/dev/null 2>&1 || return 0
    runtime_root=${XDG_RUNTIME_DIR:-/tmp}
    export SUBARU_SETUP_MUSIC_STATE_FILE="$runtime_root/subaru-ecu-tools-music-${BASHPID}-${RANDOM}.state"
    ECU_TOOLS_MUSIC_STATE_FILE="$SUBARU_SETUP_MUSIC_STATE_FILE" \
        "$music_player" >/dev/null 2>&1 &
    export SUBARU_SETUP_MUSIC_PID=$!
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
    menu_line '    Install or update all managed components.'
    menu_line '[2] CLEAN REINSTALL' "$cyan$bold"
    menu_line '    Rebuild managed files and the Wine environment.'
    menu_line '[3] SYSTEM CHECK' "$cyan$bold"
    menu_line '    Diagnose installation and a connected OpenPort.'
    menu_line '[4] UNINSTALL                    [Q] EXIT' "$cyan$bold"
    printf '  %b╰──────────────────────────────────────────────────────╯%b\n\n' "$blue$bold" "$reset"
    printf '%b  Select an option: %b' "$yellow$bold" "$reset"
}

draw_banner
if [[ -f "$installed_setup" && "${ECU_TOOLS_SKIP_UPDATE_PROMPT:-0}" != 1 ]]; then
    printf '  %bRecommended:%b check for installer and compatibility updates first.\n' \
        "$green$bold" "$reset"
    printf '  Y = update now (recommended); N = continue without updating (not recommended).\n\n'
    if confirm 'Update Subaru & Evo ECU Tools before continuing?'; then
        [[ -x "$updater" ]] || {
            printf 'Cannot find the updater: %s\n' "$updater" >&2
            exit 1
        }
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
        1|2|3|4|q|Q) break ;;
        *)
            printf '%b  Unknown selection.%b Press 1, 2, 3, 4, or Q.\n\n' \
                "$red$bold" "$reset" >&2
            ;;
    esac
done

case "$choice" in
    1)
        confirm 'Install or repair the recommended tools?' || exit 0
        start_installer_music
        exec "$installer" --yes-all
        ;;
    2)
        printf '  This replaces installer-managed applications, bridge files, runtime, and cache.\n'
        printf '  Your ROMs, definitions, and logs are preserved.\n\n'
        confirm 'Continue with a clean reinstall?' || exit 0
        start_installer_music
        exec "$installer" --clean-install --yes
        ;;
    3) exec "$installer" --check ;;
    4)
        printf '  Your ROMs, definitions, and logs are preserved.\n\n'
        confirm 'Remove installer-managed ECU tools?' || exit 0
        exec "$installer" --uninstall --yes
        ;;
    q|Q) printf 'Setup closed.\n' ;;
esac
