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

This repository does **not** include EcuFlash, RomRaider, the DimeMod package,
ECU definitions, ROM files, logs, or Tactrix firmware. You need to get those
from their original sources.

## CachyOS quick start

Clone the repository and run the read-only system check first:

```bash
./linux/install-cachyos.sh --check
```

If the check looks good, build the bridge and install the user-level launchers:

```bash
./linux/install-cachyos.sh
```

If dependencies or the OpenPort udev rule are missing, the installer can handle
those too. These options use `sudo` because they change system packages or USB
permissions:

```bash
./linux/install-cachyos.sh --install-deps --install-udev
```

The installer does not install the tuning applications themselves. The default
locations can be changed with `ECUFLASH_WINEPREFIX`, `ECUFLASH_WINE`, and
`ROMRAIDER_HOME`.

More detailed setup and troubleshooting notes are in
[LINUX_ECU_TOOLS.md](LINUX_ECU_TOOLS.md).

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
