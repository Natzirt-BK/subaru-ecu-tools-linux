# Subaru tuning tools on Linux

I put this project together after getting my Subaru tuning setup working on
CachyOS. My setup uses the DimeMod version of RomRaider, EcuFlash, and a
Tactrix OpenPort 2.0 cable.

RomRaider Editor and Logger now run on my Linux machine, and EcuFlash can find
and communicate with the OpenPort cable through Wine. I am also working on
getting EvoScan running, but that part is not ready yet.

## What is here

- An experimental Wine driver for EcuFlash and the OpenPort 2.0
- Launch scripts for EcuFlash, RomRaider Editor, and RomRaider Logger
- A CachyOS/Arch installer that checks dependencies and installs the Linux-side
  pieces
- A udev rule for OpenPort cable access
- Notes about the USB and Wine issues that had to be solved

This repository does **not** commit EcuFlash, RomRaider, the DimeMod package,
ECU definitions, ROM files, logs, or Tactrix firmware. You need to get those
from their original sources. The installer can download EcuFlash directly from
Tactrix for you.

## CachyOS quick start

For a native setup, download the small bootstrap, inspect it, and run the
read-only check:

```bash
curl -fL https://raw.githubusercontent.com/Natzirt-BK/subaru-ecu-tools-linux/master/bootstrap-cachyos.sh -o /tmp/bootstrap-cachyos.sh
less /tmp/bootstrap-cachyos.sh
bash /tmp/bootstrap-cachyos.sh --check
```

If the check looks good, this installs the dependencies, udev rule, Wine bridge,
launchers, and official EcuFlash download:

```bash
bash /tmp/bootstrap-cachyos.sh --install-deps --install-udev --install-ecuflash
```

The shorter paste-and-run form is:

```bash
curl -fsSL https://raw.githubusercontent.com/Natzirt-BK/subaru-ecu-tools-linux/master/bootstrap-cachyos.sh | bash -s -- --install-deps --install-udev --install-ecuflash
```

The first method is recommended because it lets you read the script before it
runs. The bootstrap keeps its checkout in
`$HOME/.local/src/subaru-ecu-tools-linux` and updates it safely when run again.

### Graphical setup

CachyOS KDE users can open a KDialog setup wizard from Konsole:

```bash
curl -fsSL https://raw.githubusercontent.com/Natzirt-BK/subaru-ecu-tools-linux/master/bootstrap-cachyos.sh | bash -s -- --gui
```

The wizard asks which pieces to install, then opens Konsole so progress and any
`sudo` prompt stay visible. It never communicates with an ECU. After the first
installation, **Subaru ECU Tools Setup** is also available in the application
menu. Choose **Install everything (yes to all)** for the complete setup, or
**Remove Subaru ECU Tools** for guided cleanup.

If dependencies or the OpenPort udev rule are missing, the installer can handle
those too. It can also download the complete official EcuFlash installer from
Tactrix and open it through Wine. The dependency and udev options use `sudo`
because they change system packages or USB permissions:

```bash
./linux/install-cachyos.sh --install-deps --install-udev --install-ecuflash
```

The EcuFlash download is the unmodified Tactrix 1.44.4870 distribution and is
pinned by checksum. After installation, setup opens EcuFlash for a 12-second
startup test and reports success only if it stays running. Its own installer
shows the Tactrix license. Setup also downloads a checksum-pinned Wine 11.1
runtime tested specifically with EcuFlash; it does not replace system Wine.
`ECUFLASH_WINE` can select a different runner explicitly.
The exact runtime build recipe is in `linux/build-ecuflash-wine-runtime.sh`.
After installation, launch **EcuFlash (Wine)** from the application menu. Setup
removes the vendor-generated generic **EcuFlash** shortcut because it invokes
system Wine instead of the tested private runtime.

DimeMod RomRaider must still be obtained separately. Extract its complete Linux
package, including `jre32`, to `$HOME/.local/share/romraider-dm20`. The installed
Editor and Logger shortcuts then reproduce the validated launch configuration;
the Logger uses the `uucp` device-access group. Locations can be overridden with
`ECUFLASH_WINEPREFIX`, `ECUFLASH_WINE`, and `ROMRAIDER_HOME`.

More detailed setup and troubleshooting notes are in
[LINUX_ECU_TOOLS.md](LINUX_ECU_TOOLS.md).

To remove the installed launchers, bridge, EcuFlash prefix, cache, desktop
entries, USB rule, and default source checkout from a terminal:

```bash
bash ~/.local/src/subaru-ecu-tools-linux/linux/install-cachyos.sh --uninstall
```

The uninstaller preserves separately obtained RomRaider files, ROMs,
definitions, logs, and shared system packages.

Every check and installation writes a timestamped diagnostic log under
`$HOME/.local/state/subaru-ecu-tools-linux`; `latest.log` always points to the
newest run. When setup fails, share that log with the error report. Uninstall
removes the saved logs and writes its final cleanup log under `/tmp`.
Interactive terminals use colored progress and status messages while saved
logs remain plain text. Set `NO_COLOR=1` to disable terminal colors.

After a failed run, setup asks whether to upload the log to this repository as
a public GitHub issue. Automatic upload requires the `github-cli` package and
a prior `gh auth login`; setup never asks for or stores a GitHub token. The user
must confirm each upload, and declining keeps the log local.
The `--install-deps` and “install everything” paths install `github-cli`, but
GitHub authentication remains an explicit user action.

## A serious safety note

The cable is detected and communicates successfully on my computer, but that
does not guarantee safe ECU writing on every vehicle or Linux setup. Start with
cable detection, then perform a supervised read-only test. Keep a known-good
recovery method available and never interrupt an ECU flash.

## Where the driver came from

This work builds on [NikolaKozina/j2534](https://github.com/NikolaKozina/j2534),
which provided the OpenPort 2.0 J2534/libusb foundation. The Wine driver and
Linux setup in this repository were added while working through EcuFlash cable
discovery and communication on CachyOS.

The original BSD 3-Clause license and contributor history are preserved.
