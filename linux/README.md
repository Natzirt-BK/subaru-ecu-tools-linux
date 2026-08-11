# Linux installer layout

The Linux integration is split by responsibility:

- `install-cachyos.sh` — main CLI, checks, install, update-files, diagnostics,
  and uninstall orchestration.
- `setup-cachyos-gui.sh` — native KDE/KDialog front end for the main CLI.
- `update-cachyos.sh` — lightweight Git and managed-file updater.
- `install-romraider-definitions` — checksum-pinned definition download,
  custom XML import, and active definition selection.
- `configure-romraider-definitions` — idempotently applies the active selection
  to an existing RomRaider settings file while preserving user entries.
- `launch-*` — application launchers and application-log handling.
- `*.desktop` — application-menu templates rendered by the installer.
- `99-openport2.rules` — optional OpenPort 2.0 USB permissions.
- `build-ecuflash-wine-runtime.sh` — maintainer-only reproducible runtime build.

## Installed data

- Managed commands: `~/.local/bin`
- Managed bridge/runtime data: `~/.local/share/subaru-ecu-tools-linux`
- Preserved definition packs: `~/.local/share/subaru-evo-ecu-definitions`
- RomRaider DimeMod: `~/.local/share/romraider-dm20`
- Shared EcuFlash/EvoScan Wine prefix: `~/.local/share/ecuflash-proton`
- Download cache: `~/.cache/subaru-ecu-tools-linux`
- Setup logs: `~/.local/state/subaru-ecu-tools-linux`
- RomRaider application logs/settings: `~/.RomRaider`
- Easy-access application folders: `~/Documents/Subaru & Evo ECU Tools`

The historical `subaru-ecu-tools-linux` repository and data path names remain
unchanged for backward compatibility. User-facing names cover Subaru and
Mitsubishi Evo.
