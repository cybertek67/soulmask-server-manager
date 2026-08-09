# Troubleshooting

## Manager does not open

Run the PowerShell file directly to display the complete error:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "C:\SoulmaskServers\Soulmask server startup\Soulmask-Server-Manager.ps1"
```

Confirm that `UI image.png`, the icon, and the manager script remain together in the same folder.

## Launcher not found

The selected `World-XX` folder must contain:

```text
StartServer.bat
START - WORLD XX.bat
WSServer.exe
```

Run `Install-WorldSlot.ps1` for that slot, then edit its generated launcher.

## Server starts the wrong map

Stop the server, select the intended world slot, and click the manager's map button. Verify that it explicitly shows either `CLOUD MIST FOREST` or `SHIFTING SANDS` before starting.

## Save or stop fails

Verify that the `-EchoPort` value in `StartServer.bat` matches the manager's EchoPort. The default is `18888`. Check Windows Firewall and confirm another program is not occupying that port.

If EchoPort save or shutdown fails, the manager deliberately leaves the server running. Review the server console before taking manual action.

## Configure World says the file is missing

Start that world once and let it finish generating. Stop it safely, then reopen `CONFIGURE WORLD`.

## No background music

Confirm this file exists beside the PowerShell manager:

```text
Soulmask-Tribal-Tech-Loop-v1.mp3
```

Also check the manager's mute button, volume slider, and Windows Volume Mixer.

## Shifting Sands access error

Every connecting player must own the required Shifting Sands DLC. The server and client should both be fully updated.

