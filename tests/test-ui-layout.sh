#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT HUP INT TERM

TERM=xterm timeout 10 script -q -e -c \
    "ECU_TOOLS_UI_SELF_TEST=1 '$repo_root/linux/install-cachyos.sh'" \
    "$test_root/console.typescript" >/dev/null

printf 'q' | TERM=xterm SUBARU_SETUP_INPUT_DEVICE=/dev/stdin \
    ECU_TOOLS_SKIP_UPDATE_PROMPT=1 ECU_TOOLS_MUSIC_PLAYER="$test_root/no-music" \
    "$repo_root/linux/setup-cachyos-gui.sh" >"$test_root/menu.output" 2>&1

perl -CSD -Mutf8 -e '
    use strict; use warnings;
    my $failed = 0; my $seen = 0;
    while (<>) {
        s/\e\[[0-9;]*m//g; s/\r//g; chomp;
        next unless /║/;
        $seen++;
        my @chars = split //;
        my @borders = grep { $chars[$_] eq "║" } 0 .. $#chars;
        if (@borders != 2 || $borders[0] != 0 || $borders[1] != 69) {
            warn "invalid setup-console border width: $_\n";
            $failed = 1;
        }
    }
    if ($seen < 8) {
        warn "setup console emitted only $seen bordered rows\n";
        $failed = 1;
    }
    exit $failed;
' "$test_root/console.typescript"

perl -CSD -Mutf8 -e '
    use strict; use warnings;
    my $failed = 0;
    while (<>) {
        s/\e\[[0-9;]*m//g; s/\r//g; chomp;
        next unless /^  │/;
        my @chars = split //;
        my @borders = grep { $chars[$_] eq "│" } 0 .. $#chars;
        if (@borders != 2 || $borders[0] != 2 || $borders[1] != 57) {
            warn "invalid setup-menu border width: $_\n";
            $failed = 1;
        }
    }
    exit $failed;
' "$test_root/menu.output"

echo 'Installer UI border and wrapping tests passed.'
