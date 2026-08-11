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
run_choice clean '--clean-install --yes'
run_choice update 'update-cachyos.sh'
run_choice check '--check'
run_choice uninstall '--uninstall --yes'

installer=$repo_root/linux/install-cachyos.sh
grep -F 'tail -c 24000' "$installer" >/dev/null
grep -F 'tail -c 3500' "$installer" >/dev/null
grep -F 'The complete ready-to-share report remains at:' "$installer" >/dev/null
grep -F 'wait_for_stable_openport' "$installer" >/dev/null
grep -F '"$cache_root/ecuflash-j2534-probe.log"' "$installer" >/dev/null
grep -F 'LD_LIBRARY_PATH="/usr/lib32' "$repo_root/linux/launch-romraider" >/dev/null
grep -F "grep -q 'J2534 DLL Version: 1\\.02\\.4870'" "$installer" >/dev/null
grep -F 'official Tactrix J2534 library' "$installer" >/dev/null
! grep -F "WINEDLLOVERRIDES='op20pt32,j2534=b'" "$installer" >/dev/null
! grep -F 'WINEDLLOVERRIDES="op20pt32,j2534=b' "$repo_root/linux/launch-ecuflash" >/dev/null
grep -F '"$data_dir/winedll/i386-windows/op20pt32.dll"' "$installer" >/dev/null

echo 'Graphical setup action tests passed.'
