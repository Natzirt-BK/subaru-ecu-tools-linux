#!/usr/bin/env bash
set -euo pipefail

vm_name=${ECU_DEBIAN_TEST_VM_NAME:-Subaru-ECU-Tools-Debian-13}
image_build=20260810-2566
image_name=debian-13-genericcloud-amd64-${image_build}.qcow2
image_url=https://cloud.debian.org/images/cloud/trixie/${image_build}/${image_name}
image_sha512=0ce1f1d675733027d3e17a4665cb95e1d7173bdf67fb8a87ff822ff5ee025bc2a90ecb270465ef395755e41c868b40072eb9ac493810196d9cf68f941afb93dc
cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/subaru-ecu-tools-vm
image_path=$cache_dir/$image_name
ssh_key=$cache_dir/debian-test-ed25519
ssh_known_hosts=$cache_dir/debian-test-known-hosts
pool_name=images
disk_volume=subaru-ecu-tools-debian-13.qcow2
snapshot_name=clean-debian-13-gnome
vm_user=ecutest
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)

usage() {
    cat <<EOF
Usage: $0 COMMAND

  setup       Download verified Debian 13 and create the GNOME test VM
  wait-ready  Wait for cloud-init and the GNOME installation to finish
  test        Copy this checkout into the VM and run Debian qualification
  console     Open the VM in Virtual Machine Manager
  attach-usb  Pass the connected OpenPort 2.0 into the running VM
  detach-usb  Return the OpenPort 2.0 to the host
  mark-clean  Save the configured VM as the clean Debian baseline
  reset       Revert the VM to the clean Debian baseline
  status      Show VM, snapshot, network, cloud-init, and OpenPort state

The VM is created from Debian's checksum-pinned official Debian 13 Stable
generic cloud image. Cloud-init adds GNOME Core, GDM, Spice integration, and an
ordinary passwordless-sudo test user authenticated only by a local SSH key.
EOF
}

require_host_tools() {
    local tool
    for tool in curl sha512sum ssh ssh-keygen tar virsh virt-install virt-manager qemu-img; do
        command -v "$tool" >/dev/null || {
            echo "Missing required host tool: $tool" >&2
            exit 1
        }
    done
    [[ -e /dev/kvm ]] || { echo 'KVM is not available on this host.' >&2; exit 1; }
    virsh -c qemu:///system list >/dev/null
}

vm_exists() {
    virsh -c qemu:///system dominfo "$vm_name" >/dev/null 2>&1
}

vm_ip() {
    local ip

    # Managed-save restores can briefly leave an older DHCP lease beside the
    # guest's current address. Prefer what the guest agent reports, then fall
    # back to the newest address shown by libvirt's lease source.
    ip=$(virsh -c qemu:///system domifaddr "$vm_name" --source agent 2>/dev/null | \
        awk '$3 == "ipv4" && $1 != "lo" {sub(/\/.*/, "", $4); print $4; exit}')
    if [[ -n "$ip" ]]; then
        printf '%s\n' "$ip"
        return 0
    fi
    virsh -c qemu:///system domifaddr "$vm_name" --source lease 2>/dev/null | \
        awk '$3 == "ipv4" {sub(/\/.*/, "", $4); ip=$4} END {if (ip != "") print ip}'
}

wait_for_ssh() {
    local ip attempt
    for attempt in {1..120}; do
        ip=$(vm_ip || true)
        if [[ -n "$ip" ]] && ssh -i "$ssh_key" \
            -o UserKnownHostsFile="$ssh_known_hosts" \
            -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new \
            "$vm_user@$ip" true 2>/dev/null; then
            printf '%s\n' "$ip"
            return 0
        fi
        sleep 5
    done
    echo 'Debian VM did not become reachable by SSH within 10 minutes.' >&2
    return 1
}

write_openport_xml() {
    local target=$1
    printf '%s\n' \
        '<hostdev mode="subsystem" type="usb" managed="yes">' \
        '  <source>' \
        '    <vendor id="0x0403"/>' \
        '    <product id="0xcc4d"/>' \
        '  </source>' \
        '</hostdev>' >"$target"
}

