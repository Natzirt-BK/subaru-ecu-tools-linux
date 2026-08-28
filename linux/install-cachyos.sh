#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
mode=install
install_deps=false
install_udev=false
install_ecuflash=false
install_romraider=false
install_evo_romraider=false
install_bergerraider=false
install_evoscan=false
install_definitions=false
definition_source=official
definition_units=metric
definition_language=en
vehicle_make=
vehicle_year=
vehicle_model=
custom_editor_definition=
custom_logger_definition=
evoscan_installer=${EVOSCAN_INSTALLER:-}
assume_yes=false
clean_install=false
setup_interactive=false
if [[ -t 0 || -t 1 || -t 2 ]]; then
    setup_interactive=true
fi
if [[ -n "$evoscan_installer" ]]; then
    install_evoscan=true
    install_ecuflash=true
fi

os_release_file=${ECU_TOOLS_OS_RELEASE:-/etc/os-release}
if [[ ! -r "$os_release_file" ]]; then
    echo "Cannot identify this Linux distribution: $os_release_file" >&2
    exit 1
fi
# shellcheck disable=SC1090
source "$os_release_file"
os_family="${ID:-} ${ID_LIKE:-}"
case " ${os_family,,} " in
    *debian*)
        distro_family=debian
        distro_label=Debian
        package_manager=apt
        github_cli_package=gh
        openport_group=${OPENPORT_GROUP:-dialout}
        ;;
    *cachyos*|*arch*)
        distro_family=arch
        distro_label=CachyOS/Arch
        package_manager=pacman
        github_cli_package=github-cli
        openport_group=${OPENPORT_GROUP:-uucp}
        ;;
    *)
        distro_family=unsupported
        distro_label=${PRETTY_NAME:-unknown}
        package_manager=unknown
        github_cli_package=gh
        openport_group=${OPENPORT_GROUP:-dialout}
        ;;
esac

if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-}" != dumb ]]; then
    color_reset=$'\033[0m'
    color_bold=$'\033[1m'
    color_red=$'\033[31m'
    color_green=$'\033[32m'
    color_yellow=$'\033[33m'
    color_blue=$'\033[34m'
    color_cyan=$'\033[36m'
    color_purple=$'\033[35m'
    use_color=true
else
    color_reset= color_bold= color_red= color_green=
    color_yellow= color_blue= color_cyan= color_purple=
    use_color=false
fi

ui_rule=$(printf '%68s' '')
ui_rule=${ui_rule// /═}
ui_stage=0
ui_console_open=false
ui_box_line() {
    local style=$1 text=$2 line
    while IFS= read -r line || [[ -n "$line" ]]; do
        printf '%b║%b  %b%-66s%b%b║%b\n' \
            "$color_purple$color_bold" "$color_reset" "$style" "$line" \
            "$color_reset" "$color_purple$color_bold" "$color_reset"
    done < <(printf '%s\n' "$text" | fold -s -w 66)
}
installer_banner() {
    local mode_label=${mode^^} audio_label='AUDIO :: OFF'
    [[ "${SUBARU_SETUP_MUSIC_PID:-}" =~ ^[0-9]+$ ]] && \
        audio_label='AUDIO :: [M] MUTE'
    printf '\n%b╔%s╗%b\n' "$color_purple$color_bold" "$ui_rule" "$color_reset"
    ui_box_line "$color_cyan$color_bold" 'SUBARU // EVO :: ECU TOOLS'
    ui_box_line "$color_green$color_bold" 'SECURE SETUP CONSOLE              [ ECU I/O :: LOCKED ]'
    printf '%b╠%s╣%b\n' "$color_purple$color_bold" "$ui_rule" "$color_reset"
    ui_box_line "$color_blue$color_bold" \
        "MODE :: $mode_label     $audio_label     DIAGNOSTICS :: ACTIVE"
    ui_console_open=true
}
console_footer() {
    [[ "$ui_console_open" == true ]] || return 0
    printf '%b╚%s╝%b\n' "$color_purple$color_bold" "$ui_rule" "$color_reset"
    ui_console_open=false
}
section() {
    ((ui_stage+=1))
    printf '%b╠%s╣%b\n' "$color_purple$color_bold" "$ui_rule" "$color_reset"
    ui_box_line "$color_cyan$color_bold" \
        "NODE $(printf '%02d' "$ui_stage") // ${*^^}"
    printf '%b╟%s╢%b\n' "$color_purple" "${ui_rule//═/─}" "$color_reset"
}
step() { ui_box_line "$color_blue" "[ RUN  ] $*"; }
ok() { ui_box_line "$color_green$color_bold" "[  OK  ] $*"; }
warn() { ui_box_line "$color_yellow$color_bold" "[ WARN ] $*" >&2; }
fail() { ui_box_line "$color_red$color_bold" "[ FAIL ] $*" >&2; }
summary_row() { ui_box_line "$color_cyan" "[ DATA ] $1 :: $2"; }
completion_banner() {
    printf '%b╠%s╣%b\n' "$color_green$color_bold" "$ui_rule" "$color_reset"
    ui_box_line "$color_green$color_bold" \
        'ACCESS GRANTED // SETUP COMPLETE // ALL REQUESTED TASKS FINISHED'
    printf '%b╠%s╣%b\n' "$color_green$color_bold" "$ui_rule" "$color_reset"
}

if [[ "${ECU_TOOLS_UI_SELF_TEST:-0}" == 1 ]]; then
    installer_banner
    section "Layout validation on $distro_label"
    step "A deliberately long status message verifies that ordinary words wrap cleanly inside the setup console border on every supported distribution."
    warn "A deliberately-long-unbroken-token-ABCDEFGHIJKLMNOPQRSTUVWXYZ-0123456789-abcdefghijklmnopqrstuvwxyz-must-not-cross-the-right-border."
    ok "Short status text remains aligned."
    summary_row PLATFORM "$distro_label / $(uname -m) / $package_manager"
    completion_banner
    console_footer
    exit 0
fi

setup_music_process_active() {
    local music_pid=${SUBARU_SETUP_MUSIC_PID:-}
    [[ "$music_pid" =~ ^[0-9]+$ ]] && kill -0 "$music_pid" 2>/dev/null && \
        [[ -r "/proc/$music_pid/cmdline" ]] && \
        tr '\0' ' ' <"/proc/$music_pid/cmdline" | grep -q 'play-installer-chiptune'
}

pause_setup_music_keys() {
    local state_file=${SUBARU_SETUP_MUSIC_STATE_FILE:-} attempt state=
    setup_music_process_active || return 0
    kill -USR1 "$SUBARU_SETUP_MUSIC_PID" 2>/dev/null || return 0
    for ((attempt=0; attempt<30; attempt++)); do
        [[ -r "$state_file" ]] && IFS= read -r state <"$state_file" || state=
        [[ "$state" == paused ]] && return 0
        setup_music_process_active || return 0
        sleep 0.01
    done
}

resume_setup_music_keys() {
    setup_music_process_active || return 0
    kill -USR2 "$SUBARU_SETUP_MUSIC_PID" 2>/dev/null || true
}

run_with_music_keys_paused() {
    local status
    pause_setup_music_keys
    "$@" && status=0 || status=$?
    resume_setup_music_keys
    return "$status"
}

package_installed() {
    case "$package_manager" in
        pacman) pacman -Q "$1" &>/dev/null ;;
        apt)
            dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null | grep -q '^ii '
            ;;
        *) return 1 ;;
    esac
}

enable_debian_i386() {
    [[ "$distro_family" == debian ]] || return 0
    [[ "$(dpkg --print-architecture)" == amd64 ]] || {
        fail "Debian support currently requires an amd64 installation."
        return 1
    }
    if ! dpkg --print-foreign-architectures | grep -qx i386; then
        step "Enabling Debian i386 multiarch for RomRaider Logger"
        run_with_music_keys_paused sudo dpkg --add-architecture i386
    fi
}

install_host_packages() {
    case "$package_manager" in
        pacman)
            run_with_music_keys_paused sudo pacman -S --needed "$@"
            ;;
        apt)
            enable_debian_i386
            run_with_music_keys_paused sudo apt-get update
            run_with_music_keys_paused sudo apt-get install -y --no-install-recommends "$@"
            ;;
        *)
            fail "Unsupported package manager on $distro_label."
            return 1
            ;;
    esac
}

romraider_libusb_runtime() {
    local candidate
    for candidate in /usr/lib32/libusb-1.0.so.0 \
        /usr/lib/i386-linux-gnu/libusb-1.0.so.0; do
        [[ -e "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
    done
    return 1
}

# Read confirmations immediately, without requiring Enter. Noninteractive callers
# continue to use --yes/--yes-all and never reach this helper.
read_yes_no() {
    local prompt=$1 default=${2:-no} key suffix result
    [[ "$default" == yes ]] && suffix='[Y/n]' || suffix='[y/N]'
    pause_setup_music_keys
    while true; do
        ui_box_line "$color_yellow$color_bold" "[ INPUT ] $prompt $suffix"
        printf '%b║%b  > ' "$color_purple$color_bold" "$color_reset"
        if ! IFS= read -rsn1 key </dev/tty; then
            result=1
            break
        fi
        if [[ -z "$key" ]]; then
            printf '\n'
            [[ "$default" == yes ]] && result=0 || result=1
            break
        fi
        case "$key" in
            y|Y) printf 'Y\n'; result=0; break ;;
            n|N) printf 'N\n'; result=1; break ;;
            *) printf '\nPress Y or N.\n' ;;
        esac
    done
    resume_setup_music_keys
    return "$result"
}

stop_wine_prefix() {
    local wine_runner=$1 prefix=$2 log_target=${3:-/dev/null}
    local runtime_bin wineserver
    runtime_bin=$(dirname -- "$(command -v "$wine_runner" 2>/dev/null || printf '%s' "$wine_runner")")
    wineserver="$runtime_bin/wineserver"
    [[ -x "$wineserver" ]] || return 0
    WINEPREFIX="$prefix" "$wineserver" -k >>"$log_target" 2>&1 || true
    WINEPREFIX="$prefix" "$wineserver" -w >>"$log_target" 2>&1 || true
}

# A newly added supplementary group is not present in the process that ran
# usermod.  Run hardware checks through that group immediately so a first-time
# install tests the same USB access that launchers receive after login.
run_with_openport_access() {
    local group_command= current_user
    current_user=${USER:-$(id -un)}
    if id -nG | tr ' ' '\n' | grep -qx "$openport_group" || \
       ! getent group "$openport_group" | cut -d: -f4 | tr ',' '\n' | grep -qx "$current_user"; then
        "$@"
        return
    fi
    command -v newgrp >/dev/null 2>&1 || {
        fail "The $openport_group device-access group was added, but newgrp is unavailable. Log out and back in, then run Update."
        return 1
    }
    printf -v group_command ' %q' "$@"
    newgrp "$openport_group" -c "exec${group_command}"
}

capture_verbose_openport_probe() {
    local wine_runner=$1 prefix=$2 winedll_path=$3 probe=$4 trace_log=$5
    shift 5
    {
        echo
        echo '=== Failure-only Wine OpenPort driver/PnP trace ==='
    } >>"$trace_log"
    stop_wine_prefix "$wine_runner" "$prefix" "$trace_log"
    set +e
    run_with_openport_access env WINEPREFIX="$prefix" \
        WINEDLLPATH="$winedll_path" \
        WINEDEBUG=-all,+loaddll,+plugplay,+service,+setupapi,+module \
        "$wine_runner" "$probe" "$@" >>"$trace_log" 2>&1
    set -e
    stop_wine_prefix "$wine_runner" "$prefix" "$trace_log"
}

capture_openport_device_probe() {
    local wine_runner=$1 prefix=$2 winedll_path=$3 device_probe=$4 trace_log=$5
    {
        echo
        echo '=== OpenPort Windows interface/service probe ==='
    } >>"$trace_log"
    set +e
    run_with_openport_access env WINEPREFIX="$prefix" \
        WINEDLLPATH="$winedll_path" WINEDEBUG=-all \
        "$wine_runner" "$device_probe" >>"$trace_log" 2>&1
    set -e
}

