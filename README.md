# Subaru & Evo ECU Tools for Linux

This enables EcuFlash and RomRaider on CachyOS, Arch Linux, and Debian 13
(amd64) with a Tactrix OpenPort 2.0. The installer configures the host,
checksum-pinned runtime, Wine bridge, launchers, and definitions.

Set up by **Tristan Bukenberger**.

## Install

On CachyOS or Arch Linux, paste this into a terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/Natzirt-BK/subaru-ecu-tools-linux/master/bootstrap-cachyos.sh | bash
```

To install or update only BergerRaider for testing, use:

```bash
curl -fsSL https://raw.githubusercontent.com/Natzirt-BK/subaru-ecu-tools-linux/master/bootstrap-cachyos.sh | bash -s -- --install-bergerraider
```

On Debian 13 Stable (amd64), use:

```bash
curl -fsSL https://raw.githubusercontent.com/Natzirt-BK/subaru-ecu-tools-linux/master/bootstrap-debian.sh | bash
```

For a BergerRaider-only Debian test install, use:

```bash
curl -fsSL https://raw.githubusercontent.com/Natzirt-BK/subaru-ecu-tools-linux/master/bootstrap-debian.sh | bash -s -- --install-bergerraider
```

Debian setup enables the official `i386` multiarch repository support needed
by the bundled 32-bit RomRaider Logger and installs dependencies with APT.

1. **Install / repair** > normal setup and updates
2. **Clean reinstall** > replace all installer-managed state
3. **System check** > inspect the current installation
4. **Uninstall** > remove installer-managed files
5. **BergerRaider 1.1 RC** > install the Java 21 Subaru/Evo studio

Use **Clean reinstall** when replacing an older or broken setup. Your ROMs,
definitions, and logs are preserved.

## What gets installed

- EcuFlash 1.44.4870 from Tactrix (Official)
- the validated WineGDK 11.1 runtime published with this project
- the official Tactrix OpenPort 2.0 J2534 library
- the Linux OpenPort Wine bridge and USB permissions
- RomRaider DimeMod Editor and Logger with official definitions

BergerRaider 1.1 RC adds the shared Subaru/Evo platform, a self-contained Java
21 x64 runtime, versioned settings, read-only Evo MUT-II support, and offline
CSV analysis. Its
OpenPort 2.0 Subaru SSM/ISO9141 path has completed a sustained in-car logging
test. The GitHub project and BergerRaider release are software-only: vehicle
ROMs, definitions, profiles, logs, and owner-specific tuning material are not
included. DimeMod remains the Subaru fallback and EvoScan remains the Evo fallback
until their remaining external-sensor and MUT-II vehicle qualification gates
pass. Guarded realtime write support is not enabled.

All applications appear together under **Subaru & Evo ECU Tools** in your
application menu. On Arch the OpenPort fallback group is `uucp`; on Debian it is
`dialout`. Active desktop sessions normally receive access through `uaccess`.

After installation, **Setup** offers to update the project before showing its
menu. Setup prepares the computer; it never reads or writes to your ECU.

Press **M** in the Setup terminal to mute sound. The bundled track is
checksum-verified and credited in
[`linux/installer-music-CREDITS.md`](linux/installer-music-CREDITS.md).

## OpenPort validation

The installer checks the physical USB state. With the cable disconnected, the
J2534 probe must report device-not-connected. With it connected, the probe must
open and close the real adapter. An EcuFlash status-bar label by itself is not proof
that the cable is connected. The guided plug/unplug test is recommended but can
be skipped if the adapter is unavailable at the time of install.

EcuFlash checks the cable when it starts and does not refresh Task Info
after a USB change. The launcher watches the real Linux USB state and shows a
desktop notice when the cable is plugged in or removed. If the USB state
changes, restart EcuFlash before working with an ECU.

Note: `[In Use]` is not automatically an error under Wine. It often means Wine has
the USB device open for EcuFlash. The installer confirms the connection with a
real J2534 open/version/close test.

The packaged runtime is the same WineGDK build used for successful local
EcuFlash read/write validation. It originated as a Linux gaming compatibility
runtime and proved to be the most reliable tested option. Its release includes
licenses, source commits, patches, package versions, and source checksums.

## If setup fails please report

Setup saves its output under:

```text
~/.local/state/subaru-ecu-tools-linux/
```

On failure, press `Y` when asked to create a GitHub diagnostic report. The
report includes bounded excerpts from the setup, J2534, EcuFlash, and RomRaider
logs, plus OpenPort-targeted USB descriptors, permissions, udev state, and
recent filtered kernel USB events. It also includes a bounded host/runtime
snapshot that may identify your username, hostname, home paths, local network
addresses, hardware and USB identifiers, adapter serial, groups, and relevant
packages/processes. It does not intentionally collect credentials, tokens, SSH
keys, browser data, or the unfiltered environment. Review it before uploading because
reports are public. If GitHub upload fails, a ready-to-share report is preserved
locally. Reports are assembled below GitHub's issue-body limit. An oversized
report is automatically reduced to bounded first/last excerpts while the
complete version remains local.

Report problems at:
[GitHub Issues](https://github.com/Natzirt-BK/subaru-ecu-tools-linux/issues)

## Safety

Cable detection does not necessarily guarantee that an ECU write is safe. Begin with a
write test, verify the exact ROM ID and definition, keep a
recovery path, and never interrupt a flash. The installer and its tests never
read, write, or flash an ECU.

EvoScan support is available only through the advanced command line with a
purchaser-supplied installer. It is not part of the recommended setup, and
Linux vehicle communication remains unvalidated because no reliable hardware
qualification result is available.

Technical details and advanced commands are in
[LINUX_ECU_TOOLS.md](LINUX_ECU_TOOLS.md). The project is licensed under the
[MIT License](LICENSE).
