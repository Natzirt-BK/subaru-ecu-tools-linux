# j2534

> Linux/Wine users: see [LINUX_ECU_TOOLS.md](LINUX_ECU_TOOLS.md) for the
> experimental EcuFlash OpenPort 2.0 bridge and portable RomRaider launchers.

j2534 is a library written specifically for the [Tactrix Openport 2.0](https://www.tactrix.com/index.php?option=com_virtuemart&page=shop.product_details&flypage=flypage.tpl&product_id=17&Itemid=53&redirected=1&Itemid=53 "Tactrix Openport 2.0") cable.

This library implements most of the SAE J2534-1 API functions as used by the [RomRaider - Open Source ECU Tuning](https://www.romraider.com/ "RomRaider - Open Source ECU Tuning") project.

This fork focuses on Linux and Wine. The library depends on [libusb](https://libusb.info/ "libusb") version 1.08 or higher.


## Linux Compilation
- Install pkg-config
- Install libusb-1.0-devel
- Run make on the command line to compile the library
- Run make install if you wish to install the library in `/usr/local/lib/`


## Using the library
Before using this library, remove the SD card from the Openport 2.0

### Linux
USB devices require write permission, add a udev rule entry in `/etc/udev/rules.d/`
with the contents such as this to allow write access:  
`SUBSYSTEM=="usb", ATTRS{idVendor}=="0403", ATTR{idProduct}=="cc4d", GROUP="dialout", MODE="0666"`

Your User ID must also be a member of the `dialout` group on the system.