openport_usb_present() {
    local sysfs_root=${OPENPORT_USB_SYSFS_ROOT:-/sys/bus/usb/devices}
    local vendor_file product_file vendor product

    for vendor_file in "$sysfs_root"/*/idVendor; do
        [[ -f "$vendor_file" ]] || continue
        read -r vendor <"$vendor_file" || continue
        [[ "${vendor,,}" == 0403 ]] || continue
        product_file=${vendor_file%/idVendor}/idProduct
        [[ -f "$product_file" ]] || continue
        read -r product <"$product_file" || continue
        [[ "${product,,}" == cc4d ]] && return 0
    done
    return 1
}

openport_usb_node() {
    local sysfs_root=${OPENPORT_USB_SYSFS_ROOT:-/sys/bus/usb/devices}
    local dev_root=${OPENPORT_USB_DEV_ROOT:-/dev/bus/usb}
    local vendor_file device_dir product_file vendor product busnum devnum node

    for vendor_file in "$sysfs_root"/*/idVendor; do
        [[ -f "$vendor_file" ]] || continue
        read -r vendor <"$vendor_file" || continue
        [[ "${vendor,,}" == 0403 ]] || continue
        device_dir=${vendor_file%/idVendor}
        product_file=$device_dir/idProduct
        [[ -f "$product_file" ]] || continue
        read -r product <"$product_file" || continue
        [[ "${product,,}" == cc4d ]] || continue
        read -r busnum <"$device_dir/busnum" || continue
        read -r devnum <"$device_dir/devnum" || continue
        [[ "$busnum" =~ ^[0-9]+$ && "$devnum" =~ ^[0-9]+$ ]] || continue
        printf -v node '%s/%03d/%03d' "$dev_root" "$busnum" "$devnum"
        [[ -e "$node" ]] || continue
        printf '%s\n' "$node"
        return 0
    done
    return 1
}

openport_usb_accessible() {
    local node
    node=$(openport_usb_node) || return 1
    [[ -r "$node" && -w "$node" ]]
}

verify_openport_usb_access() {
    local node
    node=$(openport_usb_node) || {
        fail "The OpenPort is detected, but its USB device node was not created."
        return 1
    }
    if run_with_openport_access test -r "$node" && \
       run_with_openport_access test -w "$node"; then
        ok "udev grants effective read/write access to the connected OpenPort ($node)."
        return 0
    fi
    stat -c 'OpenPort node: %A %U:%G (%a) %n' "$node" 2>/dev/null || true
    fail "The OpenPort USB node is not readable and writable after applying the udev rule."
    return 1
}

wait_for_stable_openport() {
    local sysfs_root=${OPENPORT_USB_SYSFS_ROOT:-/sys/bus/usb/devices}
    local previous= current= vendor_file product_file vendor product devnum_file devnum
    local stable=0 attempt

    for attempt in {1..20}; do
        current=
        for vendor_file in "$sysfs_root"/*/idVendor; do
            [[ -f "$vendor_file" ]] || continue
            read -r vendor <"$vendor_file" || continue
            [[ "${vendor,,}" == 0403 ]] || continue
            product_file=${vendor_file%/idVendor}/idProduct
            [[ -f "$product_file" ]] || continue
            read -r product <"$product_file" || continue
            [[ "${product,,}" == cc4d ]] || continue
            devnum_file=${vendor_file%/idVendor}/devnum
            read -r devnum <"$devnum_file" || devnum=unknown
            current="${vendor_file%/idVendor}:$devnum"
            break
        done
        if [[ -n "$current" && "$current" == "$previous" ]]; then
            ((stable += 1))
            ((stable >= 4)) && return 0
        else
            previous=$current
            stable=1
        fi
        sleep 0.5
    done
    return 1
}

wait_for_openport_state() {
    local expected=$1 instruction=$2 attempt
    printf '\n%s\n' "$instruction"
    for attempt in {1..120}; do
        if [[ "$expected" == present ]]; then
            openport_usb_present && wait_for_stable_openport && return 0
        else
            ! openport_usb_present && return 0
        fi
        sleep 0.5
    done
    fail "Timed out waiting for the OpenPort to become $expected."
    return 1
}

verify_openport_hotplug_cycle() {
    wait_for_openport_state absent \
        "Unplug the OpenPort 2.0 USB cable. Detection will continue automatically." || return 1
    ok "OpenPort removal detected."
    wait_for_openport_state present \
        "Plug the OpenPort 2.0 into USB. Detection will continue automatically." || return 1
    ok "OpenPort connection detected and stable."
    verify_openport_usb_access || return 1
    wait_for_openport_state absent \
        "Unplug the OpenPort once more to verify clean removal." || return 1
    ok "OpenPort plug/unplug detection passed."
}

write_openport_usb_diagnostics() {
    local sysfs_root=${OPENPORT_USB_SYSFS_ROOT:-/sys/bus/usb/devices}
    local vendor_file product_file device_dir vendor product busnum devnum node value
    local found=false

    printf 'Captured: %s\n' "$(date --iso-8601=seconds 2>/dev/null || date)"
    printf 'User and groups: %s\n' "$(id)"
    printf 'OpenPort lsusb: '
    if command -v lsusb >/dev/null 2>&1; then
        lsusb -d 0403:cc4d 2>&1 || true
        echo 'USB topology:'
        lsusb -t 2>&1 | sed 's/^/  /' || true
    else
        echo 'lsusb is unavailable'
    fi

    for vendor_file in "$sysfs_root"/*/idVendor; do
        [[ -f "$vendor_file" ]] || continue
        read -r vendor <"$vendor_file" || continue
        [[ "${vendor,,}" == 0403 ]] || continue
        device_dir=${vendor_file%/idVendor}
        product_file=$device_dir/idProduct
        [[ -f "$product_file" ]] || continue
        read -r product <"$product_file" || continue
        [[ "${product,,}" == cc4d ]] || continue
        found=true
        printf 'Sysfs device: %s\n' "${device_dir##*/}"
        for value in busnum devnum authorized speed version bNumInterfaces \
            bConfigurationValue configuration devpath removable; do
            if [[ -r "$device_dir/$value" ]]; then
                printf '  %s: ' "$value"
                sed -n '1p' "$device_dir/$value"
            fi
        done
        if [[ -L "$device_dir/driver" ]]; then
            printf '  kernel driver: %s\n' "$(basename -- "$(readlink -f "$device_dir/driver")")"
        else
            echo '  kernel driver: none'
        fi
        read -r busnum <"$device_dir/busnum" || busnum=
        read -r devnum <"$device_dir/devnum" || devnum=
        if [[ "$busnum" =~ ^[0-9]+$ && "$devnum" =~ ^[0-9]+$ ]]; then
            printf -v node '/dev/bus/usb/%03d/%03d' "$busnum" "$devnum"
            if [[ -e "$node" ]]; then
                stat -c '  device node: %A %U:%G (%a) %n' "$node" 2>&1 || true
                if command -v getfacl >/dev/null 2>&1; then
                    echo '  device node ACL:'
                    getfacl -cp "$node" 2>&1 | sed 's/^/    /' || true
                fi
                if run_with_openport_access test -r "$node"; then
                    echo '  effective read access: yes'
                else
                    echo '  effective read access: no'
                fi
                if run_with_openport_access test -w "$node"; then
                    echo '  effective write access: yes'
                else
                    echo '  effective write access: no'
                fi
                if command -v fuser >/dev/null 2>&1; then
                    echo '  processes using node:'
                    fuser -v "$node" 2>&1 | sed 's/^/    /' || echo '    none detected'
                fi
            else
                printf '  device node: missing (%s)\n' "$node"
            fi
        fi
        if command -v udevadm >/dev/null 2>&1; then
            echo '  udev properties:'
            udevadm info --query=property --path="$device_dir" 2>&1 | \
                sed 's/^/    /' || true
            echo '  udev attribute walk:'
            udevadm info --attribute-walk --path="$device_dir" 2>&1 | \
                sed 's/^/    /' || true
        fi
        for value in control runtime_status runtime_active_time runtime_suspended_time autosuspend; do
            if [[ -r "$device_dir/power/$value" ]]; then
                printf '  power/%s: ' "$value"
                sed -n '1p' "$device_dir/power/$value"
            fi
        done
    done
    $found || echo 'Sysfs OpenPort match: none'
    echo 'Installed OpenPort udev rule:'
    if [[ -r /etc/udev/rules.d/99-openport2.rules ]]; then
        stat -c '  %A %U:%G (%a) %n' /etc/udev/rules.d/99-openport2.rules 2>&1 || true
        sed 's/^/  /' /etc/udev/rules.d/99-openport2.rules
    else
        echo '  missing or unreadable'
    fi
    printf '%s group entry: ' "$openport_group"
    getent group "$openport_group" 2>&1 || echo 'missing'
    if command -v lsusb >/dev/null 2>&1; then
        echo 'Verbose OpenPort USB descriptor:'
        lsusb -v -d 0403:cc4d 2>&1 || true
    fi
    if command -v journalctl >/dev/null 2>&1; then
        echo 'Recent kernel USB events (filtered):'
        journalctl -k -n 300 --no-pager 2>&1 | \
            grep -Ei 'usb|0403|cc4d|ftdi|openport' | tail -120 || true
    fi
}

write_host_runtime_diagnostics() {
    local runtime_root="$data_dir/runtime/ecuflash-winegdk-11.1/files"
    local diagnostic_file

    printf 'Captured: %s\n' "$(date --iso-8601=seconds 2>/dev/null || date)"
    printf 'Hostname: %s\n' "$(hostname 2>&1 || echo unavailable)"
    printf 'User and groups: %s\n' "$(id)"
    printf 'Home: %s\n' "$HOME"
    echo 'Operating system:'
    if [[ -r /etc/os-release ]]; then
        sed 's/^/  /' /etc/os-release
    else
        echo '  /etc/os-release unavailable'
    fi
    printf 'Kernel: '
    uname -a 2>&1 || true
    printf 'Architecture: '
    uname -m 2>&1 || true
    printf 'Desktop session: XDG_SESSION_TYPE=%s XDG_CURRENT_DESKTOP=%s DESKTOP_SESSION=%s DISPLAY=%s WAYLAND_DISPLAY=%s\n' \
        "${XDG_SESSION_TYPE:-}" "${XDG_CURRENT_DESKTOP:-}" "${DESKTOP_SESSION:-}" \
        "${DISPLAY:-}" "${WAYLAND_DISPLAY:-}"
    printf 'Shell: %s\n' "${SHELL:-unknown}"
    echo 'Locale:'
    locale 2>&1 | sed 's/^/  /' || true
    printf 'Timezone: '
    timedatectl show --property=Timezone --value 2>&1 || date +%Z 2>&1 || true
    echo 'CPU summary:'
    if command -v lscpu >/dev/null 2>&1; then
        lscpu 2>&1 | grep -E '^(Architecture|CPU\(s\)|Model name|Vendor ID|Virtualization|Hypervisor vendor):' | \
            sed 's/^/  /' || true
    else
        echo '  lscpu unavailable'
    fi
    echo 'Display and USB controllers:'
    if command -v lspci >/dev/null 2>&1; then
        lspci -nnk 2>&1 | grep -A3 -Ei 'VGA compatible|3D controller|Display controller|USB controller' | \
            sed 's/^/  /' || true
    else
        echo '  lspci unavailable'
    fi
    echo 'Memory:'
    free -h 2>&1 | sed 's/^/  /' || true
    echo 'Filesystem capacity:'
    df -h "$HOME" /tmp 2>&1 | sed 's/^/  /' || true
    echo 'Relevant mount options:'
    if command -v findmnt >/dev/null 2>&1; then
        findmnt -T "$HOME" -o TARGET,SOURCE,FSTYPE,OPTIONS 2>&1 | sed 's/^/  /' || true
        findmnt -T /tmp -o TARGET,SOURCE,FSTYPE,OPTIONS 2>&1 | sed 's/^/  /' || true
    else
        echo '  findmnt unavailable'
    fi
    echo 'Network addresses:'
    if command -v ip >/dev/null 2>&1; then
        ip -brief address 2>&1 | sed 's/^/  /' || true
    else
        echo '  ip unavailable'
    fi
    echo 'Relevant installed packages:'
    case "$package_manager" in
        pacman)
            pacman -Q git github-cli libusb lib32-libusb usbutils wine wine-mono \
                llvm llvm-libs mingw-w64-gcc jre8-openjdk 2>&1 | sed 's/^/  /' || true
            ;;
        apt)
            dpkg-query -W git gh libusb-1.0-0 libusb-1.0-0:i386 usbutils \
                libwine-dev libwine-dev:i386 wine64-tools gcc-mingw-w64 \
                2>&1 | sed 's/^/  /' || true
            ;;
        *) echo '  supported package manager unavailable' ;;
    esac
    echo 'Relevant running processes:'
    ps -eo pid,user,stat,lstart,comm 2>&1 | \
        grep -Ei ' (wine|wine64|wineserver|wineboot|ecuflash|romraider|openport|j2534|java)$' | \
        tail -80 | sed 's/^/  /' || echo '  none detected'
    echo 'Relevant kernel modules:'
    if command -v lsmod >/dev/null 2>&1; then
        lsmod 2>&1 | grep -E '^(cdc_acm|usbcore|usb_common|xhci|ehci|uhci|ftdi)' | \
            sed 's/^/  /' || echo '  none detected'
    else
        echo '  lsmod unavailable'
    fi
    echo 'Installed runtime and bridge files:'
    printf 'Packaged Wine version: '
    "$runtime_root/bin/wine" --version 2>&1 || true
    for diagnostic_file in \
        "$runtime_root/bin/wine" \
        "$runtime_root/bin/wineserver" \
        "$ecuflash_prefix/drive_c/windows/syswow64/op20pt32.dll" \
        "$ecuflash_prefix/drive_c/windows/system32/drivers/openport.sys" \
        "$ecuflash_prefix/drive_c/windows/system32/drivers/openport.so" \
        "$data_dir/tools/j2534-probe.exe" \
        "$data_dir/tools/openport-device-probe.exe"; do
        if [[ -e "$diagnostic_file" ]]; then
            stat -c '  %A %U:%G (%a) %s bytes %y %n' "$diagnostic_file" 2>&1 || true
            sha256sum "$diagnostic_file" 2>&1 | sed 's/^/  sha256: /' || true
            file "$diagnostic_file" 2>&1 | sed 's/^/  type: /' || true
        else
            printf '  missing: %s\n' "$diagnostic_file"
        fi
    done
    echo 'OpenPort native bridge dependencies:'
    if command -v ldd >/dev/null 2>&1; then
        ldd "$ecuflash_prefix/drive_c/windows/system32/drivers/openport.so" 2>&1 | \
            sed 's/^/  /' || true
    else
        echo '  ldd unavailable'
    fi
}

