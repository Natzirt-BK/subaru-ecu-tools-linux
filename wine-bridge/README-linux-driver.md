# EcuFlash OpenPort Wine driver

EcuFlash 1.44 embeds Tactrix's OpenPort access library. Its interface scan does
not use the system J2534 registry entry, so a working registry J2534 bridge by
itself is not sufficient. The Wine driver attaches to Wine's USB PnP device,
publishes Tactrix's OpenPort 2.0 interface GUID, and forwards raw reads and
writes through the split Unix libusb module.

Build the required 64-bit Wine kernel module with:

    sh wine-bridge/build-openport-driver.sh

The Wine prefix is 64-bit even though EcuFlash is a 32-bit application. A
32-bit `openport.sys` fails at driver initialization with `0xc0000142`.

`build-openport-driver.sh` updates both the primary artifacts and Wine's split
`WINEDLLPATH` directories. This is required; otherwise Wine can silently load
an older cached `openport.sys`.

The 32-bit J2534 frontend must include Wine's `winecrt0` `unix_lib.o`. That
startup object registers the paired native Unix library with Wine. A normal
MinGW DLL can have all the expected J2534 exports yet fail at `LoadLibrary`
with Windows error 126 because the Unix-library registration is absent.

The OpenPort 2.0 (`0403:cc4d`) exposes two USB interfaces. Interface 0 contains
interrupt/status endpoint `0x81`. J2534 data uses interface 1 with bulk OUT
`0x02` and bulk IN `0x82`. Claiming interface 0 or reading `0x81` produces
successful writes followed by read timeouts.

The service, J2534 provider, and USB device interface have deliberately
separate registry files. Driver installation must never permanently enumerate
the USB device: `linux/sync-openport-device-state` adds that interface only
when Linux sysfs contains `0403:cc4d`, and deletes it when the cable is absent.
This prevents EcuFlash from displaying a phantom OpenPort merely because the
bridge is installed.

Do not publish the legacy FTDI/OpenPort 1.x GUID
`{219D0508-57A8-4FF5-97A1-BD86587C6C7E}` for this cable. It makes EcuFlash run
the wrong D2XX probe (`0x220198`, `0x222198`, `0x2221c4`, `0x2220a4`). The
OpenPort 2.0 interface GUID is `{6D1781B7-C987-4F6C-8D4F-1EFC098BEA67}`.

The Unix bridge enumerates the matching libusb device before opening it and
logs the bus, address, and exact libusb result. Do not use
`libusb_open_device_with_vid_pid()` here: its null return hides the difference
between an absent adapter and a present adapter that the current process cannot
open.

Computer-only validation on 2026-08-09 passed three clean EcuFlash launches.
Every run reported API `04.04`, DLL `1.02.4870`, and firmware `1.17.4955`,
without `J2534 error [no devices available]`.

This validates discovery and cable communication only. Perform a separate,
supervised vehicle-connected read-only test before enabling ROM writes.
