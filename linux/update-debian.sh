#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export ECU_TOOLS_INSTALLER=${ECU_TOOLS_INSTALLER:-$script_dir/install-debian.sh}
export ECU_TOOLS_UPDATER=${ECU_TOOLS_UPDATER:-$script_dir/update-debian.sh}
exec "$script_dir/update-cachyos.sh" "$@"
