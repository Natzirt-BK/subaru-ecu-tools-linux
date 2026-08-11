# Subaru & Mitsubishi Evo ECU tools on Linux

This repository contains the source for an experimental Wine driver that lets
EcuFlash discover and communicate with a Tactrix OpenPort 2.0. It also contains
portable launchers for the RomRaider editor and logger.
It also provides experimental purchaser-supplied EvoScan installation, a
definition manager, and a lightweight updater.

## Scope and safety

The bridge has been validated for cable discovery and communication. That is
not proof that writing an ECU is safe. Begin with a supervised, vehicle-connected
read-only test. Keep a known-good recovery path and never interrupt a flash.

No EcuFlash binary, RomRaider binary, EvoScan installer, Tactrix firmware, or
ROM image is committed to Git history. The installer fetches checksum-pinned
EcuFlash, DimeMod, Java, and definition packages from documented sources or
this project's GitHub Releases.

## CachyOS quick start

Download and inspect the native bootstrap before running it:

    curl -fL https://raw.githubusercontent.com/Natzirt-BK/subaru-ecu-tools-linux/master/bootstrap-cachyos.sh -o /tmp/bootstrap-cachyos.sh
    less /tmp/bootstrap-cachyos.sh
    bash /tmp/bootstrap-cachyos.sh --check

Then build and install the user-level tools. The optional flags install missing
repository packages and the OpenPort permission rule, and download DimeMod and
the official EcuFlash installer:

    bash /tmp/bootstrap-cachyos.sh --install-deps --install-udev --install-romraider --install-ecuflash

For a graphical KDialog wizard on CachyOS KDE:

    bash /tmp/bootstrap-cachyos.sh --gui

The wizard offers a recommended installation, a compact Customize path,
Update, Check, and guided Uninstall. The command-line equivalent for the
recommended installation is `--yes-all`.

To refresh project-managed files without reinstalling large applications:

    bash ~/.local/src/subaru-ecu-tools-linux/linux/update-cachyos.sh

To remove files owned by this setup:

    bash ~/.local/src/subaru-ecu-tools-linux/linux/install-cachyos.sh --uninstall

Removal includes the launchers, desktop entries, bridge/runtime data, EcuFlash
prefix and cache, USB rule, default source checkout, and installer-managed
DimeMod package. It preserves separately obtained RomRaider packages, ROMs,
definition packs in `$HOME/.local/share/subaru-evo-ecu-definitions`,
application logs, and shared system packages.

## Diagnostic logs

Every command-line or graphical setup run records its terminal output in:

    $HOME/.local/state/subaru-ecu-tools-linux/

`latest.log` points to the newest run. Setup prints the exact file to share if
an error occurs. The uninstaller removes the saved setup logs and writes its own
final log to `/tmp/subaru-ecu-tools-uninstall-<timestamp>.log`.

On failure, the terminal asks whether to submit the log as a public GitHub
issue. If the user answers yes and the GitHub CLI is already authenticated
(`gh auth login`), the installer creates an issue in the project repository
containing setup output and recent application logs when available. It never
requests or saves a GitHub token,
and it does not upload anything unless the user confirms.

The optional EcuFlash step downloads checksum-pinned version 1.44.4870 directly
from Tactrix. After the vendor installer closes, setup starts EcuFlash for 12
seconds and fails if it crashes or exits early. Setup uses the project's
checksum-verified, source-built Wine 11.1 runtime, including its LGPL license;
set `ECUFLASH_WINE` to test another general-purpose runner. No runtime from an
unrelated application is downloaded or reused. Compatibility is established
only by the startup test on the user's computer.
Setup does not silently accept the Tactrix license and never downloads ROM
images or firmware. Run it from a normal user account; it
invokes `sudo` only for the explicit dependency and udev options.

Use the **EcuFlash (Wine)** application-menu shortcut installed by this
project. Setup removes the vendor-generated shortcut named only **EcuFlash**,
which bypasses USB-state synchronization and diagnostic logging.

At each launch, the project synchronizes EcuFlash's Wine device enumeration
with the physical USB state reported by Linux sysfs. With no `0403:cc4d` cable
attached, the OpenPort device-interface keys are removed so EcuFlash cannot
mistake an installed bridge for connected hardware. Physical presence and a
successful read-only J2534 probe are separate checks.

