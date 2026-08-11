# Disposable CachyOS release test

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

Copy or type the public repository URL in the VM, then run
`tests/vm/qualify-release.sh`. It deliberately clones GitHub into a blank home
directory instead of using host files.

When the script asks for the physical adapter, connect it to the host and run:

```bash
./tests/vm/manage-cachyos-vm.sh attach-usb
```

Run `tests/vm/verify-installed.sh` inside the VM after EcuFlash has started with
the adapter. This validates USB discovery and J2534 identity only. It never
reads or writes an ECU.

Return the adapter afterward:

```bash
./tests/vm/manage-cachyos-vm.sh detach-usb
```
