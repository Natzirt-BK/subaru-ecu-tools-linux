# Technical reference

The README covers normal setup. This page is for manual commands,
troubleshooting, and maintenance.

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

The udev rule grants OpenPort access through the `uucp` group and the active
desktop seat. During a first install, setup runs its hardware validation through
the newly granted group even though the original terminal has not inherited it
yet. The launchers do the same until the next login refreshes the session.

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

Failure reports include recent setup and application logs, source revision,
checksums, USB/permission details, and a bounded host/runtime snapshot. The
snapshot may identify the username, hostname, home paths, local network
addresses, hardware/USB identifiers, adapter serial, groups, and relevant
packages/processes. It intentionally excludes credentials, tokens, SSH keys,
browser data, and the unfiltered environment. Upload uses the authenticated
GitHub CLI and requires explicit confirmation. If upload fails, the complete
Markdown report remains beside the setup logs. If a report exceeds GitHub's
issue-body limit, setup uploads bounded first/last excerpts and retains the
complete version locally.

Common checks:

```bash
lsusb | grep -i '0403:cc4d'
id -nG | tr ' ' '\n' | grep -x uucp
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

The build requires CachyOS/Arch packages listed by the installer, including
LLVM-MinGW, Wine development files, and libusb development files. Driver design
details are in [wine-bridge/README-linux-driver.md](wine-bridge/README-linux-driver.md).
