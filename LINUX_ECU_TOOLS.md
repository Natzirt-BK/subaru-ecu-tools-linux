# Technical reference

The normal installation is intentionally simple. This document covers manual
and advanced operation for maintainers and troubleshooting.

## Bootstrap and command line

Download and inspect the bootstrap:

```bash
curl -fL https://raw.githubusercontent.com/Natzirt-BK/subaru-ecu-tools-linux/master/bootstrap-cachyos.sh -o /tmp/bootstrap-cachyos.sh
less /tmp/bootstrap-cachyos.sh
bash /tmp/bootstrap-cachyos.sh
```

Useful direct commands after checkout:

```bash
./linux/install-cachyos.sh --check
./linux/install-cachyos.sh --yes-all
./linux/install-cachyos.sh --clean-install
./linux/update-cachyos.sh
./linux/install-cachyos.sh --uninstall
```

Run `./linux/install-cachyos.sh --help` for advanced component, definition, and
EvoScan flags. The bootstrap checkout lives at
`~/.local/src/subaru-ecu-tools-linux` by default.

## Managed locations

| Purpose | Location |
|---|---|
| Project data and Wine runtime | `~/.local/share/subaru-ecu-tools-linux/` |
| EcuFlash Wine prefix | `~/.local/share/ecuflash-proton/` |
| RomRaider DimeMod | `~/.local/share/romraider-dm20/` |
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

After EcuFlash startup, setup stops Wine and waits for all prefix services to
exit before probing J2534. A transient probe startup failure is retried once
after another complete Wine restart. Connected testing opens and closes the
physical adapter; disconnected testing requires J2534
`ERR_DEVICE_NOT_CONNECTED`.

The udev rule grants OpenPort access through the `uucp` group. A new group
membership may require logging out and back in.

## RomRaider definitions

Recommended setup installs the official RomRaider Editor 0.8.3.1b and Logger
v370 definitions in metric units. Editor selection must be verified by exact ROM
ID, not model year alone.

Community stable, beta, alpha, alternative units, and custom XML imports remain
available through advanced installer flags. Experimental definitions can contain
incorrect addresses; verify them independently.

## EvoScan

EvoScan is paid software and is never redistributed. Advanced setup can install
a purchaser-supplied EXE or MSI:

```bash
./linux/install-cachyos.sh --evoscan-installer /path/to/installer.exe
```

Startup support is experimental. Vehicle communication on Linux is not
validated.

## Diagnostics

Every run updates:

```text
~/.local/state/subaru-ecu-tools-linux/latest.log
```

Failure reports include recent setup and application logs, source revision, and
checksums for the installed launcher and J2534 DLL. Upload uses the authenticated
GitHub CLI and requires explicit user confirmation. If upload fails, the complete
Markdown report remains beside the setup logs.

Common checks:

```bash
lsusb | grep -i '0403:cc4d'
id -nG | tr ' ' '\n' | grep -x uucp
sha256sum ~/.local/share/ecuflash-proton/drive_c/windows/syswow64/op20pt32.dll
```

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

The build requires CachyOS/Arch packages listed by the installer, including
LLVM-MinGW, Wine development files, and libusb development files. Driver design
details are in [wine-bridge/README-linux-driver.md](wine-bridge/README-linux-driver.md).
