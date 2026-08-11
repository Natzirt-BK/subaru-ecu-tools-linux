# Subaru & Evo ECU Tools for Linux

Run EcuFlash and RomRaider on CachyOS or Arch Linux with a Tactrix OpenPort 2.0.

Created and maintained by **Tristan Bukenberger**.

## Install

Paste this into a terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/Natzirt-BK/subaru-ecu-tools-linux/master/bootstrap-cachyos.sh | bash
```

1. **Install / repair** — normal setup and updates
2. **Clean reinstall** — replace all installer-managed state
3. **System check** — inspect the current installation
4. **Uninstall** — remove installer-managed files

Use **Clean reinstall** when replacing an older or broken setup. ROMs,
definitions, and logs are preserved.

## What gets installed

- EcuFlash 1.44.4870 from Tactrix
- the validated WineGDK 11.1 runtime published with this project
- the official Tactrix OpenPort 2.0 J2534 library
- the Linux OpenPort Wine bridge and USB permissions
- RomRaider DimeMod Editor and Logger with official definitions

Applications appear together under **Subaru & Evo ECU Tools** in the application
menu with short names such as **Setup**, **EcuFlash**, and **RomRaider Logger**.
After installation, **Setup** offers to update the project before showing its
menu; skipping that update is supported but not recommended. Setup prepares the
computer only; it never reads or writes an ECU.

## OpenPort validation

The installer checks the physical USB state. With the cable disconnected, the
J2534 probe must report device-not-connected. With it connected, the probe must
open and close the real adapter. An EcuFlash status-bar label alone is not proof
that the cable is connected.

EcuFlash 1.44 checks the cable when it starts and does not refresh Task Info
after a USB change. The launcher watches the real Linux USB state and shows a
desktop notice when the cable is plugged in or removed. If that happens,
restart EcuFlash before working with an ECU.

`[In Use]` is not automatically an error under Wine. It often means Wine has
the USB device open for EcuFlash. The installer confirms the connection with a
real J2534 open/version/close test.

The packaged runtime is the same WineGDK build used for the successful local
EcuFlash read/write validation. Its release includes licenses, source commits,
patches, package versions, and source checksums.

## If setup fails

Setup saves its output under:

```text
~/.local/state/subaru-ecu-tools-linux/
```

On failure, press `Y` when asked to create a GitHub diagnostic report. The
report includes bounded excerpts from the setup, J2534, EcuFlash, and RomRaider
logs, plus OpenPort-targeted USB descriptors, permissions, udev state, and
recent filtered kernel USB events. It also includes a bounded host/runtime
snapshot that may identify the username, hostname, home paths, local network
addresses, hardware and USB identifiers, adapter serial, groups, and relevant
packages/processes. It does not intentionally collect credentials, tokens, SSH
keys, browser data, or the unfiltered environment. Review it before uploading;
reports are public. If GitHub upload fails, a ready-to-share report is preserved
locally. Reports are assembled below GitHub's issue-body limit; an oversized
report is automatically reduced to bounded first/last excerpts while the
complete version remains local.

Report problems at:
[GitHub Issues](https://github.com/Natzirt-BK/subaru-ecu-tools-linux/issues)

## Safety

Cable detection does not guarantee that an ECU write is safe. Begin with a
supervised read-only test, verify the exact ROM ID and definition, keep a
recovery path, and never interrupt a flash.

EvoScan support is available only through the advanced command line with a
purchaser-supplied installer; it is not part of the recommended setup and Linux
vehicle communication is not validated.

Technical details and advanced commands are in
[LINUX_ECU_TOOLS.md](LINUX_ECU_TOOLS.md). The project is licensed under the
[MIT License](LICENSE).
