# Subaru & Evo ECU Tools for Linux

This enables EcuFlash and RomRaider on CachyOS or Arch Linux with a Tactrix OpenPort 2.0 without having to manually set everything up. read/write are working.

set up by **Tristan Bukenberger**.

## Install

Paste this into a terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/Natzirt-BK/subaru-ecu-tools-linux/master/bootstrap-cachyos.sh | bash
```

1. **Install / repair** — normal setup and updates
2. **Clean reinstall** — replace all installer-managed state
3. **System check** — inspect the current installation
4. **Uninstall** — remove installer-managed files

Use **Clean reinstall** when replacing an older or broken setup. It will not you own roms, definitions, and logs. they will be preserved.

## What gets installed

- EcuFlash 1.44.4870 from Tactrix
- the validated WineGDK 11.1 runtime published with this project
- the official Tactrix OpenPort 2.0 J2534 library
- the Linux OpenPort Wine bridge and USB permissions
- RomRaider. DimeMod Editor and Logger with official definition

All Applications are installed to appear together under **Subaru & Evo ECU Tools** in your application
menu.

After the installation, **Setup** offers to update the project before showing its
menu to make updating simple. Setup prepares the
computer and it never reads or writes to your ECU.

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
desktop notice when the cable is plugged in or removed. If usb state changes
restart EcuFlash before working with an ECU.

note:`[In Use]` is not automatically an error under Wine. It often means Wine has
the USB device open for EcuFlash. The installer confirms the connection with a
real J2534 open/version/close test.

The packaged runtime is the same WineGDK build used for my successful local
EcuFlash read/write validation. I discovered this build was the closest one available to work. originally it was to get Minecraft bedrock on linux working. Its release includes licenses, source commits,
patches, package versions, and source checksums.

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
locally. Reports are assembled below GitHub's issue-body limit. an oversized
report is automatically reduced to bounded first/last excerpts while the
complete version remains local.

Report problems at:
[GitHub Issues](https://github.com/Natzirt-BK/subaru-ecu-tools-linux/issues)

## Safety

Cable detection does not nessesarily guarantee that an ECU write is safe. Begin with a
write test, verify the exact ROM ID and definition, keep a
recovery path, and never interrupt a flash.

EvoScan support is available only through the advanced command line with a
purchaser-supplied installer; it is not part of the recommended setup and Linux
vehicle communication is not validated as I do not have an Evo, nor do I have Evoscan. I had a tester but they were unreliable and excuse ridden. The only reason it was included was because of this so called tester. I started development to get it working but discontinued my efforts shortly after.

Technical details and advanced commands are in
[LINUX_ECU_TOOLS.md](LINUX_ECU_TOOLS.md). The project is licensed under the
[MIT License](LICENSE).
