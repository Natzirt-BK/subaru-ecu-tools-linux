# Subaru & Mitsubishi Evo ECU tools on Linux

> [!IMPORTANT]
> ## Install on CachyOS / Arch Linux
>
> Copy this complete command, paste it into a terminal, and press Enter:
>
> ```bash
> curl -fsSL https://raw.githubusercontent.com/Natzirt-BK/subaru-ecu-tools-linux/master/bootstrap-cachyos.sh | bash -s -- --gui
> ```
>
> The graphical installer lets you select EcuFlash, RomRaider Editor/Logger,
> official or experimental definitions, USB permissions, and experimental
> purchaser-supplied EvoScan support. It never reads or writes an ECU.

Already installed? Update the managed tools without reinstalling the large
applications:

```bash
bash ~/.local/src/subaru-ecu-tools-linux/linux/update-cachyos.sh
```

Remove the installed package:

```bash
bash ~/.local/src/subaru-ecu-tools-linux/linux/install-cachyos.sh --uninstall
```

This project packages the Linux-side setup for Subaru and Mitsubishi Evo ECU
tools on CachyOS/Arch. The validated Subaru setup uses RomRaider DimeMod,
EcuFlash, and a Tactrix OpenPort 2.0 cable.

RomRaider Editor and Logger now run on my Linux machine, and EcuFlash can find
and communicate with the OpenPort cable through Wine. EvoScan installation and
launching are available as an explicitly experimental option using the user's
purchased Windows installer; Linux vehicle communication is not yet validated.

## What is here

- An experimental Wine driver for EcuFlash and the OpenPort 2.0
- Launch scripts for EcuFlash, EvoScan, RomRaider Editor, and RomRaider Logger
- A CachyOS/Arch installer that checks dependencies and installs the Linux-side
  pieces
- A udev rule for OpenPort cable access
- A GUI/CLI definition manager with official definitions, optional community
  Stable/Beta/Alpha channels, and custom Mitsubishi XML import
- A lightweight updater that does not reinstall large applications
- Notes about the USB and Wine issues that had to be solved

This repository does **not** commit EcuFlash, RomRaider, the DimeMod package,
ROM files, logs, or Tactrix firmware. Checksum-pinned definition bundles are
published as installer assets with source/version labels. EvoScan is paid
software and is never redistributed by this project.

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
installation, **Subaru & Evo ECU Tools Setup** is also available in the application
menu. Choose **Install recommended tools** for the normal setup, or
**Customize installation** for advanced definition and EvoScan choices. If an
older installation may contain stale Wine or bridge files, choose **Clean
reinstall**. It removes installer-managed application/runtime state before
installing fresh copies while preserving ROMs, definitions, and logs.

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
shows the Tactrix license. Setup downloads the project's checksum-verified,
source-built Wine 11.1 runtime and includes its LGPL license. It is a
general-purpose Wine build with no dependency on another application.
`ECUFLASH_WINE` can select a different runner explicitly; no runner is treated
as compatible unless it passes the fresh-prefix startup test on that computer.
After installation, launch **EcuFlash (Wine)** from the application menu. Setup
removes the vendor-generated generic **EcuFlash** shortcut because it bypasses
the project launcher, USB-state synchronization, and diagnostic logging.

The launcher checks Linux USB sysfs for the OpenPort 2.0 hardware ID
`0403:cc4d` before every start. It publishes the Wine device interface only
while the cable is physically present and removes stale enumeration when it is
unplugged. An installed J2534 provider or an EcuFlash status-bar label is not,
by itself, proof of cable communication; use the read-only J2534 probe for that.
After a connected-cable probe, setup shuts down the probe's Wine server,
republishes the physical USB state, and starts EcuFlash through the installed
launcher. Setup fails if that fresh EcuFlash session reports `J2534 error [no
devices available]`, preventing a successful probe from masking a device that
was not released for EcuFlash.
Because an OpenPort reset can briefly re-enumerate it under a new Linux USB
device number, setup waits for the replacement device to remain stable before
starting EcuFlash.
Setup preserves and checksum-verifies Tactrix's official J2534 DLL, matching
the configuration that completed real ECU reads and flashes. The project Wine
kernel bridge supplies Linux USB access underneath that vendor implementation.
The post-test requires EcuFlash itself to report vendor DLL version 1.02.4870
and the connected adapter's serial number.