usage() {
    printf 'Usage: %s [options]\n\n' "$0"
    cat <<'EOF'
  --check          Check the system without building or installing anything
  --update-files   Audit and update all installer-managed support files
  --install-deps   Install missing host packages with sudo
  --install-udev   Install the OpenPort 2.0 udev rule with sudo
  --install-ecuflash  Download and open Tactrix's official EcuFlash installer
  --install-romraider  Install RomRaider DimeMod with a bundled 32-bit JRE
  --install-evo-romraider  Install the optional NatZirt Evo MUT-II RomRaider fork
  --install-bergerraider   Install the optional BergerRaider foundation preview
  --install-definitions SOURCE  Install RomRaider definitions (official, stable, beta, alpha)
  --definition-units UNITS     metric, standard, or imperial (default: metric)
  --definition-language LANG   en or de (default: en)
  --vehicle-make/--vehicle-year/--vehicle-model VALUE  Record vehicle guidance
  --custom-editor-definition FILE  Import an experimental Editor XML
  --custom-logger-definition FILE  Import an experimental Logger XML
  --evoscan-installer FILE  Install a purchaser-supplied EvoScan EXE or MSI (experimental)
  --yes-all        Select all recommended installation components
  --clean-install  Remove installer-managed app/runtime state, then install recommended tools
  --uninstall      Remove files installed by Subaru & Evo ECU Tools
  --yes            Do not prompt before --clean-install or --uninstall
  -h, --help       Show this help

The default builds the bridge and installs support files under ~/.local.
RomRaider DimeMod is installed only when selected. The Evo MUT-II fork and
BergerRaider preview are separate opt-in components and never replace DimeMod.
Setup never supplies ROMs or vehicle firmware.
EOF
}

while (($#)); do
    case "$1" in
        --check) mode=check ;;
        --update-files) mode=update ;;
        --install-deps) install_deps=true ;;
        --install-udev) install_udev=true ;;
        --install-ecuflash) install_ecuflash=true ;;
        --install-romraider) install_romraider=true ;;
        --install-evo-romraider) install_evo_romraider=true ;;
        --install-bergerraider) install_bergerraider=true ;;
        --install-definitions)
            shift; (($#)) || { echo "--install-definitions requires a source." >&2; exit 2; }
            definition_source=$1; install_definitions=true; install_romraider=true
            ;;
        --definition-units) shift; definition_units=${1:?--definition-units requires a value} ;;
        --definition-language) shift; definition_language=${1:?--definition-language requires a value} ;;
        --vehicle-make) shift; vehicle_make=${1:?--vehicle-make requires a value} ;;
        --vehicle-year) shift; vehicle_year=${1:?--vehicle-year requires a value} ;;
        --vehicle-model) shift; vehicle_model=${1:?--vehicle-model requires a value} ;;
        --custom-editor-definition)
            shift; custom_editor_definition=${1:?--custom-editor-definition requires a file}
            install_definitions=true; install_romraider=true
            ;;
        --custom-logger-definition)
            shift; custom_logger_definition=${1:?--custom-logger-definition requires a file}
            install_definitions=true; install_romraider=true
            ;;
        --evoscan-installer)
            shift
            (($#)) || { echo "--evoscan-installer requires a file path." >&2; exit 2; }
            evoscan_installer=$1
            install_evoscan=true
            install_ecuflash=true
            ;;
        --yes-all) install_deps=true; install_udev=true; install_ecuflash=true; install_romraider=true; install_definitions=true ;;
        --clean-install)
            clean_install=true
            install_deps=true
            install_udev=true
            install_ecuflash=true
            install_romraider=true
            install_definitions=true
            ;;
        --uninstall) mode=uninstall ;;
        --yes) assume_yes=true ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

log_stamp=$(date +%Y%m%d-%H%M%S)
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/subaru-ecu-tools-linux"
if [[ "$mode" == uninstall ]]; then
    log_file="/tmp/subaru-ecu-tools-uninstall-$log_stamp.log"
else
    mkdir -p "$state_dir"
    log_file="$state_dir/setup-$log_stamp.log"
    ln -sfn "$(basename -- "$log_file")" "$state_dir/latest.log"
fi
if $use_color; then
    : >"$log_file"
    exec > >(tee >(sed -u $'s/\033\[[0-9;]*m//g' >>"$log_file")) 2>&1
else
    exec > >(tee -a "$log_file") 2>&1
fi
installer_banner
github_repo=Natzirt-BK/subaru-ecu-tools-linux
ecuflash_vendor_j2534_sha256=f432084801762d919a3c31974616e097562424470003edc4f4fb843df34103cf
offer_error_report() {
    local user_description=${1:-}
    local report_file full_report upload_error issue_url extra_log log_bytes usb_report host_report latest_ecuflash_log report_bytes

    [[ "$setup_interactive" == true && "${SUBARU_SETUP_NO_PAUSE:-0}" != 1 ]] || return 0
    warn "The public report may identify this computer and user. It includes the username, hostname, home paths, local network addresses, hardware and USB identifiers, adapter serial, groups, relevant packages/processes, permissions, and bounded application/system logs. It does not intentionally collect passwords, tokens, SSH keys, browser data, or an unfiltered environment. Review the report before sharing."
    read_yes_no "Upload this error log in a public GitHub issue so the maintainer can investigate?" no || return 0

    if ! command -v gh >/dev/null 2>&1; then
        echo "Automatic upload requires GitHub CLI. Install '$github_cli_package', run 'gh auth login', then retry."
        echo "No log was uploaded. Your log remains at: $log_file"
        return 0
    fi
    if ! gh auth status --hostname github.com >/dev/null 2>&1; then
        echo "GitHub CLI is not signed in. Run 'gh auth login', then retry."
        echo "No log was uploaded. Your log remains at: $log_file"
        return 0
    fi

    report_file="$state_dir/report-$log_stamp.md"
    full_report="$state_dir/report-$log_stamp-full.md"
    {
        echo "Setup submitted this report after a detected or user-reported problem."
        echo
        if [[ -n "$user_description" ]]; then
            echo "User description:"
            printf '%s\n' "$user_description" | sed 's/^/> /'
            echo
        fi
        echo "Installer log (last 12,000 bytes):"
        echo '```text'
        tail -c 12000 "$log_file"
        echo
        echo '```'
        echo "Source revision: $(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null || echo unknown)"
        echo "Installed launcher: $(sha256sum "$bin_dir/launch-ecuflash" 2>/dev/null || echo missing)"
        echo "Installed J2534 DLL: $(sha256sum "$ecuflash_prefix/drive_c/windows/syswow64/op20pt32.dll" 2>/dev/null || echo missing)"
        echo
        echo 'Host and installed-runtime diagnostics:'
        echo '(first 6,000 bytes; may include identifying host, user, network, hardware, process, and path details)'
        echo '```text'
        host_report=$(mktemp /tmp/subaru-ecu-tools-host-report.XXXXXX)
        write_host_runtime_diagnostics >"$host_report" 2>&1
        head -c 6000 "$host_report"
        rm -f -- "$host_report"
        echo
        echo '```'
        echo
        echo 'OpenPort USB access diagnostics:'
        echo '(first 10,000 bytes; may include adapter serial and host USB details)'
        echo '```text'
        usb_report=$(mktemp /tmp/subaru-ecu-tools-usb-report.XXXXXX)
        write_openport_usb_diagnostics >"$usb_report" 2>&1
        head -c 10000 "$usb_report"
        rm -f -- "$usb_report"
        echo
        echo '```'
        echo
        latest_ecuflash_log=$(find "$ecuflash_prefix/drive_c/users" -type f \
            -path '*/OpenECU/EcuFlash/logs/*' -printf '%T@ %p\n' 2>/dev/null | \
            sort -nr | head -1 | cut -d' ' -f2- || true)
        for extra_log in \
            "$cache_root/ecuflash-j2534-probe.log" \
            "$state_dir/ecuflash-j2534-probe.log" \
            "$cache_root/ecuflash-startup.log" \
            "$cache_root/ecuflash-post-probe-startup.log" \
            "$latest_ecuflash_log" \
            "$state_dir/ecuflash-force-refresh.log" \
            "$state_dir/ecuflash-j2534.log" \
            "$state_dir/ecuflash-launch.log" \
            "$state_dir/ecuflash-openport-registration.log" \
            "$cache_root/ecuflash-openport-registration.log" \
            "$state_dir/romraider-launch.log" \
            "$state_dir/evo-mut2-launch.log" \
            "$HOME/.RomRaider/romraider_sout.log"; do
            [[ -s "$extra_log" ]] || continue
            case "$extra_log" in
                *j2534-probe.log) log_bytes=10000 ;;
                *ecuflash_log_*) log_bytes=5000 ;;
                *) log_bytes=1500 ;;
            esac
            echo
            echo "Application log: $extra_log (last $log_bytes bytes)"
            echo '```text'
            tail -c "$log_bytes" "$extra_log"
            echo
            echo '```'
        done
    } >"$full_report"
    report_bytes=$(wc -c <"$full_report")
    if ((report_bytes <= 60000)); then
        mv -f -- "$full_report" "$report_file"
    else
        {
            echo 'Setup diagnostic report automatically shortened for the GitHub issue-body limit.'
            echo "Complete local report: $full_report ($report_bytes bytes)"
            echo
            echo 'First 28,000 bytes:'
            echo '```text'
            head -c 28000 "$full_report"
            echo
            echo '```'
            echo
            echo 'Middle omitted from the upload; retained in the complete local report.'
            echo
            echo 'Last 28,000 bytes:'
            echo '```text'
            tail -c 28000 "$full_report"
            echo
            echo '```'
        } >"$report_file"
    fi
    upload_error=$(mktemp /tmp/subaru-ecu-tools-upload-error.XXXXXX)
    if issue_url=$(gh issue create --repo "$github_repo" \
        --title "Setup diagnostic report ($log_stamp)" \
        --body-file "$report_file" 2>"$upload_error"); then
        echo "Error report uploaded: $issue_url"
        rm -f -- "$report_file" "$full_report"
    else
        echo "GitHub upload failed: $(tail -n 1 "$upload_error")" >&2
        if [[ -f "$full_report" ]]; then
            echo "The complete report remains at: $full_report" >&2
            echo "The GitHub-sized report remains at: $report_file" >&2
        else
            echo "The complete ready-to-share report remains at: $report_file" >&2
        fi
        echo "You can attach it manually at: https://github.com/$github_repo/issues/new" >&2
    fi
    rm -f -- "$upload_error"
}
confirm_success() {
    local question user_description

    [[ "$setup_interactive" == true && "${SUBARU_SETUP_NO_PAUSE:-0}" != 1 ]] || return 0
    case "$mode" in
        check) question="Did the system check complete as expected?" ;;
        uninstall) question="Did removal complete as expected?" ;;
        update) question="Did the update and automatic OpenPort test complete successfully?" ;;
        *) question="Did installation complete and do the installed shortcuts open correctly?" ;;
    esac
    if ! read_yes_no "$question" yes; then
        warn "The run exited successfully, but the user reported a problem."
        read -r -p "Briefly describe what went wrong (optional; do not include passwords or private data): " \
            user_description </dev/tty || user_description=
        offer_error_report "$user_description"
    else
        ok "Confirmed complete. No error report is needed."
    fi
}
wait_before_close() {
    [[ "$setup_interactive" == true && "${SUBARU_SETUP_NO_PAUSE:-0}" != 1 ]] || return 0
    ui_box_line "$color_cyan" '[ INPUT ] Press Enter to close this setup terminal...'
    printf '%b║%b  > ' "$color_purple$color_bold" "$color_reset"
    read -r _ </dev/tty || true
}
stop_setup_music() {
    local music_pid=${SUBARU_SETUP_MUSIC_PID:-}
    local state_file=${SUBARU_SETUP_MUSIC_STATE_FILE:-}
    if [[ "$music_pid" =~ ^[0-9]+$ ]]; then
        kill "$music_pid" 2>/dev/null || true
        wait "$music_pid" 2>/dev/null || true
    fi
    [[ -z "$state_file" ]] || rm -f -- "$state_file"
    unset SUBARU_SETUP_MUSIC_PID
    unset SUBARU_SETUP_MUSIC_STATE_FILE
}
log_result() {
    local status=$?
    trap - EXIT
    stop_setup_music
    if ((status)); then
        echo
        fail "Subaru & Evo ECU Tools stopped with status $status."
        echo "Share this diagnostic log when requesting help: $log_file"
        offer_error_report
    else
        ok "Run log saved: $log_file"
        confirm_success
    fi
    wait_before_close
    console_footer
    exit "$status"
}
trap log_result EXIT

bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
data_root="${XDG_DATA_HOME:-$HOME/.local/share}"
data_dir="$data_root/subaru-ecu-tools-linux"
applications_dir="$data_root/applications"
desktop_directories_dir="$data_root/desktop-directories"
menus_dir="${XDG_CONFIG_HOME:-$HOME/.config}/menus/applications-merged"
tools_menu_file="$menus_dir/subaru-ecu-tools.menu"
tools_directory_file="$desktop_directories_dir/subaru-ecu-tools.directory"
wine_ecuflash_menu_dir="$applications_dir/wine/Programs/EcuFlash"
cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/subaru-ecu-tools-linux"
ecuflash_prefix="${ECUFLASH_WINEPREFIX:-$data_root/ecuflash-proton}"
default_source_dir="$HOME/.local/src/subaru-ecu-tools-linux"
romraider_home="$data_root/romraider-dm20"
evo_romraider_home="$data_root/romraider-mut2-evo-88780008"
bergerraider_home="$data_root/bergerraider-ecu-studio-preview-1"
definitions_home="$data_root/subaru-evo-ecu-definitions"

if $clean_install; then
    section "Clean reinstall"
    warn "This removes the installer-managed EcuFlash/EvoScan prefix, Wine runtime, bridge, launchers, cache, and recommended RomRaider package."
    echo "ROMs, definitions, logs, separately installed software, and both optional preview packages are preserved."
    if ! $assume_yes; then
        read_yes_no "Continue with the clean reinstall?" no || {
            echo "Clean reinstall cancelled."
            exit 0
        }
    fi

    if [[ -x "$data_dir/runtime/ecuflash-winegdk-11.1/files/bin/wineserver" ]]; then
        WINEPREFIX="$ecuflash_prefix" \
            "$data_dir/runtime/ecuflash-winegdk-11.1/files/bin/wineserver" -k >/dev/null 2>&1 || true
        WINEPREFIX="$ecuflash_prefix" \
            "$data_dir/runtime/ecuflash-winegdk-11.1/files/bin/wineserver" -w >/dev/null 2>&1 || true
    fi
    command -v wineserver >/dev/null 2>&1 && \
        WINEPREFIX="$ecuflash_prefix" wineserver -k >/dev/null 2>&1 || true
    rm -rf -- "$data_dir" "$ecuflash_prefix" "$cache_root" "$wine_ecuflash_menu_dir"
    rm -f -- \
        "$bin_dir/launch-ecuflash" \
        "$bin_dir/launch-evoscan" \
        "$bin_dir/launch-romraider" \
        "$bin_dir/launch-romraider-evo-mut2" \
        "$bin_dir/install-evo-romraider-mut2" \
        "$bin_dir/launch-bergerraider" \
        "$bin_dir/install-bergerraider-preview" \
        "$bin_dir/sync-openport-device-state" \
        "$bin_dir/monitor-openport-state" \
        "$bin_dir/configure-romraider-definitions" \
        "$bin_dir/install-romraider-definitions" \
        "$applications_dir/ecuflash.desktop" \
        "$applications_dir/evoscan.desktop" \
        "$applications_dir/romraider-editor.desktop" \
        "$applications_dir/romraider-logger.desktop" \
        "$applications_dir/romraider-evo-mut2-editor.desktop" \
        "$applications_dir/romraider-evo-mut2-logger.desktop" \
        "$applications_dir/bergerraider-editor.desktop" \
        "$applications_dir/bergerraider-logger.desktop" \
        "$applications_dir/subaru-ecu-tools-setup.desktop" \
        "$applications_dir/subaru-ecu-tools-update.desktop" \
        "$tools_menu_file" \
        "$tools_directory_file"
    if [[ -f "$romraider_home/.installed-by-subaru-ecu-tools" ]]; then
        rm -rf -- "$romraider_home"
    fi
    ok "Old installer-managed application and runtime state removed."
fi

create_documents_shortcuts() {
    local documents_dir tools_documents link target documents_evoscan_exe=
    local active_editor_definition= active_logger_definition= documents_line

    if command -v xdg-user-dir >/dev/null 2>&1; then
        documents_dir=$(xdg-user-dir DOCUMENTS 2>/dev/null || true)
    fi
    if [[ -z "${documents_dir:-}" || "$documents_dir" == "$HOME" ]]; then
        documents_dir="$HOME/Documents"
    fi
    tools_documents="$documents_dir/Subaru & Evo ECU Tools"
    install -d \
        "$definitions_home/editor" \
        "$definitions_home/logger" \
        "$definitions_home/imported" \
        "$tools_documents/RomRaider Editor" \
        "$tools_documents/RomRaider Logger" \
        "$tools_documents/EcuFlash" \
        "$tools_documents/EvoScan" \
        "$tools_documents/Diagnostic Logs"
    if [[ -f "$evo_romraider_home/.installed-by-subaru-ecu-tools" ]]; then
        install -d "$tools_documents/Evo RomRaider MUT-II"
    fi
    if [[ -f "$bergerraider_home/.installed-by-subaru-ecu-tools" ]]; then
        install -d "$tools_documents/BergerRaider Preview"
    fi

    if [[ -f "$data_dir/evoscan-exe.path" ]]; then
        IFS= read -r documents_evoscan_exe <"$data_dir/evoscan-exe.path" || true
    fi
    if [[ -f "$data_dir/definitions-active.conf" ]]; then
        while IFS= read -r documents_line; do
            case "$documents_line" in
                EDITOR_DEFINITION=*) active_editor_definition=${documents_line#*=} ;;
                LOGGER_DEFINITION=*) active_logger_definition=${documents_line#*=} ;;
            esac
        done <"$data_dir/definitions-active.conf"
    fi

    add_documents_link() {
        link=$1
        target=$2
        [[ -e "$target" ]] || return 0
        if [[ -L "$link" ]]; then
            ln -sfn -- "$target" "$link"
        elif [[ ! -e "$link" ]]; then
            ln -s -- "$target" "$link"
        else
            warn "Preserving the existing Documents item instead of replacing it: $link"
        fi
    }

    add_documents_link "$tools_documents/RomRaider Editor/Definitions" \
        "$definitions_home/editor"
    add_documents_link "$tools_documents/RomRaider Logger/Definitions" \
        "$definitions_home/logger"
    add_documents_link "$tools_documents/RomRaider Editor/Imported Definitions" \
        "$definitions_home/imported"
    add_documents_link "$tools_documents/RomRaider Editor/Active Definition.xml" \
        "${active_editor_definition:-/path/that/does/not/exist}"
    add_documents_link "$tools_documents/RomRaider Logger/Active Definition.xml" \
        "${active_logger_definition:-/path/that/does/not/exist}"
    add_documents_link "$tools_documents/Evo RomRaider MUT-II/Definitions" \
        "$evo_romraider_home/definitions"
    add_documents_link "$tools_documents/Evo RomRaider MUT-II/Release Notes.md" \
        "$evo_romraider_home/RELEASE_NOTES.md"
    add_documents_link "$tools_documents/BergerRaider Preview/Definitions" \
        "$bergerraider_home/definitions"
    add_documents_link "$tools_documents/BergerRaider Preview/Release Notes.md" \
        "$bergerraider_home/RELEASE_NOTES.md"
    add_documents_link "$tools_documents/EcuFlash/Definitions" \
        "$ecuflash_prefix/drive_c/Program Files (x86)/OpenECU/EcuFlash/rommetadata"
    add_documents_link "$tools_documents/EvoScan/Installed Program" \
        "${documents_evoscan_exe:-/path/that/does/not/exist}"
    add_documents_link "$tools_documents/Diagnostic Logs/Setup Logs" "$state_dir"
    add_documents_link "$tools_documents/Diagnostic Logs/RomRaider Logs" "$HOME/.RomRaider"
    printf '%s\n' \
        'These folders are shortcuts to the files used by Subaru & Evo ECU Tools.' \
        'Changes made through these shortcuts affect the real definitions and logs.' \
        'RomRaider normally configures definition paths automatically.' \
        'Do not select a definition by model year alone; verify the exact ROM ID.' \
        >"$tools_documents/README - File Locations.txt"
    ok "Easy-access folders: $tools_documents"
}