setup_vm() {
    local prepared_image user_data meta_data public_key
    vm_exists && { echo "$vm_name already exists."; return; }
    mkdir -p "$cache_dir"
    rm -f -- "$ssh_known_hosts"
    if [[ ! -f "$image_path" ]] || \
       ! printf '%s  %s\n' "$image_sha512" "$image_path" | sha512sum -c - >/dev/null 2>&1; then
        echo "Downloading official Debian 13 Stable image build $image_build..."
        curl --fail --location --continue-at - --output "$image_path" "$image_url"
    fi
    printf '%s  %s\n' "$image_sha512" "$image_path" | sha512sum -c -
    if [[ ! -f "$ssh_key" ]]; then
        ssh-keygen -q -t ed25519 -N '' -C subaru-ecu-tools-debian-vm -f "$ssh_key"
    fi
    public_key=$(<"$ssh_key.pub")

    prepared_image=$cache_dir/$disk_volume
    qemu-img convert -p -O qcow2 "$image_path" "$prepared_image"
    qemu-img resize "$prepared_image" 64G
    if virsh -c qemu:///system vol-info --pool "$pool_name" "$disk_volume" >/dev/null 2>&1; then
        echo "Refusing to overwrite existing libvirt volume: $disk_volume" >&2
        exit 1
    fi
    virsh -c qemu:///system vol-create-as "$pool_name" "$disk_volume" 64G --format qcow2
    virsh -c qemu:///system vol-upload --pool "$pool_name" "$disk_volume" "$prepared_image"
    rm -f -- "$prepared_image"

    user_data=$(mktemp "$cache_dir/debian-user-data.XXXXXX")
    meta_data=$(mktemp "$cache_dir/debian-meta-data.XXXXXX")
    trap 'rm -f -- "$user_data" "$meta_data"' RETURN
    {
        printf '%s\n' '#cloud-config'
        printf '%s\n' 'hostname: subaru-ecu-tools-debian'
        printf '%s\n' 'manage_etc_hosts: true'
        printf '%s\n' 'users:'
        printf '%s\n' "  - name: $vm_user"
        printf '%s\n' '    gecos: Subaru ECU Tools Test User'
        printf '%s\n' '    groups: [sudo, dialout]'
        printf '%s\n' '    shell: /bin/bash'
        printf '%s\n' '    sudo: ALL=(ALL) NOPASSWD:ALL'
        printf '%s\n' '    lock_passwd: true'
        printf '%s\n' '    ssh_authorized_keys:'
        printf '      - %s\n' "$public_key"
        printf '%s\n' 'package_update: true'
        printf '%s\n' 'package_upgrade: true'
        printf '%s\n' 'packages:'
        printf '%s\n' '  - gnome-core' '  - gdm3' '  - spice-vdagent' \
            '  - qemu-guest-agent' '  - linux-image-amd64' \
            '  - git' '  - curl' '  - ca-certificates'
        printf '%s\n' 'runcmd:'
        printf '%s\n' '  - |'
        printf '%s\n' \
            '    standard_kernel=$(dpkg-query -W -f="\${Depends}" linux-image-amd64 | sed -E "s/^linux-image-([^ ]+).*/\1/")' \
            '    printf '\''GRUB_DEFAULT="Advanced options for Debian GNU/Linux>Debian GNU/Linux, with Linux %s"\n'\'' "$standard_kernel" > /etc/default/grub.d/99-subaru-test-input.cfg' \
            '    update-grub'
        printf '%s\n' '  - [netplan, set, --origin-hint, 99-gnome-network, renderer=NetworkManager]'
        printf '%s\n' '  - [netplan, apply]'
        printf '%s\n' '  - [systemctl, set-default, graphical.target]'
        printf '%s\n' '  - [systemctl, enable, --now, qemu-guest-agent.service]'
        printf '%s\n' '  - [systemctl, enable, --now, gdm3.service]'
        printf '%s\n' 'power_state:' '  mode: reboot' '  timeout: 1800' \
            '  condition: true'
    } >"$user_data"
    printf 'instance-id: %s\nlocal-hostname: subaru-ecu-tools-debian\n' \
        "$vm_name-$image_build" >"$meta_data"

    virt-install --connect qemu:///system \
        --name "$vm_name" \
        --memory 8192 \
        --vcpus 4 \
        --cpu host-passthrough \
        --osinfo debian13 \
        --machine q35 \
        --boot uefi \
        --import \
        --disk "vol=$pool_name/$disk_volume,bus=virtio" \
        --network network=default,model=virtio \
        --graphics spice \
        --video virtio \
        --channel spicevmc \
        --cloud-init "user-data=$user_data,meta-data=$meta_data,disable=on" \
        --noautoconsole
    echo "Debian VM created. Run '$0 wait-ready' to follow GNOME provisioning."
}

