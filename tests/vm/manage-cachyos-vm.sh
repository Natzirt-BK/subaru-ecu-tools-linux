#!/usr/bin/env bash
set -euo pipefail

vm_name=${ECU_TEST_VM_NAME:-Subaru-ECU-Tools-Clean}
iso_version=260628
iso_name=cachyos-desktop-linux-${iso_version}.iso
iso_sha256=136c84942eacdc6deed205fe7018c69fe7b70757f2f9b4010936ee05e060f336
iso_url=https://cdn77.cachyos.org/ISO/desktop/${iso_version}/${iso_name}
cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/subaru-ecu-tools-vm
iso_path=$cache_dir/$iso_name
pool_name=images
disk_volume=subaru-ecu-tools-clean.qcow2
iso_volume=$iso_name
snapshot_name=clean-cachyos-user

usage() {
    cat <<EOF
Usage: $0 COMMAND

  setup       Download the verified CachyOS ISO and create the test VM
  console     Open the VM in Virtual Machine Manager
  attach-usb  Pass the connected OpenPort 2.0 into the running VM
  detach-usb  Return the OpenPort 2.0 to the host
  eject-iso   Remove the installer ISO after CachyOS is installed
  mark-clean  Save the installed VM as the clean-user baseline
  reset       Revert the VM to the clean-user baseline
  status      Show VM, snapshot, and OpenPort state

Run setup once, finish the normal CachyOS graphical installation, remove the
installer ISO, create an ordinary test user, and then run mark-clean.
EOF
}

require_host_tools() {
    local tool
    for tool in curl sha256sum virsh virt-install virt-manager; do
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
    vm_exists && { echo "$vm_name already exists."; return; }
    mkdir -p "$cache_dir"
    if [[ ! -f "$iso_path" ]] || \
       ! printf '%s  %s\n' "$iso_sha256" "$iso_path" | sha256sum -c - >/dev/null 2>&1; then
        echo "Downloading the official CachyOS ${iso_version} desktop image..."
        curl --fail --location --continue-at - --output "$iso_path" "$iso_url"
    fi
    printf '%s  %s\n' "$iso_sha256" "$iso_path" | sha256sum -c -
    if ! virsh -c qemu:///system vol-info --pool "$pool_name" "$iso_volume" >/dev/null 2>&1; then
        iso_bytes=$(stat -c %s "$iso_path")
        virsh -c qemu:///system vol-create-as "$pool_name" "$iso_volume" "$iso_bytes" --format raw
        virsh -c qemu:///system vol-upload --pool "$pool_name" "$iso_volume" "$iso_path"
    fi
    if ! virsh -c qemu:///system vol-info --pool "$pool_name" "$disk_volume" >/dev/null 2>&1; then
        virsh -c qemu:///system vol-create-as "$pool_name" "$disk_volume" 64G --format qcow2
    fi
    pool_iso_path=$(virsh -c qemu:///system vol-path --pool "$pool_name" "$iso_volume")
    virt-install --connect qemu:///system \
        --name "$vm_name" \
        --memory 8192 \
        --vcpus 4 \
        --cpu host-passthrough \
        --osinfo linux2024 \
        --machine q35 \
        --boot uefi \
        --disk "vol=$pool_name/$disk_volume,bus=virtio" \
        --cdrom "$pool_iso_path" \
        --network network=default,model=virtio \
        --graphics spice \
        --video virtio \
        --channel spicevmc \
        --noautoconsole
    echo
    echo 'VM created. Run the console command and complete the CachyOS installer.'
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
    echo 'OpenPort 2.0 is attached to the test VM.'
}

detach_usb() {
    local xml
    xml=$(mktemp)
    trap 'rm -f -- "$xml"' RETURN
    write_openport_xml "$xml"
    virsh -c qemu:///system detach-device "$vm_name" "$xml" --live || true
    echo 'OpenPort 2.0 has been returned to the host.'
}

eject_iso() {
    vm_exists || { echo "$vm_name does not exist." >&2; exit 1; }
    local options=(--config)
    [[ "$(virsh -c qemu:///system domstate "$vm_name")" == running ]] && options+=(--live)
    virsh -c qemu:///system change-media "$vm_name" sda --eject "${options[@]}" || true
}

mark_clean() {
    vm_exists || { echo "$vm_name does not exist." >&2; exit 1; }
    [[ "$(virsh -c qemu:///system domstate "$vm_name")" == 'shut off' ]] || {
        echo 'Shut down the VM normally before creating the baseline.' >&2
        exit 1
    }
    eject_iso
    virsh -c qemu:///system snapshot-create-as "$vm_name" "$snapshot_name" \
        'Fresh CachyOS ordinary user before Subaru ECU Tools installation'
}

reset_vm() {
    vm_exists || { echo "$vm_name does not exist." >&2; exit 1; }
    if [[ "$(virsh -c qemu:///system domstate "$vm_name")" != 'shut off' ]]; then
        virsh -c qemu:///system shutdown "$vm_name"
        for _ in {1..30}; do
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
    virsh -c qemu:///system dominfo "$vm_name" 2>/dev/null || echo 'VM: not created'
    echo
    virsh -c qemu:///system snapshot-list "$vm_name" 2>/dev/null || true
    echo
    lsusb -d 0403:cc4d 2>/dev/null || echo 'OpenPort: not visible on host'
}

require_host_tools
case ${1:-} in
    setup) setup_vm ;;
    console) vm_exists || { echo "$vm_name does not exist." >&2; exit 1; }; virt-manager --connect qemu:///system --show-domain-console "$vm_name" >/dev/null 2>&1 & ;;
    attach-usb) attach_usb ;;
    detach-usb) detach_usb ;;
    eject-iso) eject_iso ;;
    mark-clean) mark_clean ;;
    reset) reset_vm ;;
    status) show_status ;;
    *) usage; exit 2 ;;
esac
