#!/usr/bin/env bash
set -euo pipefail

repo_url=https://github.com/Natzirt-BK/subaru-ecu-tools-linux.git
source_dir="${ECU_TOOLS_SOURCE_DIR:-$HOME/.local/src/subaru-ecu-tools-linux}"

if [[ ! -r /etc/os-release ]]; then
    echo "Cannot identify this Linux distribution." >&2
    exit 1
fi
# shellcheck disable=SC1091
source /etc/os-release
os_family="${ID:-} ${ID_LIKE:-}"
if [[ "$os_family" != *cachyos* && "$os_family" != *arch* ]]; then
    echo "This bootstrap is intended for CachyOS/Arch Linux." >&2
    echo "Detected: ${PRETTY_NAME:-unknown}" >&2
    exit 1
fi

if ! command -v git >/dev/null; then
    echo "Git is required. Install it first with:" >&2
    echo "  sudo pacman -S --needed git" >&2
    exit 1
fi

mkdir -p "$(dirname -- "$source_dir")"
if [[ -d "$source_dir/.git" ]]; then
    echo "Updating existing checkout in $source_dir"
    git -C "$source_dir" fetch --prune origin master
    if git -C "$source_dir" merge-base --is-ancestor HEAD origin/master && \
       git -C "$source_dir" merge --ff-only origin/master; then
        :
    else
        backup_dir="${source_dir}.backup-$(date +%Y%m%d-%H%M%S)"
        if [[ -e "$backup_dir" ]]; then
            backup_dir="$backup_dir-$$"
        fi
        echo "The existing checkout has local or older rewritten history."
        echo "Preserving it at: $backup_dir"
        mv -- "$source_dir" "$backup_dir"
        git clone --depth 1 "$repo_url" "$source_dir"
    fi
elif [[ -e "$source_dir" ]]; then
    echo "Cannot install: $source_dir exists but is not a Git checkout." >&2
    exit 1
else
    git clone --depth 1 "$repo_url" "$source_dir"
fi

if (($# == 0)); then
    set -- --check
fi
if [[ "${1:-}" == --gui ]]; then
    shift
    exec "$source_dir/linux/setup-cachyos-gui.sh" "$@"
fi
exec "$source_dir/linux/install-cachyos.sh" "$@"