wait_ready() {
    local ip
    vm_exists || { echo "$vm_name does not exist." >&2; exit 1; }
    [[ "$(virsh -c qemu:///system domstate "$vm_name")" == running ]] || \
        virsh -c qemu:///system start "$vm_name"
    ip=$(wait_for_ssh)
    echo "Debian VM reachable at $ip; waiting for cloud-init..."
    ssh -i "$ssh_key" -o UserKnownHostsFile="$ssh_known_hosts" \
        -o StrictHostKeyChecking=accept-new "$vm_user@$ip" \
        'cloud-init status --wait --long; systemctl is-active gdm3 qemu-guest-agent; cat /etc/debian_version'
}

test_vm() {
    local ip remote_root
    wait_ready
    ip=$(vm_ip)
    remote_root=/home/$vm_user/subaru-ecu-tools-linux-under-test
    tar --exclude=.git --exclude=build-wine-bridge -C "$repo_root" -cf - . | \
        ssh -i "$ssh_key" -o UserKnownHostsFile="$ssh_known_hosts" \
        -o StrictHostKeyChecking=accept-new "$vm_user@$ip" \
        "rm -rf '$remote_root' && mkdir -p '$remote_root' && tar -xf - -C '$remote_root'"
    ssh -T -i "$ssh_key" -o UserKnownHostsFile="$ssh_known_hosts" \
        -o StrictHostKeyChecking=accept-new "$vm_user@$ip" \
        "cd '$remote_root' && ./tests/vm/qualify-debian.sh"
}

attach_usb() {
    local xml
    vm_exists || { echo "$vm_name does not exist." >&2; exit 1; }
    lsusb -d 0403:cc4d >/dev/null 2>&1 || {
        echo 'OpenPort 2.0 is not connected to the host.' >&2
        exit 1
    }
    [[ "$(virsh -c qemu:///system domstate "$vm_name")" == running ]] || {
        echo "$vm_name must be running before USB attachment." >&2
        exit 1
    }
    xml=$(mktemp)
    trap 'rm -f -- "$xml"' RETURN
    write_openport_xml "$xml"
    virsh -c qemu:///system attach-device "$vm_name" "$xml" --live
}

detach_usb() {
    local xml
    vm_exists || { echo "$vm_name does not exist." >&2; exit 1; }
    [[ "$(virsh -c qemu:///system domstate "$vm_name")" == running ]] || return 0
    xml=$(mktemp)
    trap 'rm -f -- "$xml"' RETURN
    write_openport_xml "$xml"
    virsh -c qemu:///system detach-device "$vm_name" "$xml" --live || true
}

mark_clean() {
    vm_exists || { echo "$vm_name does not exist." >&2; exit 1; }
    [[ "$(virsh -c qemu:///system domstate "$vm_name")" == 'shut off' ]] || {
        echo 'Shut down the VM normally before creating the baseline.' >&2
        exit 1
    }
    virsh -c qemu:///system snapshot-create-as "$vm_name" "$snapshot_name" \
        'Fresh Debian 13 Stable GNOME test user before ECU Tools installation'
}

reset_vm() {
    vm_exists || { echo "$vm_name does not exist." >&2; exit 1; }
    if [[ "$(virsh -c qemu:///system domstate "$vm_name")" != 'shut off' ]]; then
        virsh -c qemu:///system shutdown "$vm_name"
        for _ in {1..60}; do
            [[ "$(virsh -c qemu:///system domstate "$vm_name")" == 'shut off' ]] && break
            sleep 1
        done
    fi
    [[ "$(virsh -c qemu:///system domstate "$vm_name")" == 'shut off' ]] || {
        echo 'The VM did not shut down; no snapshot was reverted.' >&2
        exit 1
    }
    virsh -c qemu:///system snapshot-revert "$vm_name" "$snapshot_name"
    virsh -c qemu:///system start "$vm_name"
}

show_status() {
    virsh -c qemu:///system dominfo "$vm_name" 2>/dev/null || { echo 'VM: not created'; return; }
    echo
    virsh -c qemu:///system snapshot-list "$vm_name" 2>/dev/null || true
    echo
    virsh -c qemu:///system domifaddr "$vm_name" --source lease 2>/dev/null || true
    echo
    lsusb -d 0403:cc4d 2>/dev/null || echo 'OpenPort: not visible on host'
}

require_host_tools
case ${1:-} in
    setup) setup_vm ;;
    wait-ready) wait_ready ;;
    test) test_vm ;;
    console) vm_exists || { echo "$vm_name does not exist." >&2; exit 1; }; virt-manager --connect qemu:///system --show-domain-console "$vm_name" >/dev/null 2>&1 & ;;
    attach-usb) attach_usb ;;
    detach-usb) detach_usb ;;
    mark-clean) mark_clean ;;
    reset) reset_vm ;;
    status) show_status ;;
    *) usage; exit 2 ;;
esac
