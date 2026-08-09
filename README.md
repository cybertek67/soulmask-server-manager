# Soulmask Server Manager v4.6

A Windows desktop manager for running multiple local Soulmask dedicated-server world slots. It provides safe start, save, graceful shutdown, backups, world configuration, Cloud Mist Forest/Shifting Sands map selection, and optional looping background audio.

![Soulmask Server Manager background](manager/UI%20image.png)

## Highlights

- Five independent server slots: `World-01` through `World-05`
- Cloud Mist Forest (`Level01_Main`) and Shifting Sands (`DLC_Level01_Main`)
- Save verification followed by Soulmask's graceful shutdown command
- Automatic pre-start and post-stop backups
- Per-world gameplay presets and quick settings
- Safe test-world reset with two confirmations and an archived save
- Built-in tribal-tech background music with volume and mute controls
- No continuous EchoPort polling

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1
- [SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD)
- Soulmask on Steam for each player
- The Shifting Sands DLC for players connecting to a Shifting Sands server

## Quick start

1. Download or clone this repository.
2. Open PowerShell in the repository folder.
3. Install the manager:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Install-Manager.ps1" -CreateDesktopShortcut
   ```

4. Install the dedicated-server files for World-01. Change the SteamCMD path if yours is elsewhere:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Install-WorldSlot.ps1" -Slot 1 -SteamCmdPath "C:\SteamCMD\steamcmd.exe"
   ```

5. Edit:

   ```text
   C:\SoulmaskServers\World-01\START - WORLD 01.bat
   ```

   Replace `CHANGE ME` and `CHANGE_THIS_PASSWORD` with your server name and a strong private admin password.

6. Open the desktop shortcut or run:

   ```text
   C:\SoulmaskServers\Soulmask server startup\Soulmask Server Manager.bat
   ```

See [Installation](docs/INSTALLATION.md) for the complete walkthrough.

## Selecting Shifting Sands

Select a world slot and click the large map button until it reads `MAP: SHIFTING SANDS`. The next server start uses `DLC_Level01_Main`. Switching the button back selects Cloud Mist Forest without deleting either map's save database.

For completely separate or simultaneous map servers, use different world slots and configure unique network ports.

## Safety and privacy

Do not commit a live `World-XX` folder. It can contain:

- Admin and server passwords
- Player and tribe data
- `world.db` save databases
- Local identifiers and logs

The included `.gitignore` excludes common runtime and credential files. The repository contains templates only—never the author's live saves, passwords, MiniMax API key, or Steam account data.

## Repository layout

```text
manager/      Manager application and bundled media
scripts/      Installation and world-slot setup helpers
templates/    Safe server launcher templates
docs/         Installation, usage, and troubleshooting guides
```

## Updating

- Stop the active server first.
- Re-run `Install-WorldSlot.ps1` to update a slot through SteamCMD.
- Re-run `Install-Manager.ps1` to refresh the manager files.
- Existing world saves and slot launchers are preserved by the scripts.

## Disclaimer

This is an independent community project and is not affiliated with CampFire Studio, Qooland Games, Valve, or Steam. Soulmask names and trademarks belong to their respective owners.

## License

Released under the [MIT License](LICENSE). Copyright (c) 2026 CyberTek Gamer 67.

