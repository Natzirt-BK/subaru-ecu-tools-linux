# Ecu Tools by NatZirt

ECU editing, logging, and diagnostic software for Linux through one supported setup. It
installs the applications, compatibility runtime, OpenPort 2.0 support,
definitions, USB permissions, and desktop launchers that users would otherwise
have to assemble manually unnecessarily.

The project also distributes **[RomRaider2](https://github.com/Natzirt-BK/RomRaider2)**,
a much-needed modernization of RomRaider that preserves useful work from the
DimeMod fork while adding a new interface, current runtime, safer diagnostics,
improved logging, and Mitsubishi Lancer Evolution support.

Maintained by **NatZirt**. This is an independent community
project and is not affiliated with Tactrix, Subaru, Mitsubishi, or the official
RomRaider project.

## Downloads and installation

Windows 10/11 x64 users can download the self-contained RomRaider2 portable ZIP
from the [current release page](https://github.com/Natzirt-BK/RomRaider2/releases/tag/romraider2-1.1.12).
Java 21 is included; extract the ZIP and launch `RomRaider2.exe` or
`RomRaider2 Logger.exe`.

On CachyOS or Arch Linux, paste this command into a terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/Natzirt-BK/subaru-ecu-tools-linux/master/bootstrap-cachyos.sh | bash
```

On Debian 13 Stable x64, use:

```bash
curl -fsSL https://raw.githubusercontent.com/Natzirt-BK/subaru-ecu-tools-linux/master/bootstrap-debian.sh | bash
```

The Setup menu provides:

1. **Install / repair** — EcuFlash, the validated Linux OpenPort stack,
   RomRaider DimeMod, definitions, dependencies, USB access, and launchers.
2. **Clean reinstall** — rebuild installer-managed software while preserving
   ROMs, definitions, and logs.
3. **System check** — verify applications, dependencies, J2534, and OpenPort USB
   access without installing anything.
4. **Uninstall** — remove installer-managed software.
5. **RomRaider2 1.1.12** — install or update RomRaider2 separately.

Installer music starts with the setup menu and continues across install runs.
Press **M** to mute it. Completion screens use **B** to return to the main menu,
and the menu redraw restores the same terminal colors and formatting.
Music stops when setup exits or its terminal closes, including while an
installer prompt has temporarily taken over keyboard input.

To install only RomRaider2 on CachyOS or Arch Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/Natzirt-BK/subaru-ecu-tools-linux/master/bootstrap-cachyos.sh | bash -s -- --install-romraider2
```

On Debian 13 Stable x64:

```bash
curl -fsSL https://raw.githubusercontent.com/Natzirt-BK/subaru-ecu-tools-linux/master/bootstrap-debian.sh | bash -s -- --install-romraider2
```

## Linux software stack

### RomRaider2 update preservation

RomRaider2 updates migrate the complete `config/user` tree (including managed
definitions, profiles and recovery), plus top-level `definitions`, `profiles`,
`logs`, `roms` and `repositories`. Existing settings are retained byte-for-byte;
new application binaries, drivers and defaults are not replaced with old ones.

The current installation is backed up beside itself before activation. If
activation fails, the installer attempts to restore it automatically and reports
the backup location if restoration also fails. Legacy installations are retained
unchanged, including custom files outside the migrated paths. They are not
deleted automatically, so absolute references into them continue to work.
Verify your setup and backups before manually removing any predecessor.

An existing current installation takes priority over legacy copies; older files
are not merged back into it. Symlinked migration roots/settings require manual
migration and stop the update without removing the original. Nested data links
are copied as links, not followed. These repairs cannot recreate files already
deleted by an older installer without another backup.

### Included components

The recommended installation includes:

- Tactrix EcuFlash 1.44.4870.
- The official Tactrix OpenPort 2.0 J2534 library.
- A Linux OpenPort Wine bridge and distribution-specific USB permissions.
- A checksum-pinned WineGDK 11.1 runtime validated with EcuFlash.
- RomRaider DimeMod Editor and Logger with current public definitions.
- Application-menu entries and launchers under **ECU Tools**.

The large Wine dependency is maintained in the
[validated EcuFlash runtime release](https://github.com/Natzirt-BK/subaru-ecu-tools-linux/releases/tag/ecuflash-winegdk-11.1-validated-1)
and is downloaded automatically. The installer also obtains the official
EcuFlash installer from Tactrix, builds the OpenPort bridge, and validates the
completed stack.

## EcuFlash on Linux

EcuFlash is a supported part of this installer.
This setup:

- installs the official EcuFlash 1.44.4870 package and Tactrix
  32-bit OpenPort 2.0 J2534 library
- supplies a 64-bit Wine-to-libusb bridge so the 32-bit application can reach
  the physical adapter
- installs distribution-aware USB permissions and verifies the actual device
  node
- synchronizes Wine's device state before EcuFlash starts and reports later
  cable changes
- verifies bridge registration, disconnected behavior, and live adapter access
- keeps the WineGDK runtime checksum-pinned and separate from the user's normal
  Wine configuration.

This stack has completed live OpenPort discovery and ECU read/write validation
on Linux. EcuFlash still reads cable state at startup, so restart it after
plugging or unplugging the OpenPort.

## What RomRaider2 adds

- A modern workspace with favorites, recent and changed-map
  navigation, tab order, and recents.
- Fast table filtering and search across maps, logger parameters, DTCs,
  settings, and commands.
- ROM comparison, grouped undo/redo, selected-cell revert, change summaries,
  notes, and integrity-checked crash-recovery snapshots.
- 3D map surface integration with the active table.
- Integrated live-data cards, traces, and a datalog workspace driven by
  logger samples.
- RomRaider CSV analysis with linked tables, graphs, statistics, range
  selection, and playback speed adjustability.
- Light & dark, system themes with customizable interface
  scaling and multiple display modes including touch-mode to prevent fat-finger button pressing.
- Integrated window controls and resizing.
- Multi-vehicle platform model with a
  read-only MUT-II logging foundation.
- Versioned settings, diagnostics, and self-contained Java 21 x64
  packages for Linux and Windows.

## What RomRaider2 fixes

- OpenPort/J2534 reception waits for complete messages and resynchronizes when
  Subaru SSM queries change, preventing logging gaps.
- J2534 logging no longer shows an irrelevant serial COM-port selector.
- External serial sensors validate their configuration and reconnect after a
  port change (unsupported Windows-only plugins are hidden on Linux.)
- Missing-definition guidance opens the current SubaruDefs project instead of
  sending users to an outdated forum download.
- Missing Logger definitions now use one prompt with clear choices.
- Error dialogs no longer expose raw exception details.
- End-of-life Java and logging components were replaced with Java 21,
  JNA, jSerialComm, and Log4j dependencies.

## Definitions and vehicle files

The Linux installer can download current public
RomRaider definitions for chosen vehicle options, however this is currently disabled.

## Validation status

- EcuFlash 1.44 and the packaged Linux OpenPort/Wine stack have passed live
  adapter discovery and ECU read/write validation.
- RomRaider2 has completed OpenPort/J2534 Subaru ECU identification and sustained
  in-car SSM/ISO9141 logging.
- Mitsubishi MUT-II logging passed validation.
- The Windows package passes build and hardware testing.
- Does not enable ECU memory writing or flashing. The code is removed and remains local currently
  EcuFlash remains the flashing application in the Linux toolset.

## OpenPort behavior on Linux

The installer checks the USB state.
When connected, the J2534 probe opens and closes the adapter. When disconnected,
it must report device not connected. The EcuFlash launcher synchronizes Wine's
device state before startup and reports later USB changes. 

**Restart EcuFlash after plugging or unplugging the cable.**

The J2534 probe distinguishes states from
missing or denied USB access.

## Diagnostic reports

Setup logs are stored under:

```text
~/.local/state/subaru-ecu-tools-linux/
```

Press **R** after a problem to create a filtered local report. Review the report before attaching it to a
[GitHub issue](https://github.com/Natzirt-BK/subaru-ecu-tools-linux/issues).
Do not publish the raw setup log without reviewing it.

## Safety

Begin with a
supervised read-only connection and logging test, verify the exact ROM and
definition, maintain a recovery path, and never interrupt a flash.

Advanced commands and implementation details are in the
[technical reference](LINUX_ECU_TOOLS.md). The installer project is available
under the [MIT License](LICENSE); bundled and downloaded applications retain
their own licenses and attribution.