install_managed_user_files() {
    local source target desktop rendered expected_mode actual_mode setup_script
    local checked=0 updated=0 current=0
    local -a desktop_names

    setup_script=$repo_root/linux/setup-cachyos-gui.sh
    [[ "$distro_family" == debian ]] && setup_script=$repo_root/linux/setup-debian-gui.sh

    install -d "$bin_dir" "$applications_dir" "$desktop_directories_dir" \
        "$menus_dir" "$data_dir/registry"

    update_managed_file() {
        source=$1
        target=$2
        mode_bits=$3
        expected_mode=${mode_bits#0}
        ((checked+=1))
        actual_mode=$(stat -c '%a' "$target" 2>/dev/null || true)
        if [[ -f "$target" ]] && cmp -s "$source" "$target" && \
           [[ "$actual_mode" == "$expected_mode" ]]; then
            ((current+=1))
            step "Current: ${target#"$HOME/"}"
        else
            install -m "$mode_bits" "$source" "$target"
            ((updated+=1))
            ok "Updated: ${target#"$HOME/"}"
        fi
    }

    for source in launch-ecuflash launch-evoscan launch-romraider \
        launch-romraider-evo-mut2 install-evo-romraider-mut2 \
        launch-bergerraider install-bergerraider-preview \
        sync-openport-device-state monitor-openport-state \
        configure-romraider-definitions install-romraider-definitions; do
        update_managed_file "$repo_root/linux/$source" "$bin_dir/$source" 0755
    done
    update_managed_file "$repo_root/wine-bridge/openport-driver-wine.reg" \
        "$data_dir/registry/openport-driver-wine.reg" 0644
    update_managed_file "$repo_root/wine-bridge/openport2-wine.reg" \
        "$data_dir/registry/openport2-wine.reg" 0644
    update_managed_file "$repo_root/wine-bridge/openport2-device-present.reg" \
        "$data_dir/registry/openport2-device-present.reg" 0644
    update_managed_file "$repo_root/wine-bridge/openport2-device-absent.reg" \
        "$data_dir/registry/openport2-device-absent.reg" 0644
    desktop_names=(ecuflash evoscan romraider-editor romraider-logger
        subaru-ecu-tools-setup)
    if $install_evo_romraider || \
       [[ -f "$evo_romraider_home/.installed-by-subaru-ecu-tools" ]]; then
        desktop_names+=(romraider-evo-mut2-editor romraider-evo-mut2-logger)
    else
        rm -f -- \
            "$applications_dir/romraider-evo-mut2-editor.desktop" \
            "$applications_dir/romraider-evo-mut2-logger.desktop"
    fi
    if $install_bergerraider || \
       [[ -f "$bergerraider_home/.installed-by-subaru-ecu-tools" ]]; then
        desktop_names+=(bergerraider-editor bergerraider-logger)
    else
        rm -f -- \
            "$applications_dir/bergerraider-editor.desktop" \
            "$applications_dir/bergerraider-logger.desktop"
    fi
    for desktop in "${desktop_names[@]}"; do
        rendered=$(mktemp "$cache_root/desktop-$desktop.XXXXXX")
        sed -e "s|@BINDIR@|$bin_dir|g" \
            -e "s|@SETUP@|$setup_script|g" \
            "$repo_root/linux/$desktop.desktop" \
            >"$rendered"
        update_managed_file "$rendered" "$applications_dir/$desktop.desktop" 0644
        rm -f -- "$rendered"
    done
    if [[ -e "$applications_dir/subaru-ecu-tools-update.desktop" ]]; then
        rm -f -- "$applications_dir/subaru-ecu-tools-update.desktop"
        ok "Removed the redundant Update shortcut; Setup now offers updates first."
    fi
    update_managed_file "$repo_root/linux/subaru-ecu-tools.directory" \
        "$tools_directory_file" 0644
    update_managed_file "$repo_root/linux/subaru-ecu-tools.menu" \
        "$tools_menu_file" 0644
    command -v update-desktop-database >/dev/null && \
        update-desktop-database "$applications_dir" >/dev/null 2>&1 || true
    ok "Application menu folder: Subaru & Evo ECU Tools"
    ok "Managed-file audit complete: $checked checked, $updated updated, $current already current."
}

ecuflash_runtime_url=https://github.com/Natzirt-BK/subaru-ecu-tools-linux/releases/download/ecuflash-winegdk-11.1-validated-1/ecuflash-winegdk-11.1-validated.tar.zst
ecuflash_runtime_sha256=065b6e7f12c77c717946806c7272fdadfbfcf7d9328593de630c7f7a72dc45c1
ecuflash_wine_sha256=c249f6017f910365dc51b7a1ba5114004fca12aa4182fdeb6e404b8591658b11
ecuflash_runtime_archive="$cache_root/ecuflash-winegdk-11.1-validated.tar.zst"
ecuflash_runtime_root="$data_dir/runtime"
ecuflash_runtime_dir="$ecuflash_runtime_root/ecuflash-winegdk-11.1"
install_ecuflash_runtime() {
    mkdir -p "$cache_root" "$ecuflash_runtime_root"
    if [[ ! -f "$ecuflash_runtime_archive" ]] || \
       ! printf '%s  %s\n' "$ecuflash_runtime_sha256" "$ecuflash_runtime_archive" | \
           sha256sum -c - >/dev/null 2>&1; then
        step "Downloading the validated WineGDK 11.1 runtime"
        curl --fail --location --progress-bar \
            --output "$ecuflash_runtime_archive" "$ecuflash_runtime_url"
    fi
    printf '%s  %s\n' "$ecuflash_runtime_sha256" "$ecuflash_runtime_archive" | sha256sum -c - >/dev/null
    if [[ ! -x "$ecuflash_runtime_dir/files/bin/wine" ]] || \
       ! printf '%s  %s\n' "$ecuflash_wine_sha256" "$ecuflash_runtime_dir/files/bin/wine" | \
           sha256sum -c - >/dev/null 2>&1 || \
       [[ ! -f "$ecuflash_runtime_dir/LICENSE" ]] || \
       [[ ! -f "$ecuflash_runtime_dir/engine-manifest.json" ]]; then
        rm -rf -- "$ecuflash_runtime_dir"
        tar --zstd -xf "$ecuflash_runtime_archive" -C "$ecuflash_runtime_root"
    fi
    if [[ ! -x "$ecuflash_runtime_dir/files/bin/wine" ]] || \
       ! printf '%s  %s\n' "$ecuflash_wine_sha256" "$ecuflash_runtime_dir/files/bin/wine" | \
           sha256sum -c - >/dev/null 2>&1 || \
       [[ ! -f "$ecuflash_runtime_dir/LICENSE" ]] || \
       [[ ! -f "$ecuflash_runtime_dir/engine-manifest.json" ]]; then
        fail "The verified Wine 11.1 runtime is incomplete."
        exit 1
    fi
    ok "Validated WineGDK 11.1 runtime and provenance verified."
}

restore_openport_after_probe() {
    local wine_runner=$1 prefix=$2 registry_dir=$3 restore_log=$4 expect_present=${5:-false}
    stop_wine_prefix "$wine_runner" "$prefix" "$restore_log"
    if [[ "$expect_present" == true ]] && ! wait_for_stable_openport; then
        warn "OpenPort did not remain stable after the communication probe."
    fi
    OPENPORT_REGISTRY_DIR="$registry_dir" \
    OPENPORT_STATE_LOG="$restore_log" \
    ECUFLASH_WINE="$wine_runner" \
    ECUFLASH_WINEPREFIX="$prefix" \
        "$bin_dir/sync-openport-device-state" >/dev/null
}

if [[ "$mode" == update ]]; then
    section "Auditing installed files against the latest release"
    if ! romraider_libusb_runtime >/dev/null; then
        step "Installing the 32-bit USB runtime required by RomRaider Logger"
        case "$distro_family" in
            arch) install_host_packages lib32-libusb ;;
            debian) install_host_packages libusb-1.0-0:i386 ;;
            *) fail "Updates are unsupported on $distro_label."; exit 1 ;;
        esac
    else
        ok "RomRaider Logger 32-bit USB runtime is current."
    fi
    mkdir -p "$cache_root"
    install_managed_user_files
    if [[ -f "$ecuflash_prefix/drive_c/Program Files (x86)/OpenECU/EcuFlash/ecuflash.exe" ]]; then
        section "Rebuilding the installed OpenPort J2534 bridge"
        bridge_build_log="$cache_root/openport-bridge-build.log"
        if "$repo_root/wine-bridge/build-openport-driver.sh" >"$bridge_build_log" 2>&1; then
            install -d "$data_dir/winedll/x86_64-windows" "$data_dir/winedll/x86_64-unix"
            install -m 0644 "$repo_root/build-wine-bridge/winedll/x86_64-windows/openport.sys" \
                "$data_dir/winedll/x86_64-windows/openport.sys"
            install -m 0755 "$repo_root/build-wine-bridge/winedll/x86_64-unix/openport.so" \
                "$data_dir/winedll/x86_64-unix/openport.so"
            rm -f -- "$data_dir/winedll/i386-windows/op20pt32.dll" \
                "$data_dir/winedll/i386-windows/j2534.dll" \
                "$data_dir/winedll/x86_64-unix/op20pt32.so" \
                "$data_dir/winedll/x86_64-unix/j2534.so"
            install -d "$data_dir/tools"
            install -m 0755 "$repo_root/build-wine-bridge/j2534-probe.exe" \
                "$data_dir/tools/j2534-probe.exe"
            install -m 0755 "$repo_root/build-wine-bridge/openport-device-probe.exe" \
                "$data_dir/tools/openport-device-probe.exe"
            ok "OpenPort kernel bridge and diagnostic files are current."
        else
            fail "OpenPort bridge update failed. Diagnostic log: $bridge_build_log"
            tail -50 "$bridge_build_log" >&2 || true
            exit 1
        fi
        section "Checking the installed EcuFlash runtime"
        install_ecuflash_runtime
        section "Force-refreshing Wine and OpenPort dependencies"
        update_wine=${ECUFLASH_WINE:-$ecuflash_runtime_dir/files/bin/wine}
        command -v "$update_wine" >/dev/null 2>&1 || [[ -x "$update_wine" ]] || {
            fail "The configured EcuFlash Wine runner is missing: $update_wine"
            exit 1
        }
        update_runtime_bin=$(dirname -- "$(command -v "$update_wine" 2>/dev/null || printf '%s' "$update_wine")")
        update_wineserver="$update_runtime_bin/wineserver"
        update_driver_dir="$ecuflash_prefix/drive_c/windows/system32/drivers"
        update_j2534_target="$ecuflash_prefix/drive_c/windows/syswow64/op20pt32.dll"
        update_j2534_vendor="$ecuflash_prefix/drive_c/Program Files (x86)/OpenECU/EcuFlash/drivers/openport 2.0/op20pt32.dll"
        update_refresh_log="$state_dir/ecuflash-force-refresh.log"
        update_probe_log="$state_dir/ecuflash-j2534-probe.log"
        install -d "$update_driver_dir" "$(dirname -- "$update_j2534_target")" "$state_dir"
        WINEPREFIX="$ecuflash_prefix" "$update_wineserver" -k >/dev/null 2>&1 || true
        WINEPREFIX="$ecuflash_prefix" "$update_wineserver" -w >/dev/null 2>&1 || true
        rm -f -- \
            "$ecuflash_prefix/.openport-bridge-registered-v1" \
            "$ecuflash_prefix/.openport-bridge-registered-v2" \
            "$ecuflash_prefix/.openport-bridge-registered-v3"
        WINEPREFIX="$ecuflash_prefix" WINEDEBUG=-all \
            "$update_wine" wineboot -u >"$update_refresh_log" 2>&1
        printf '%s  %s\n' "$ecuflash_vendor_j2534_sha256" "$update_j2534_vendor" | \
            sha256sum -c - >/dev/null 2>&1 || {
            fail "The official Tactrix J2534 DLL is missing or altered; run a Clean reinstall."
            exit 1
        }
        install -m 0644 "$update_j2534_vendor" \
            "$update_j2534_target"
        install -m 0644 "$data_dir/winedll/x86_64-windows/openport.sys" \
            "$update_driver_dir/openport.sys"
        install -m 0755 "$data_dir/winedll/x86_64-unix/openport.so" \
            "$update_driver_dir/openport.so"
        WINEPREFIX="$ecuflash_prefix" WINEDEBUG=-all LOG_ENABLE="$state_dir/ecuflash-j2534.log" \
            "$update_wine" regedit /S "$data_dir/registry/openport2-wine.reg" \
            >>"$update_refresh_log" 2>&1
        WINEPREFIX="$ecuflash_prefix" WINEDEBUG=-all LOG_ENABLE="$state_dir/ecuflash-j2534.log" \
            "$update_wine" regedit /S "$data_dir/registry/openport-driver-wine.reg" \
            >>"$update_refresh_log" 2>&1
        OPENPORT_REGISTRY_DIR="$data_dir/registry" \
        OPENPORT_STATE_LOG="$update_refresh_log" \
        ECUFLASH_WINE="$update_wine" \
        ECUFLASH_WINEPREFIX="$ecuflash_prefix" \
            "$bin_dir/sync-openport-device-state" >/dev/null
        # Start the probe in a fresh Wine session so PnP sees the state that was
        # just imported and binds openport.sys before the official DLL opens it.
        stop_wine_prefix "$update_wine" "$ecuflash_prefix" "$update_refresh_log"
        cmp -s "$update_j2534_vendor" "$update_j2534_target" || {
            fail "The EcuFlash J2534 DLL failed post-update verification."
            exit 1
        }
        cmp -s "$data_dir/winedll/x86_64-windows/openport.sys" \
            "$update_driver_dir/openport.sys" || {
            fail "The OpenPort Wine driver failed post-update verification."
            exit 1
        }
        ok "Wine stopped, dependencies refreshed, bridge reloaded, and hashes verified."
        if openport_usb_present; then
            : >"$update_probe_log"
            # Starting the kernel service creates the standalone Wine device
            # link.  Prime it before the official DLL attempts PassThruOpen.
            capture_openport_device_probe "$update_wine" "$ecuflash_prefix" \
                "$data_dir/winedll" "$data_dir/tools/openport-device-probe.exe" \
                "$update_probe_log"
            set +e
            run_with_openport_access env WINEPREFIX="$ecuflash_prefix" \
                WINEDLLPATH="$data_dir/winedll" \
                WINEDEBUG=-all LOG_ENABLE="$state_dir/ecuflash-j2534.log" \
                "$update_wine" "$data_dir/tools/j2534-probe.exe" \
                >>"$update_probe_log" 2>&1
            update_probe_status=$?
            set -e
            restore_openport_after_probe "$update_wine" "$ecuflash_prefix" \
                "$data_dir/registry" "$update_refresh_log" true
            if ((update_probe_status)); then
                capture_verbose_openport_probe "$update_wine" "$ecuflash_prefix" \
                    "$data_dir/winedll" "$data_dir/tools/j2534-probe.exe" \
                    "$update_probe_log"
                # Keep the compact binding result after the verbose trace so it
                # survives the bounded tail included in public issue reports.
                capture_openport_device_probe "$update_wine" "$ecuflash_prefix" \
                    "$data_dir/winedll" "$data_dir/tools/openport-device-probe.exe" \
                    "$update_probe_log"
                restore_openport_after_probe "$update_wine" "$ecuflash_prefix" \
                    "$data_dir/registry" "$update_refresh_log" true
                fail "The read-only OpenPort J2534 probe failed with status $update_probe_status."
                echo "Diagnostic log: $update_probe_log" >&2
                tail -50 "$update_probe_log" >&2 || true
                exit 1
            fi
            ok "Read-only OpenPort J2534 probe passed."
        else
            set +e
            run_with_openport_access env WINEPREFIX="$ecuflash_prefix" \
                WINEDLLPATH="$data_dir/winedll" \
                WINEDEBUG=-all LOG_ENABLE="$state_dir/ecuflash-j2534.log" \
                "$update_wine" "$data_dir/tools/j2534-probe.exe" --expect-absent \
                >"$update_probe_log" 2>&1
            update_probe_status=$?
            set -e
            restore_openport_after_probe "$update_wine" "$ecuflash_prefix" \
                "$data_dir/registry" "$update_refresh_log"
            if ((update_probe_status)); then
                fail "The unplugged OpenPort probe did not report device-not-connected."
                echo "Diagnostic log: $update_probe_log" >&2
                tail -50 "$update_probe_log" >&2 || true
                exit 1
            fi
            ok "Unplugged OpenPort probe correctly reported device-not-connected."
        fi
    fi
    create_documents_shortcuts
    ok "Every installer-managed launcher, registry file, and desktop entry is current."
    echo "Large runtimes and vendor applications were not reinstalled."
    exit 0
