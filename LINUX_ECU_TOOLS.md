# Ecu Tools by NatZirt technical reference

The README covers normal setup. This page is for manual commands,
troubleshooting, and maintenance.

## Bootstrap and command line

Download and inspect the bootstrap:

```bash
curl -fL https://raw.githubusercontent.com/Natzirt-BK/subaru-ecu-tools-linux/master/bootstrap-cachyos.sh -o /tmp/bootstrap-cachyos.sh
less /tmp/bootstrap-cachyos.sh
bash /tmp/bootstrap-cachyos.sh
```

For Debian 13 Stable (amd64), substitute `bootstrap-debian.sh`:

```bash
curl -fL https://raw.githubusercontent.com/Natzirt-BK/subaru-ecu-tools-linux/master/bootstrap-debian.sh -o /tmp/bootstrap-debian.sh
less /tmp/bootstrap-debian.sh
bash /tmp/bootstrap-debian.sh
```

Useful direct commands after checkout:

```bash
./linux/install-cachyos.sh --check
./linux/install-cachyos.sh --yes-all
./linux/install-cachyos.sh --clean-install
./linux/update-cachyos.sh
./linux/install-cachyos.sh --uninstall
```

On Debian, use `./linux/install-debian.sh`, `./linux/setup-debian-gui.sh`, and
`./linux/update-debian.sh`. Both distro entry points use the same installation
engine, while the explicit Debian names make manual maintenance unambiguous.

Run `./linux/install-cachyos.sh --help` for advanced component, definition, and
RomRaider2 flags. The bootstrap checkout lives at
`~/.local/src/subaru-ecu-tools-linux` by default.

## Managed locations

| Purpose | Location |
|---|---|
| Project data and Wine runtime | `~/.local/share/subaru-ecu-tools-linux/` |
| EcuFlash Wine prefix | `~/.local/share/ecuflash-proton/` |
| RomRaider DimeMod | `~/.local/share/romraider-dm20/` |
| RomRaider2 1.1 RC | `~/.local/share/romraider2-ecu-studio/` |
| Definitions | `~/.local/share/subaru-evo-ecu-definitions/` |
| Setup logs | `~/.local/state/subaru-ecu-tools-linux/` |
| Download cache | `~/.cache/subaru-ecu-tools-linux/` |

Clean reinstall removes managed applications, runtime, bridge, prefix, and
cache. It preserves ROMs, definitions, logs, and separately installed software.

## EcuFlash and OpenPort

EcuFlash is 32-bit. The setup uses:

- Tactrix EcuFlash 1.44.4870, checksum-pinned
- official Tactrix `op20pt32.dll` version 1.02.4870
- a 64-bit Wine kernel-driver bridge backed by native libusb
- the project’s checksum-pinned WineGDK 11.1 runtime

The launcher synchronizes Wine’s USB registry with physical Linux USB state
before every start. Static registry files never claim the adapter is present.
The OpenPort 2.0 USB identity is `0403:cc4d`.

EcuFlash 1.44 reads its visible cable state at startup and ignores Windows
arrival/removal notifications afterward. The launcher warns when it starts
without a cable. While it runs, a small monitor keeps Wine in sync with Linux
and reports USB changes on the desktop. Restart EcuFlash after plugging or
unplugging the cable. The bridge also drops stale libusb handles before reuse.

Under Wine, `[In Use]` often means Wine has opened the USB device for EcuFlash.
Use the J2534 probe to tell that apart from an access failure.

After EcuFlash startup, setup stops Wine and waits for all prefix services to
exit before probing J2534. A transient probe startup failure is retried once
after another complete Wine restart. Connected testing opens and closes the
physical adapter; disconnected testing requires J2534
`ERR_DEVICE_NOT_CONNECTED`.

The udev rule grants OpenPort access to the active desktop seat through
`uaccess`; membership in `uucp` on Arch or `dialout` on Debian is a fallback.
Setup renders the correct group into the installed rule. Setup and the
launchers test the actual connected USB node before using the fallback group. A
restart is not normally required; reconnecting the adapter applies the rule,
and a logout/login refreshes fallback group membership when needed.

## RomRaider definitions

Recommended setup installs the official RomRaider Editor 0.8.3.1b and Logger
v370 definitions in metric units. Editor selection must be verified by exact ROM
ID, not model year alone.

Community stable, beta, alpha, alternative units, and custom XML imports remain
available through advanced installer flags. Experimental definitions can contain
incorrect addresses; verify them independently.

## RomRaider2 1.1 release candidate

RomRaider2 is a separate Subaru and Lancer Evolution VIII/IX release candidate.
It includes the shared platform selector, independent DimeMod state, current
upstream editor fixes, and a read-only MUT-II logging foundation. Definitions
and vehicle files are intentionally not bundled. Install it directly with:

```bash
./linux/install-cachyos.sh --install-romraider2
```

It uses its own application directory and settings file and does not replace
RomRaider DimeMod. Realtime ECU writes are not enabled.

## Diagnostics

Every run updates:

```text
~/.local/state/subaru-ecu-tools-linux/latest.log
```

Failure reports contain a bounded, filtered installer excerpt and basic
platform information. The filter removes usernames, hostnames, home paths,
email and network addresses, USB serials and topology, and URL queries. Reports
are saved locally and never uploaded automatically. Review a report before
attaching it to a public issue; do not share the unfiltered setup log.

Common checks:

```bash
lsusb | grep -i '0403:cc4d'
id -nG | tr ' ' '\n' | grep -E '^(uucp|dialout)$'
sha256sum ~/.local/share/ecuflash-proton/drive_c/windows/syswow64/op20pt32.dll
```

The bridge log records whether libusb found the physical adapter and whether
opening it succeeded, was denied, or was busy. This distinguishes USB access
problems from Wine registry discovery failures.

Expected official J2534 SHA-256:

```text
f432084801762d919a3c31974616e097562424470003edc4f4fb843df34103cf
```

## Build and test

Build the Wine bridge:

```bash
./wine-bridge/build-openport-driver.sh
```

Run the repository tests:

```bash
for test_script in tests/*.sh; do "$test_script"; done
```

On CachyOS/Arch, the build uses LLVM-MinGW. On Debian it uses the distribution's
`gcc-mingw-w64`, `wine64-tools`, `libwine-dev`, and libusb development packages.
The build script discovers both layouts and reports the selected toolchain with
`./wine-bridge/build-openport-driver.sh --check`.

The repository includes a checksum-pinned Debian 13 Stable GNOME VM workflow:

```bash
./tests/vm/manage-debian-vm.sh setup
./tests/vm/manage-debian-vm.sh wait-ready
./tests/vm/manage-debian-vm.sh test
```

This VM is separate from the CachyOS qualification VM. It compiles every bridge
artifact, runs repository tests, and installs only non-flashing support files.
Driver design details are in
[wine-bridge/README-linux-driver.md](wine-bridge/README-linux-driver.md).
