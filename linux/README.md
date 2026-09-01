# Ecu Tools by NatZirt installer files

- `setup-cachyos-gui.sh` — terminal setup menu; starts persistent installer
  music, owns the M mute key while the menu is active, and preserves the
  historical filename so existing shortcuts keep working
- Completion prompts use B to return to the main menu. The installer restores
  the original terminal streams before redrawing it so color and layout remain
  intact after a logged install run.
- `install-cachyos.sh` — installation, repair, checks, and removal engine
- `update-cachyos.sh` — refreshes managed files and validates EcuFlash/OpenPort
- `install-romraider2` — checksum-pinned RomRaider2 1.1.0 RC3 Java 21 installer
- `launch-romraider2` — isolated RomRaider2 Editor/Logger launcher
- `launch-*` — installed application launchers
- `sync-openport-device-state` — mirrors physical USB presence into Wine
- `*.desktop`, `*.directory`, `*.menu` — application-menu integration

Normal users should follow the repository [README](../README.md).
