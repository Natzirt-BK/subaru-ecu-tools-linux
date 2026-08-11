#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT HUP INT TERM
mkdir -p "$test_root/bin"

cat >"$test_root/bin/kdialog" <<'EOF'
#!/bin/sh
case " $* " in
    *' --menu '*) printf '%s\n' "$TEST_CHOICE" ;;
    *' --yesno '*|*' --warningyesno '*) exit 0 ;;
    *) exit 1 ;;
esac
EOF
cat >"$test_root/bin/konsole" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >"$TEST_TRACE"
EOF
chmod +x "$test_root/bin/kdialog" "$test_root/bin/konsole"

run_choice() {
    choice=$1
    expected=$2
    trace=$test_root/$choice.trace
    PATH="$test_root/bin:$PATH" TEST_CHOICE="$choice" TEST_TRACE="$trace" \
        DISPLAY=:test "$repo_root/linux/setup-cachyos-gui.sh"
    grep -F -- "$expected" "$trace" >/dev/null
}

run_choice recommended '--yes-all'
run_choice update 'update-cachyos.sh'
run_choice check '--check'
run_choice uninstall '--uninstall --yes'

echo 'Graphical setup action tests passed.'
