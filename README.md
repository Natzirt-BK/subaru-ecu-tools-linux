# Subaru & Evo ECU Tools for Linux

Run EcuFlash and RomRaider on CachyOS or Arch Linux with a Tactrix OpenPort 2.0.

Created and maintained by **Tristan Bukenberger**.

## Install

Paste this into a terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/Natzirt-BK/subaru-ecu-tools-linux/master/bootstrap-cachyos.sh | bash
```

The installer responds to one keypress; Enter is not required for menu choices
or Y/N questions.

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
menu. Setup prepares the computer only; it never reads or writes an ECU.

## OpenPort validation

The installer checks the physical USB state. With the cable disconnected, the
J2534 probe must report device-not-connected. With it connected, the probe must
open and close the real adapter. An EcuFlash status-bar label alone is not proof
that the cable is connected.

EcuFlash 1.44 does not refresh its visible Task Info after USB hot-plug events.
The launcher therefore warns before starting it unplugged and monitors the real
Linux USB state while it runs. Plug/unplug changes produce immediate desktop
notifications. Start EcuFlash with the cable connected before ECU work. Its
`[In Use]` label can mean Wine’s PnP driver owns USB on EcuFlash’s behalf; the
installer’s J2534 open/version/close probe is the reliable health check.

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
logs. Review it before uploading; reports are public. If GitHub upload fails, a
ready-to-share report is preserved locally.

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
