# Disposable CachyOS release test

This directory contains maintainer-only release qualification tooling. It is
not used by the public installer and none of it is copied into a user's
installation.

This VM tests the public installer as an ordinary new user without changing the
known-good host EcuFlash prefix.

## One-time host setup

```bash
./tests/vm/manage-cachyos-vm.sh setup
./tests/vm/manage-cachyos-vm.sh console
```

Complete the normal CachyOS graphical installation. Create an ordinary test
user, update the system, shut it down, and create the reusable baseline:

```bash
./tests/vm/manage-cachyos-vm.sh mark-clean
```

`mark-clean` ejects the installer ISO before creating the snapshot.

The ISO is checksum-pinned to the official CachyOS `260628` desktop release.
The VM uses four virtual CPUs, 8 GiB RAM, a 64 GiB sparse disk, UEFI, and the
existing libvirt `default` network.

## Test a release

Reset the VM, open its desktop, and run the qualification script inside it:

```bash
./tests/vm/manage-cachyos-vm.sh reset
./tests/vm/manage-cachyos-vm.sh console
```

Inside the VM, download only the qualification entry point and run it from
temporary storage:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/Natzirt-BK/subaru-ecu-tools-linux/master/tests/vm/qualify-release.sh \
  -o /tmp/qualify-release.sh
chmod +x /tmp/qualify-release.sh
/tmp/qualify-release.sh
```

The script deliberately clones GitHub into a blank home directory instead of
using host files. Do not clone the repository to
`~/subaru-ecu-tools-release-test` first; that path is the script's clean public
checkout target.

When the script asks for the physical adapter, connect it to the host and run:

```bash
./tests/vm/manage-cachyos-vm.sh attach-usb
```

Run `tests/vm/run-connected-test.sh` inside the public checkout. It launches
EcuFlash for 20 seconds, validates USB discovery and J2534 identity, and then
closes the test session without displaying a false launcher error. It never
reads or writes an ECU.

Return the adapter afterward:

```bash
./tests/vm/manage-cachyos-vm.sh detach-usb
```