fi

if [[ "$mode" == uninstall ]]; then
    section "Remove Subaru & Evo ECU Tools"
    warn "The following project-managed files will be removed:"
    printf '  %s\n' \
        "$bin_dir/launch-ecuflash" \
        "$bin_dir/launch-evoscan" \
        "$bin_dir/launch-romraider" \
        "$bin_dir/launch-romraider-evo-mut2" \
        "$bin_dir/install-evo-romraider-mut2" \
        "$bin_dir/launch-bergerraider" \
        "$bin_dir/install-bergerraider-preview" \
        "$bin_dir/sync-openport-device-state" \
        "$bin_dir/monitor-openport-state" \
        "$bin_dir/configure-romraider-definitions" \
        "$bin_dir/install-romraider-definitions" \
        "$data_dir" \
        "$ecuflash_prefix" \
        "$cache_root" \
        "$state_dir" \
        "$wine_ecuflash_menu_dir" \
        "$applications_dir/ecuflash.desktop" \
        "$applications_dir/evoscan.desktop" \
        "$applications_dir/romraider-editor.desktop" \
        "$applications_dir/romraider-logger.desktop" \
        "$applications_dir/romraider-evo-mut2-editor.desktop" \
        "$applications_dir/romraider-evo-mut2-logger.desktop" \
        "$applications_dir/bergerraider-editor.desktop" \
        "$applications_dir/bergerraider-logger.desktop" \
        "$applications_dir/subaru-ecu-tools-setup.desktop" \
        "$applications_dir/subaru-ecu-tools-update.desktop" \
        "$tools_menu_file" \
        "$tools_directory_file" \
        "/etc/udev/rules.d/99-openport2.rules"
    if [[ "$repo_root" == "$default_source_dir" ]]; then
        printf '  %s\n' "$default_source_dir"
    fi
    if [[ -f "$romraider_home/.installed-by-subaru-ecu-tools" ]]; then
        printf '  %s\n' "$romraider_home"
        echo "The installer-managed RomRaider package will be removed; definitions in $definitions_home and logs remain preserved."
    else
        echo "Separately installed RomRaider DimeMod, ROMs, definitions, logs, and shared packages are preserved."
    fi
    if [[ -f "$evo_romraider_home/.installed-by-subaru-ecu-tools" ]]; then
        printf '  %s\n' "$evo_romraider_home"
        echo "The optional installer-managed Evo MUT-II package will also be removed."
    fi
    if [[ -f "$bergerraider_home/.installed-by-subaru-ecu-tools" ]]; then
        printf '  %s\n' "$bergerraider_home"
        echo "The optional installer-managed BergerRaider preview will also be removed."
    fi

    if ! $assume_yes; then
        read_yes_no "Remove these Subaru & Evo ECU Tools files?" no || {
            echo "Uninstall cancelled."
            exit 0
        }
    fi

    rm -f -- \
        "$bin_dir/launch-ecuflash" \
        "$bin_dir/launch-evoscan" \
        "$bin_dir/launch-romraider" \
        "$bin_dir/launch-romraider-evo-mut2" \
        "$bin_dir/install-evo-romraider-mut2" \
        "$bin_dir/launch-bergerraider" \
        "$bin_dir/install-bergerraider-preview" \
        "$bin_dir/sync-openport-device-state" \
        "$bin_dir/monitor-openport-state" \
        "$bin_dir/configure-romraider-definitions" \
        "$bin_dir/install-romraider-definitions" \
        "$applications_dir/ecuflash.desktop" \
        "$applications_dir/evoscan.desktop" \
        "$applications_dir/romraider-editor.desktop" \
        "$applications_dir/romraider-logger.desktop" \
        "$applications_dir/romraider-evo-mut2-editor.desktop" \
        "$applications_dir/romraider-evo-mut2-logger.desktop" \
        "$applications_dir/bergerraider-editor.desktop" \
        "$applications_dir/bergerraider-logger.desktop" \
        "$applications_dir/subaru-ecu-tools-setup.desktop" \
        "$applications_dir/subaru-ecu-tools-update.desktop" \
        "$tools_menu_file" \
        "$tools_directory_file"
    rm -rf -- "$data_dir" "$ecuflash_prefix" "$cache_root" "$state_dir" \
        "$wine_ecuflash_menu_dir"
    if [[ -f "$romraider_home/.installed-by-subaru-ecu-tools" ]]; then
        rm -rf -- "$romraider_home"
    fi
    if [[ -f "$evo_romraider_home/.installed-by-subaru-ecu-tools" ]]; then
        rm -rf -- "$evo_romraider_home"
    fi
    if [[ -f "$bergerraider_home/.installed-by-subaru-ecu-tools" ]]; then
        rm -rf -- "$bergerraider_home"
    fi
    if [[ -e /etc/udev/rules.d/99-openport2.rules ]]; then
        run_with_music_keys_paused sudo rm -f -- /etc/udev/rules.d/99-openport2.rules
        run_with_music_keys_paused sudo udevadm control --reload-rules
        run_with_music_keys_paused sudo udevadm trigger --subsystem-match=usb
    fi
    command -v update-desktop-database >/dev/null && \
        update-desktop-database "$applications_dir" >/dev/null 2>&1 || true
    if [[ "$repo_root" == "$default_source_dir" ]]; then
        rm -rf -- "$default_source_dir"
    fi
    ok "Subaru & Evo ECU Tools removal completed."
    echo "The final removal log is outside the installed paths: $log_file"
    exit 0
fi

if $install_evoscan; then
    [[ -f "$evoscan_installer" ]] || {
        fail "The selected EvoScan installer does not exist: $evoscan_installer"
        exit 1
    }
    file --brief "$evoscan_installer" | grep -Eq 'PE32|MSI|Microsoft|Composite Document' || {
        fail "The selected file is not a Windows EXE/MSI installer: $evoscan_installer"
        exit 1
    }
fi

if [[ "$distro_family" == unsupported ]]; then
    fail "Supported hosts are CachyOS/Arch and Debian-family amd64; detected $distro_label."
    exit 1
fi
if [[ "$(uname -m)" != x86_64 ]]; then
    fail "This release requires an x86_64/amd64 host; detected $(uname -m)."
    exit 1
fi

section "Checking dependencies"
case "$distro_family" in
    arch)
        packages=(base-devel curl github-cli libnotify libusb lib32-libusb unzip wine llvm-mingw zstd)
        install_hint="sudo pacman -S --needed"
        ;;
    debian)
        packages=(build-essential ca-certificates curl file git gh libnotify-bin libusb-1.0-0
            libusb-1.0-0-dev libusb-1.0-0:i386 unzip zstd usbutils udev
            desktop-file-utils sudo wine64-tools libwine-dev libwine-dev:i386 gcc-mingw-w64
            libxtst6:i386 libxi6:i386 libxinerama1:i386 libxrandr2:i386)
        install_hint="sudo apt-get install --no-install-recommends"
        ;;
esac
missing=()
for package in "${packages[@]}"; do
    package_installed "$package" || missing+=("$package")
done

