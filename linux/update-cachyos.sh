#!/usr/bin/env bash
set -euo pipefail

repo_url=https://github.com/Natzirt-BK/subaru-ecu-tools-linux.git
source_dir=${ECU_TOOLS_SOURCE_DIR:-$HOME/.local/src/subaru-ecu-tools-linux}

if [[ ! -d "$source_dir/.git" ]]; then
    echo "The managed source checkout was not found: $source_dir" >&2
    echo "Run the normal bootstrap installer once, then use Update." >&2
    exit 1
fi

echo "==> Downloading Subaru & Evo ECU Tools updates"
before_revision=$(git -C "$source_dir" rev-parse --short HEAD)
git -C "$source_dir" fetch --prune origin master
if git -C "$source_dir" merge-base --is-ancestor HEAD origin/master &&
   git -C "$source_dir" merge --ff-only origin/master; then
    :
else
    backup_dir="${source_dir}.backup-$(date +%Y%m%d-%H%M%S)"
    echo "Preserving the divergent checkout at: $backup_dir"
    mv -- "$source_dir" "$backup_dir"
    git clone --depth 1 "$repo_url" "$source_dir"
fi

after_revision=$(git -C "$source_dir" rev-parse --short HEAD)
if [[ "$before_revision" == "$after_revision" ]]; then
    echo "==> Source already current at $after_revision"
else
    echo "==> Source updated: $before_revision -> $after_revision"
fi
echo "==> Auditing installed files and rebuilding generated bridge components"
echo "    A 0-file managed audit is normal when only generated bridge code changed."

exec "$source_dir/linux/install-cachyos.sh" --update-files
