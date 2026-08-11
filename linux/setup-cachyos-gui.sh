#!/usr/bin/env bash
set -euo pipefail

# Kept at the historical filename so existing desktop shortcuts continue to work.
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
installer=${ECU_TOOLS_INSTALLER:-$script_dir/install-cachyos.sh}

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

draw_banner() {
    [[ ! -t 1 || "${TERM:-}" == dumb ]] || printf '\033[2J\033[H'
    printf '%b' "$blue$bold"
    cat <<'EOF'
       ╭────────────────────────────────────────────╮
       │       SUBARU & EVO ECU TOOLS // LINUX      │
       ╰────────────────────────────────────────────╯
EOF
    printf '%b        ◆ ◆ ◆ ◆ ◆ ◆   %binstaller & diagnostics%b\n\n' "$purple" "$cyan" "$reset"
    printf '  %bSafe setup only:%b this installer never reads or writes an ECU.\n\n' "$green$bold" "$reset"
}

read_key() {
    local key
    IFS= read -rsn1 key || return 1
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
            *) printf '\n  Press Y or N — Enter is not required.\n' ;;
        esac
    done
}

draw_menu() {
    printf '  %b1%b  %bInstall / repair%b     Recommended; installs and updates everything needed\n' "$cyan$bold" "$reset" "$bold" "$reset"
    printf '  %b2%b  %bClean reinstall%b      Fresh managed files and Wine environment\n' "$cyan$bold" "$reset" "$bold" "$reset"
    printf '  %b3%b  %bSystem check%b         Diagnose installation and connected OpenPort\n' "$cyan$bold" "$reset" "$bold" "$reset"
    printf '  %b4%b  %bUninstall%b            Remove installer-managed components\n' "$cyan$bold" "$reset" "$bold" "$reset"
    printf '  %bQ%b  Exit\n\n' "$dim" "$reset"
    printf '%b  Select an option (no Enter required): %b' "$yellow$bold" "$reset"
}

draw_banner
draw_menu
choice=$(read_key) || exit 0
printf '%s\n\n' "$choice"

case "$choice" in
    1)
        confirm 'Install or repair the recommended tools?' || exit 0
        exec "$installer" --yes-all
        ;;
    2)
        printf '  This replaces installer-managed applications, bridge files, runtime, and cache.\n'
        printf '  Your ROMs, definitions, and logs are preserved.\n\n'
        confirm 'Continue with a clean reinstall?' || exit 0
        exec "$installer" --clean-install --yes
        ;;
    3) exec "$installer" --check ;;
    4)
        printf '  Your ROMs, definitions, and logs are preserved.\n\n'
        confirm 'Remove installer-managed ECU tools?' || exit 0
        exec "$installer" --uninstall --yes
        ;;
    q|Q) printf 'Setup closed.\n' ;;
    *)
        printf '%bUnknown selection.%b Run setup again and press 1, 2, 3, 4, or Q.\n' "$red" "$reset" >&2
        exit 2
        ;;
esac