## EvoScan (experimental)

EvoScan is paid, account/serial-bound software and is not redistributed here.
Select it in the GUI or pass `--evoscan-installer /path/to/installer.exe` to
install a purchaser-supplied EXE/MSI in the tested shared Wine/OpenPort
environment. Activation remains between the user and EvoScan and is never
included in project logs. Launch it with **EvoScan (Wine, Experimental)**.
Application startup is tested, but Linux vehicle communication is not yet
validated.

## OpenPort permissions

Copy `linux/99-openport2.rules` to `/etc/udev/rules.d/`, add your user to the
`uucp` group, reload the udev rules, and reconnect the cable. Log out and back
in after changing group membership. The installer's `--install-udev` option
performs these steps on CachyOS/Arch.

The OpenPort 2.0 USB ID is `0403:cc4d`. Verify it with `lsusb`.

## EcuFlash

1. Install EcuFlash into a Wine or Proton prefix.
2. Install build dependencies: LLVM-MinGW, Wine development headers, libusb
   development headers, a C compiler, and Wine's `winebuild`.
3. If needed, set `LLVM_MINGW_ROOT` and `WINEBUILD` for your distribution.
4. Run `sh wine-bridge/build-openport-driver.sh`.
5. Put `linux/launch-ecuflash` on your `PATH` and make it executable.
6. Set `ECUFLASH_WINE` if the required Wine/Proton runner is not named `wine`.

The launcher sets `WINEDLLPATH` to the split driver layout generated by the
build script. `ECUFLASH_WINEPREFIX`, `ECUFLASH_DIR`, and
`ECUFLASH_WINEDLLPATH` may also be overridden.

See `wine-bridge/README-linux-driver.md` for the USB endpoint and Wine-driver
details that made EcuFlash discovery work.

## RomRaider editor and logger

1. Run setup with `--install-romraider` (included by `--yes-all`) to install the
   checksum-pinned DimeMod DM20 Linux package and Azul Zulu 32-bit JRE at
   `$HOME/.local/share/romraider-dm20`. A complete existing package is kept.
2. Put `linux/launch-romraider` on your `PATH` and make it executable.
3. Run `ROMRAIDER_MODE=editor launch-romraider` for the editor.
4. Run `ROMRAIDER_MODE=logger launch-romraider` for the logger.

Use `--install-definitions official` for the official RomRaider Editor
0.8.3.1b and Logger v370 definitions. `stable`, `beta`, and `alpha` select the
corresponding community Subaru Editor channel; Beta and Alpha are experimental.
The GUI also supports custom Mitsubishi Editor/Logger XML import. Vehicle
make/year/model is recorded for support, but Editor matching uses the exact ROM
ID. Existing user-configured Editor definitions are preserved.

For easier browsing, setup creates
`$HOME/Documents/Subaru & Evo ECU Tools/` (or the desktop's configured
Documents directory). It contains separate RomRaider Editor, RomRaider Logger,
EcuFlash, EvoScan, and Diagnostic Logs folders with links to the files actually
used by each application. These are live links rather than duplicate files.

The launcher requires RomRaider's bundled 32-bit JRE by default because its
Linux logger libraries are 32-bit. Set `ROMRAIDER_JAVA` to override it only
with a compatible 32-bit runtime. The CachyOS Logger launcher enters the
`uucp` group before starting RomRaider. Missing membership, package, Java, and
Java-exit errors appear in a graphical dialog. Terminal output is saved in
`$HOME/.RomRaider/romraider_sout.log` and rotates at 10 MB.

Desktop-entry templates are provided in `linux/`. Install the launchers on your
`PATH` before using them.

## Troubleshooting

- `J2534 error [no devices available]`: check USB permissions, cable USB ID,
  `WINEDLLPATH`, and whether stale bridge artifacts are being loaded.
- Writes succeed but reads time out: confirm the driver claims USB interface 1
  and uses bulk endpoints OUT `0x02` and IN `0x82`.
- EcuFlash loads the wrong probe: do not advertise the legacy OpenPort 1.x/FTDI
  interface GUID. The OpenPort 2.0 GUID is documented in the driver notes.
- RomRaider logger does not open: inspect `$HOME/.RomRaider/romraider_sout.log`
  and verify the selected Java architecture matches the bundled native library.