if ((${#missing[@]})); then
    warn "Missing packages: ${missing[*]}"
    if $install_deps; then
        step "Installing missing $distro_label packages"
        install_host_packages "${missing[@]}"
        missing=()
        for package in "${packages[@]}"; do
            package_installed "$package" || missing+=("$package")
        done
        ((${#missing[@]} == 0)) || {
            fail "Packages remain missing after installation: ${missing[*]}"
            exit 1
        }
    else
        echo "Re-run with --install-deps, or install them with:"
        if [[ "$distro_family" == debian ]] && \
           ! dpkg --print-foreign-architectures | grep -qx i386; then
            echo "  sudo dpkg --add-architecture i386 && sudo apt-get update"
        fi
        echo "  $install_hint ${missing[*]}"
    fi
fi

checks_failed=0
check_path() {
    local description=$1 path=$2
    if [[ -e "$path" ]]; then
        ok "$description"
    else
        fail "MISSING: $description ($path)"
        checks_failed=1
    fi
}

check_path "libusb headers" /usr/include/libusb-1.0/libusb.h
if romraider_libusb_path=$(romraider_libusb_runtime); then
    ok "RomRaider 32-bit libusb runtime ($romraider_libusb_path)"
else
    fail "MISSING: RomRaider 32-bit libusb runtime"
    checks_failed=1
fi
if bridge_config=$("$repo_root/wine-bridge/build-openport-driver.sh" --check 2>&1); then
    ok "OpenPort bridge compilers, Wine headers, and startup library"
    while IFS= read -r bridge_config_line; do
        summary_row BUILD "$bridge_config_line"
    done <<<"$bridge_config"
else
    fail "MISSING: OpenPort bridge build prerequisites"
    printf '%s\n' "$bridge_config" >&2
    checks_failed=1
fi
command -v cc >/dev/null || { echo "MISSING: C compiler"; checks_failed=1; }

if [[ "$mode" == check ]]; then
    check_data_root="${XDG_DATA_HOME:-$HOME/.local/share}"
    check_ecuflash="$check_data_root/ecuflash-proton/drive_c/Program Files (x86)/OpenECU/EcuFlash/ecuflash.exe"
    check_evoscan=$(find "$check_data_root/ecuflash-proton/drive_c" -type f \
        -iname 'EvoScan*.exe' ! -iname '*setup*' ! -iname '*unins*' -print -quit 2>/dev/null || true)
    check_romraider="$check_data_root/romraider-dm20"
    [[ -f "$check_ecuflash" ]] && ok "EcuFlash installed" || \
        warn "NOT INSTALLED: EcuFlash"
    [[ -n "$check_evoscan" ]] && ok "EvoScan installed (experimental Linux support)" || \
        warn "NOT INSTALLED: EvoScan (optional, purchaser-supplied installer required)"
    if [[ -f "$check_romraider/RomRaider.jar" && -x "$check_romraider/jre32/bin/java" ]]; then
        ok "RomRaider DimeMod with bundled 32-bit Java detected"
    else
        warn "NOT INSTALLED: complete RomRaider DimeMod Linux package"
    fi
    check_evo_romraider="$check_data_root/romraider-mut2-evo-88780008"
    if [[ -f "$check_evo_romraider/.installed-by-subaru-ecu-tools" && \
          -x "$check_evo_romraider/START_LOGGER_LINUX.sh" && \
          -f "$check_evo_romraider/app/RomRaider-MUT2-88780008-32.jar" ]]; then
        ok "Optional Evo MUT-Raider-II package detected"
    else
        step "Optional Evo MUT-Raider-II package is not installed"
    fi
    check_definition_manifest="$check_data_root/subaru-ecu-tools-linux/definitions-active.conf"
    if [[ -f "$check_definition_manifest" ]]; then
        EDITOR_DEFINITION= LOGGER_DEFINITION=
        while IFS= read -r definition_line; do
            case "$definition_line" in
                EDITOR_DEFINITION=*) EDITOR_DEFINITION=${definition_line#*=} ;;
                LOGGER_DEFINITION=*) LOGGER_DEFINITION=${definition_line#*=} ;;
            esac
        done <"$check_definition_manifest"
        [[ -f "${EDITOR_DEFINITION:-}" ]] && ok "RomRaider Editor definition configured" || \
            warn "MISSING: configured RomRaider Editor definition"
        [[ -f "${LOGGER_DEFINITION:-}" ]] && ok "RomRaider Logger definition configured" || \
            warn "MISSING: configured RomRaider Logger definition"
    else
        warn "NOT INSTALLED: RomRaider Editor/Logger definition selection"
    fi
    if openport_usb_present; then
        ok "Tactrix OpenPort 2.0 detected"
        openport_usb_accessible && \
            ok "Current session has raw read/write OpenPort access" || \
            warn "MISSING: current session cannot read/write the connected OpenPort (desktop uaccess and $openport_group fallback unavailable)"
    else
        step "OpenPort 2.0 is not currently detected; USB access can be validated after connecting it"
    fi
    exit "$checks_failed"
fi

if ((${#missing[@]})) && ! $install_deps; then
    fail "Dependencies are incomplete; no files were installed."
    exit 1
fi
if ((checks_failed)); then
    fail "Build prerequisites are incomplete; no files were installed."
    exit 1
fi

section "Building the OpenPort Wine bridge"
mkdir -p "$cache_root"
bridge_build_log="$cache_root/openport-bridge-build.log"
if "$repo_root/wine-bridge/build-openport-driver.sh" >"$bridge_build_log" 2>&1; then
    ok "OpenPort Wine bridge built and verified."
else
    fail "OpenPort Wine bridge build failed. Diagnostic log: $bridge_build_log"
    tail -50 "$bridge_build_log" >&2 || true
    exit 1
fi

install -d "$bin_dir" "$data_dir/winedll/x86_64-windows" \
    "$data_dir/winedll/x86_64-unix" "$applications_dir"
install_managed_user_files
install -m 0644 "$repo_root/build-wine-bridge/winedll/x86_64-windows/openport.sys" \
    "$data_dir/winedll/x86_64-windows/openport.sys"
install -m 0755 "$repo_root/build-wine-bridge/winedll/x86_64-unix/openport.so" \
    "$data_dir/winedll/x86_64-unix/openport.so"
rm -f -- "$data_dir/winedll/i386-windows/op20pt32.dll" \
    "$data_dir/winedll/i386-windows/j2534.dll" \
    "$data_dir/winedll/x86_64-unix/op20pt32.so" \
    "$data_dir/winedll/x86_64-unix/j2534.so"
install -d "$data_dir/tools"
install -m 0755 "$repo_root/build-wine-bridge/j2534-probe.exe" \
    "$data_dir/tools/j2534-probe.exe"
install -m 0755 "$repo_root/build-wine-bridge/openport-device-probe.exe" \
    "$data_dir/tools/openport-device-probe.exe"


if $install_udev; then
    section "Configuring OpenPort USB permissions"
    if ! getent group "$openport_group" >/dev/null; then
        fail "The required $openport_group device-access group does not exist."
        exit 1
    fi
    udev_rule_rendered="$cache_root/99-openport2-$distro_family.rules"
    sed "s/GROUP=\"uucp\"/GROUP=\"$openport_group\"/" \
        "$repo_root/linux/99-openport2.rules" >"$udev_rule_rendered"
    run_with_music_keys_paused sudo install -m 0644 "$udev_rule_rendered" \
        /etc/udev/rules.d/99-openport2.rules
    run_with_music_keys_paused sudo cmp -s "$udev_rule_rendered" \
        /etc/udev/rules.d/99-openport2.rules || {
        fail "The installed OpenPort udev rule does not match the packaged rule."
        exit 1
    }
    run_with_music_keys_paused sudo usermod -aG "$openport_group" "$USER"
    run_with_music_keys_paused sudo udevadm control --reload-rules
    run_with_music_keys_paused sudo udevadm trigger --subsystem-match=usb
    run_with_music_keys_paused sudo udevadm settle --timeout=10 || {
        fail "udev did not finish applying the OpenPort permission rule."
        exit 1
    }
    ok "Installed and reloaded the OpenPort 2.0 udev permission rule."
    if $setup_interactive; then
        echo "The guided plug/unplug test is recommended, but it can be skipped."
        if read_yes_no "Run the guided OpenPort plug/unplug test now?" yes; then
            verify_openport_hotplug_cycle || exit 1
            if $install_ecuflash; then
                wait_for_openport_state present \
                    "Plug the OpenPort back in for the standalone driver and J2534 communication tests." || exit 1
                verify_openport_usb_access || exit 1
            fi
        else
            warn "Guided OpenPort plug/unplug test skipped by the user."
            if openport_usb_present; then
                wait_for_stable_openport || {
                    fail "The connected OpenPort did not stabilize after applying the udev rule."
                    exit 1
                }
                verify_openport_usb_access || exit 1
            fi
        fi
    elif openport_usb_present; then
        wait_for_stable_openport || {
            fail "The connected OpenPort did not stabilize after applying the udev rule."
            exit 1
        }
        verify_openport_usb_access || exit 1
    else
        echo "Connect the OpenPort to validate live USB permissions; the built-in System Check will verify them."
    fi
    echo "Added $USER to the $openport_group fallback group. A new login activates it for future sessions."
fi

if $install_romraider; then
    section "Installing RomRaider DimeMod Editor and Logger"
    if [[ -f "$romraider_home/RomRaider.jar" && \
          -x "$romraider_home/jre32/bin/java" && \
          -f "$romraider_home/lib/linux/32/j2534.so" && \
          -f "$romraider_home/i18n/com/romraider/logger/ecu/ui/tab/injector/InjectorTabImpl.properties" ]]; then
        ok "A complete RomRaider DimeMod installation is already present; leaving it unchanged."
    else
    romraider_url=https://github.com/Natzirt-BK/subaru-ecu-tools-linux/releases/download/romraider-dimemod-dm20-20250328/RomRaider1.0.0DM20-MAR282025-linux.zip
    romraider_sha256=1f601e03fa75ed64ec895c5460371ab638c004d6fc4a5cf591a1315aa5c161ca
    romraider_archive="$cache_root/RomRaider1.0.0DM20-MAR282025-linux.zip"
    java_url=https://cdn.azul.com/zulu/bin/zulu8.96.0.19-ca-jre8.0.502-linux_i686.zip
    java_sha256=6bff461243958e36151078feb321cf304ecb16e647fa2ab25931c4e1980c6130
    java_archive="$cache_root/zulu8.96.0.19-ca-jre8.0.502-linux_i686.zip"
    java_archive_root=zulu8.96.0.19-ca-jre8.0.502-linux_i686
    mkdir -p "$cache_root"

    if [[ ! -f "$romraider_archive" ]] || \
       ! printf '%s  %s\n' "$romraider_sha256" "$romraider_archive" | sha256sum -c - >/dev/null 2>&1; then
        step "Downloading RomRaider DimeMod DM20 for Linux"
        curl --fail --location --progress-bar \
            --output "$romraider_archive" "$romraider_url"
    fi
    printf '%s  %s\n' "$romraider_sha256" "$romraider_archive" | sha256sum -c -

    if [[ ! -f "$java_archive" ]] || \
       ! printf '%s  %s\n' "$java_sha256" "$java_archive" | sha256sum -c - >/dev/null 2>&1; then
        step "Downloading Azul Zulu Java 8 (32-bit) for the RomRaider Logger"
        curl --fail --location --progress-bar \
            --output "$java_archive" "$java_url"
    fi
    printf '%s  %s\n' "$java_sha256" "$java_archive" | sha256sum -c -

    romraider_stage=$(mktemp -d "$data_root/.romraider-install.XXXXXX")
    unzip -q "$romraider_archive" -d "$romraider_stage"
    unzip -q "$java_archive" -d "$romraider_stage"
    mv -- "$romraider_stage/$java_archive_root" "$romraider_stage/RomRaider/jre32"
    injector_bundle_root="$romraider_stage/RomRaider/i18n/com/romraider/logger/ecu/ui/tab"
    if [[ -d "$injector_bundle_root/Injector" && ! -e "$injector_bundle_root/injector" ]]; then
        mv -- "$injector_bundle_root/Injector" "$injector_bundle_root/injector"
    fi
    if [[ ! -f "$romraider_stage/RomRaider/RomRaider.jar" || \
          ! -x "$romraider_stage/RomRaider/jre32/bin/java" || \
          ! -f "$romraider_stage/RomRaider/lib/linux/32/j2534.so" || \
          ! -f "$romraider_stage/RomRaider/i18n/com/romraider/logger/ecu/ui/tab/injector/InjectorTabImpl.properties" ]]; then
        fail "The verified RomRaider packages did not extract correctly."
        exit 1
    fi
    : >"$romraider_stage/RomRaider/.installed-by-subaru-ecu-tools"
    if [[ -e "$romraider_home" ]]; then
        romraider_backup="${romraider_home}.backup-$(date +%Y%m%d-%H%M%S)"
        warn "Preserving the existing incomplete RomRaider directory at $romraider_backup"
        mv -- "$romraider_home" "$romraider_backup"
    fi
    mv -- "$romraider_stage/RomRaider" "$romraider_home"
    rmdir -- "$romraider_stage"
    ok "RomRaider DimeMod Editor and Logger installed with the required 32-bit Java runtime."
    fi
fi

if $install_definitions; then
    section "Installing RomRaider Editor and Logger definitions"
    definition_args=(
        --source "$definition_source"
        --units "$definition_units"
        --language "$definition_language"
    )
    [[ -z "$vehicle_make" ]] || definition_args+=(--vehicle-make "$vehicle_make")
    [[ -z "$vehicle_year" ]] || definition_args+=(--vehicle-year "$vehicle_year")
    [[ -z "$vehicle_model" ]] || definition_args+=(--vehicle-model "$vehicle_model")
    [[ -z "$custom_editor_definition" ]] || \
        definition_args+=(--custom-editor "$custom_editor_definition")
    [[ -z "$custom_logger_definition" ]] || \
        definition_args+=(--custom-logger "$custom_logger_definition")
    "$bin_dir/install-romraider-definitions" "${definition_args[@]}"
    if [[ "$definition_source" == beta || "$definition_source" == alpha ]]; then
        warn "Experimental $definition_source Editor definitions were selected at the user's discretion."
    fi
fi

if $install_evo_romraider; then
    section "Installing optional Evo MUT-Raider-II"
    "$bin_dir/install-evo-romraider-mut2"
    ok "NatZirt Evo MUT-II Editor and Logger installed separately from DimeMod."
fi

if $install_bergerraider; then
    section "Installing optional BergerRaider foundation preview"
    "$bin_dir/install-bergerraider-preview"
    ok "BergerRaider installed separately from DimeMod and MUT-Raider-II."
fi

if $install_ecuflash; then
    section "Installing and testing the EcuFlash environment"
    ecuflash_url=https://www.tactrix.com/downloads/ecuflash_1444870_win.exe
    ecuflash_sha256=e9242d8882530fc320164f13e4107ceff9c862f5bd2e66debdbebe4895fffa0b
    ecuflash_installer="$cache_root/ecuflash_1444870_win.exe"
    mkdir -p "$cache_root"

    install_ecuflash_runtime

    if [[ ! -f "$ecuflash_installer" ]] || \
       ! printf '%s  %s\n' "$ecuflash_sha256" "$ecuflash_installer" | sha256sum -c - >/dev/null 2>&1; then
        step "Downloading the complete, unmodified EcuFlash 1.44.4870 installer from Tactrix"
        curl --fail --location --progress-bar \
            --output "$ecuflash_installer" "$ecuflash_url"
    fi
    printf '%s  %s\n' "$ecuflash_sha256" "$ecuflash_installer" | sha256sum -c -

    ecuflash_wine="${ECUFLASH_WINE:-$ecuflash_runtime_dir/files/bin/wine}"
    ecuflash_dir="$ecuflash_prefix/drive_c/Program Files (x86)/OpenECU/EcuFlash"
    if [[ ! -f "$ecuflash_dir/ecuflash.exe" ]]; then
        step "Opening Tactrix's installer; review and accept its license"
        ecuflash_install_log="$cache_root/ecuflash-installer.log"
        set +e
        WINEPREFIX="$ecuflash_prefix" WINEDEBUG=-all \
            WINEDLLOVERRIDES="winemenubuilder.exe=d" \
            "$ecuflash_wine" "$ecuflash_installer" >"$ecuflash_install_log" 2>&1
        ecuflash_install_status=$?
        set -e
        if [[ $ecuflash_install_status -ne 0 ]]; then
            fail "The Tactrix installer exited with status $ecuflash_install_status."
            echo "Diagnostic log: $ecuflash_install_log" >&2
            exit 1
        fi
        ok "The Tactrix installer closed normally."
    else
        ok "EcuFlash is already installed in the shared Wine prefix."
    fi

    section "Registering the OpenPort 2.0 Wine bridge"
    ecuflash_driver_dir="$ecuflash_prefix/drive_c/windows/system32/drivers"
    ecuflash_bridge_log="$cache_root/ecuflash-openport-registration.log"
    install -d "$ecuflash_driver_dir"
    install -m 0644 "$data_dir/winedll/x86_64-windows/openport.sys" \
        "$ecuflash_driver_dir/openport.sys"
    install -m 0755 "$data_dir/winedll/x86_64-unix/openport.so" \
        "$ecuflash_driver_dir/openport.so"
    ecuflash_j2534_target="$ecuflash_prefix/drive_c/windows/syswow64/op20pt32.dll"
    ecuflash_j2534_vendor="$ecuflash_dir/drivers/openport 2.0/op20pt32.dll"
    printf '%s  %s\n' "$ecuflash_vendor_j2534_sha256" "$ecuflash_j2534_vendor" | \
        sha256sum -c - >/dev/null 2>&1 || {
        fail "The official Tactrix J2534 DLL is missing or altered."
        exit 1
    }
    install -m 0644 "$ecuflash_j2534_vendor" \
        "$ecuflash_j2534_target"
    if WINEPREFIX="$ecuflash_prefix" WINEDEBUG=-all \
        "$ecuflash_wine" regedit /S "$data_dir/registry/openport2-wine.reg" \
        >"$ecuflash_bridge_log" 2>&1 && \
       WINEPREFIX="$ecuflash_prefix" WINEDEBUG=-all \
        "$ecuflash_wine" regedit /S "$data_dir/registry/openport-driver-wine.reg" \
        >>"$ecuflash_bridge_log" 2>&1 && \
       OPENPORT_REGISTRY_DIR="$data_dir/registry" \
       OPENPORT_STATE_LOG="$ecuflash_bridge_log" \
       ECUFLASH_WINE="$ecuflash_wine" \
       ECUFLASH_WINEPREFIX="$ecuflash_prefix" \
        "$bin_dir/sync-openport-device-state" >/dev/null; then
        bridge_fingerprint=$(sha256sum \
            "$data_dir/winedll/x86_64-windows/openport.sys" \
            "$data_dir/winedll/x86_64-unix/openport.so" \
            "$ecuflash_j2534_vendor" \
            "$data_dir/registry/openport2-wine.reg" \
            "$data_dir/registry/openport-driver-wine.reg" \
            "$data_dir/registry/openport2-device-present.reg" \
            "$data_dir/registry/openport2-device-absent.reg" \
            "$bin_dir/sync-openport-device-state" \
            "$bin_dir/monitor-openport-state" | sha256sum | cut -d' ' -f1)
        printf '%s\n' "$bridge_fingerprint" \
            >"$ecuflash_prefix/.openport-bridge-registered-v3"
        ok "OpenPort driver files and Wine registry entries installed."
    else
        fail "OpenPort Wine bridge registration failed. Diagnostic log: $ecuflash_bridge_log"
        tail -50 "$ecuflash_bridge_log" >&2 || true
        exit 1
    fi

    # Registration can start Wine before the connected-device entry is present.
    # Restart before the standalone driver and J2534 tests.
    stop_wine_prefix "$ecuflash_wine" "$ecuflash_prefix" "$ecuflash_bridge_log"

    # The vendor installer may create generic menu entries that invoke system
    # Wine. They conflict with our tested EcuFlash (Wine) launcher.
    rm -rf -- "$wine_ecuflash_menu_dir"
    command -v update-desktop-database >/dev/null && \
        update-desktop-database "$applications_dir" >/dev/null 2>&1 || true

    if [[ ! -f "$ecuflash_dir/ecuflash.exe" ]]; then
        echo "EcuFlash installation was not completed; setup cannot report success." >&2
        exit 1
    fi

    ecuflash_probe_log="$cache_root/ecuflash-j2534-probe.log"
    probe_args=()
    if openport_usb_present; then
        step "Testing physical OpenPort communication through J2534"
    else
        step "Verifying that the unplugged J2534 bridge reports device-not-connected"
        probe_args=(--expect-absent)
    fi
    : >"$ecuflash_probe_log"
    if ((${#probe_args[@]} == 0)); then
        # Starting the kernel service creates the standalone Wine device link
        # before the official DLL attempts PassThruOpen.
        capture_openport_device_probe "$ecuflash_wine" "$ecuflash_prefix" \
            "$data_dir/winedll" "$data_dir/tools/openport-device-probe.exe" \
            "$ecuflash_probe_log"
    fi
    set +e
    run_with_openport_access env WINEPREFIX="$ecuflash_prefix" \
        WINEDLLPATH="$data_dir/winedll" \
        WINEDEBUG=-all LOG_ENABLE="$state_dir/ecuflash-j2534.log" \
        "$ecuflash_wine" "$data_dir/tools/j2534-probe.exe" "${probe_args[@]}" \
        >>"$ecuflash_probe_log" 2>&1
    ecuflash_probe_status=$?
    set -e
    if ((ecuflash_probe_status)); then
        warn "The first J2534 probe did not complete; restarting Wine and retrying once."
        stop_wine_prefix "$ecuflash_wine" "$ecuflash_prefix" "$ecuflash_probe_log"
        set +e
        run_with_openport_access env WINEPREFIX="$ecuflash_prefix" \
            WINEDLLPATH="$data_dir/winedll" \
            WINEDEBUG=-all LOG_ENABLE="$state_dir/ecuflash-j2534.log" \
            "$ecuflash_wine" "$data_dir/tools/j2534-probe.exe" "${probe_args[@]}" \
            >>"$ecuflash_probe_log" 2>&1
        ecuflash_probe_status=$?
        set -e
    fi
    restore_openport_after_probe "$ecuflash_wine" "$ecuflash_prefix" \
        "$data_dir/registry" "$ecuflash_bridge_log" \
        "$([[ ${#probe_args[@]} -eq 0 ]] && echo true || echo false)"
    if ((ecuflash_probe_status)); then
        capture_verbose_openport_probe "$ecuflash_wine" "$ecuflash_prefix" \
            "$data_dir/winedll" "$data_dir/tools/j2534-probe.exe" \
            "$ecuflash_probe_log" "${probe_args[@]}"
        # Keep the compact binding result after the verbose trace so it
        # survives the bounded tail included in public issue reports.
        capture_openport_device_probe "$ecuflash_wine" "$ecuflash_prefix" \
            "$data_dir/winedll" "$data_dir/tools/openport-device-probe.exe" \
            "$ecuflash_probe_log"
        restore_openport_after_probe "$ecuflash_wine" "$ecuflash_prefix" \
            "$data_dir/registry" "$ecuflash_bridge_log" \
            "$([[ ${#probe_args[@]} -eq 0 ]] && echo true || echo false)"
        fail "The OpenPort J2534 state probe failed with status $ecuflash_probe_status."
        echo "Diagnostic log: $ecuflash_probe_log" >&2
        tail -50 "$ecuflash_probe_log" >&2 || true
        exit 1
    fi
    if ((${#probe_args[@]})); then
        ok "Unplugged OpenPort probe correctly reported device-not-connected."
    else
        ok "Physical OpenPort communication probe passed."

        step "Verifying EcuFlash after the communication probe"
        post_probe_marker=$(mktemp "$cache_root/ecuflash-post-probe.XXXXXX")
        post_probe_log="$cache_root/ecuflash-post-probe-startup.log"
        set +e
        timeout 12s env \
            XDG_DATA_HOME="$data_root" \
            XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}" \
            ECUFLASH_WINE="$ecuflash_wine" \
            ECUFLASH_WINEPREFIX="$ecuflash_prefix" \
            ECUFLASH_TEST_STOP_MARKER="$post_probe_marker" \
            "$bin_dir/launch-ecuflash" >"$post_probe_log" 2>&1
        post_probe_status=$?
        set -e
        stop_wine_prefix "$ecuflash_wine" "$ecuflash_prefix"
        if [[ $post_probe_status -ne 124 ]]; then
            fail "EcuFlash failed its post-probe startup test (status $post_probe_status)."
            echo "Diagnostic log: $post_probe_log" >&2
            exit 1
        fi
        post_probe_ecuflash_log=$(find "$ecuflash_prefix/drive_c/users" -type f \
            -path '*/OpenECU/EcuFlash/logs/*' -newer "$post_probe_marker" \
            -print 2>/dev/null | sed -n '1p' || true)
        rm -f -- "$post_probe_marker"
        if [[ -n "$post_probe_ecuflash_log" ]] && \
           grep -q 'J2534 DLL Version: 1\.02\.4870' "$post_probe_ecuflash_log" && \
           grep -q 'Device Serial Number:' "$post_probe_ecuflash_log"; then
            ok "EcuFlash identified the OpenPort through the official Tactrix J2534 library."
        elif [[ -n "$post_probe_ecuflash_log" ]] && \
             grep -qi 'J2534 error.*no devices available' "$post_probe_ecuflash_log"; then
            fail "EcuFlash could not access the connected OpenPort after validation."
            echo "EcuFlash log: $post_probe_ecuflash_log" >&2
            exit 1
        else
            fail "EcuFlash did not identify the connected OpenPort with the official Tactrix library."
            [[ -n "$post_probe_ecuflash_log" ]] && echo "EcuFlash log: $post_probe_ecuflash_log" >&2
            exit 1
        fi
    fi
fi

if $install_evoscan; then
    section "Installing EvoScan (experimental Linux support)"
    evoscan_wine="${EVOSCAN_WINE:-$ecuflash_runtime_dir/files/bin/wine}"
    evoscan_install_log="$cache_root/evoscan-installer.log"
    step "Opening the purchaser-supplied EvoScan installer"
    set +e
    if [[ "${evoscan_installer,,}" == *.msi ]]; then
        WINEPREFIX="$ecuflash_prefix" WINEDEBUG=-all \
            WINEDLLOVERRIDES="winemenubuilder.exe=d" \
            "$evoscan_wine" msiexec /i "$evoscan_installer" \
            >"$evoscan_install_log" 2>&1
    else
        WINEPREFIX="$ecuflash_prefix" WINEDEBUG=-all \
            WINEDLLOVERRIDES="winemenubuilder.exe=d" \
            "$evoscan_wine" "$evoscan_installer" >"$evoscan_install_log" 2>&1
    fi
    evoscan_install_status=$?
    set -e
    if [[ $evoscan_install_status -ne 0 ]]; then
        fail "The EvoScan installer exited with status $evoscan_install_status."
        echo "Diagnostic log: $evoscan_install_log" >&2
        exit 1
    fi

    evoscan_exe=$(find "$ecuflash_prefix/drive_c" -type f \
        -iname 'EvoScan*.exe' ! -iname '*setup*' ! -iname '*unins*' \
        -printf '%p\n' 2>/dev/null | sort -Vr | sed -n '1p')
    if [[ -z "$evoscan_exe" ]]; then
        fail "EvoScan installation finished, but no EvoScan executable was found."
        echo "Diagnostic log: $evoscan_install_log" >&2
        exit 1
    fi
    printf '%s\n' "$evoscan_exe" >"$data_dir/evoscan-exe.path"

    step "Testing EvoScan startup for 15 seconds; complete activation if prompted"
    evoscan_smoke_log="$cache_root/evoscan-startup.log"
    set +e
    (
        cd "$(dirname -- "$evoscan_exe")" || exit 1
        timeout 15s env WINEPREFIX="$ecuflash_prefix" \
            WINEDLLPATH="$data_dir/winedll" WINEDEBUG=-all \
            "$evoscan_wine" "$evoscan_exe"
    ) >"$evoscan_smoke_log" 2>&1
    evoscan_smoke_status=$?
    set -e
    if [[ $evoscan_smoke_status -ne 124 ]]; then
        fail "EvoScan failed its experimental startup test (status $evoscan_smoke_status)."
        echo "Diagnostic log: $evoscan_smoke_log" >&2
        exit 1
    fi
    ok "EvoScan remained running for the complete experimental startup test."
fi

create_documents_shortcuts
completion_banner
installed_apps=()
[[ -f "$ecuflash_prefix/drive_c/Program Files (x86)/OpenECU/EcuFlash/ecuflash.exe" ]] && \
    installed_apps+=(EcuFlash)
[[ -f "$romraider_home/RomRaider.jar" ]] && \
    installed_apps+=("RomRaider Editor" "RomRaider Logger")
[[ -f "$evo_romraider_home/app/RomRaider-MUT2-88780008-32.jar" ]] && \
    installed_apps+=("MUT-Raider-II Editor" "MUT-Raider-II Logger")
[[ -f "$bergerraider_home/app/BergerRaider-32.jar" ]] && \
    installed_apps+=("BergerRaider Editor" "BergerRaider Logger")
[[ -f "$data_dir/evoscan-exe.path" ]] && installed_apps+=(EvoScan)
if ((${#installed_apps[@]})); then
    printf -v installed_apps_text '%s, ' "${installed_apps[@]}"
    summary_row "Applications" "${installed_apps_text%, }"
fi
summary_row "App menu" "Subaru & Evo ECU Tools"
summary_row "Launchers" "$bin_dir"
summary_row "Wine bridge" "$data_dir/winedll"
summary_row "Desktop files" "$applications_dir"
if ! $install_udev; then
    warn "OpenPort permissions were not changed. Select USB permissions in Setup if needed."
fi
if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
    warn "Add $bin_dir to PATH only when launching tools from a terminal."
fi
if [[ -f "$data_dir/evoscan-exe.path" ]]; then
    warn "EvoScan Linux support remains experimental."
fi
printf '\n'
ok "Open applications from the Subaru & Evo ECU Tools menu."
step "Begin with cable discovery and a supervised read-only ECU test."