Setup can now download and install the checksum-pinned RomRaider DimeMod DM20
Linux package and its required Azul Zulu 32-bit Java runtime automatically at
`$HOME/.local/share/romraider-dm20`. The recommended installation includes both. An
existing complete DimeMod package is left unchanged. The Editor and Logger
shortcuts reproduce the validated launch configuration; the Logger uses the
`uucp` device-access group. Locations can be overridden with
`ECUFLASH_WINEPREFIX`, `ECUFLASH_WINE`, and `ROMRAIDER_HOME`.
Logger startup problems now appear in a graphical error dialog rather than
failing silently. Its output log rotates at 10 MB to prevent unbounded growth.

The definition page records make, model, and year for guidance, but RomRaider
matches Editor definitions by exact ROM ID. Official definitions are
recommended. Community Beta and Alpha are opt-in experimental channels.
Mitsubishi users can import Editor and Logger XML matched to their exact ROM ID.
Setup also creates an easy-access folder at
`Documents/Subaru & Evo ECU Tools` with separate application folders and live
shortcuts to definitions and diagnostic logs. Existing user-created items are
never overwritten.

After the first install, choose **Update installed tools** in the setup GUI or
run:

```bash
bash ~/.local/src/subaru-ecu-tools-linux/linux/update-cachyos.sh
```

For a confirmed clean reinstall from the command line:

```bash
bash ~/.local/src/subaru-ecu-tools-linux/linux/install-cachyos.sh --clean-install
```

The clean reinstall asks for confirmation unless `--yes` is also supplied.

This updates project-managed files without redownloading Wine, Java,
RomRaider, EcuFlash, or EvoScan.

More detailed setup and troubleshooting notes are in
[LINUX_ECU_TOOLS.md](LINUX_ECU_TOOLS.md).

To remove the installed launchers, bridge, EcuFlash prefix, cache, desktop
entries, USB rule, and default source checkout from a terminal:

```bash
bash ~/.local/src/subaru-ecu-tools-linux/linux/install-cachyos.sh --uninstall
```

The uninstaller removes an installer-managed DimeMod package but preserves
ROMs, definition packs under
`$HOME/.local/share/subaru-evo-ecu-definitions`, application logs, separately
obtained RomRaider files, and shared system packages.

Every check and installation writes a timestamped diagnostic log under
`$HOME/.local/state/subaru-ecu-tools-linux`; `latest.log` always points to the
newest run. When setup fails, share that log with the error report. Uninstall
removes the saved logs and writes its final cleanup log under `/tmp`.
Interactive terminals use colored progress and status messages while saved
logs remain plain text. Set `NO_COLOR=1` to disable terminal colors.

After a failed run, setup asks whether to upload the log to this repository as
a public GitHub issue. Recent application logs are included when available.
Automatic upload requires the `github-cli` package and
a prior `gh auth login`; setup never asks for or stores a GitHub token. The user
must confirm each upload, and declining keeps the log local.
The `--install-deps` and recommended-install paths install `github-cli`, but
GitHub authentication remains an explicit user action.
Reports are kept below GitHub's issue-body limit. If submission still fails,
setup prints GitHub's error, preserves a ready-to-attach Markdown report beside
the setup logs, and shows the manual issue URL.
Before the graphical setup terminal closes, it always confirms the outcome. A
successful run asks whether setup and its shortcuts worked. Answering no opens
an optional free-text prompt so the user can explain what went wrong, then
offers the same GitHub report upload as a script-detected failure. The
description appears near the top of the report. The terminal closes only after
the user presses Enter.

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
