# Installation

## 1. Install SteamCMD

Download SteamCMD from Valve's official documentation and extract it to a permanent folder, for example:

```text
C:\SteamCMD\steamcmd.exe
```

Run `steamcmd.exe` once and allow it to update itself.

## 2. Install the manager

From the repository root, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Install-Manager.ps1" -CreateDesktopShortcut
```

The default layout is:

```text
C:\SoulmaskServers\
├── ManagerBackups\
├── Soulmask server startup\
├── World-01\
├── World-02\
├── World-03\
├── World-04\
└── World-05\
```

To use another root folder, pass the same `-ServerRoot` value to both installation scripts.

## 3. Install a world slot

Example for World-01:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Install-WorldSlot.ps1" `
  -Slot 1 `
  -SteamCmdPath "C:\SteamCMD\steamcmd.exe" `
  -ServerRoot "C:\SoulmaskServers"
```

The script uses SteamCMD app `3017310`, installs or validates the dedicated-server files, and adds safe launcher templates.

Repeat with `-Slot 2` through `-Slot 5` only when additional independent installations are needed.

## 4. Configure the launcher

Open the generated `START - WORLD XX.bat` file in a text editor. At minimum, change:

```bat
-SteamServerName="CHANGE ME"
-adminpsw="CHANGE_THIS_PASSWORD"
```

The admin password is stored as plain text because Soulmask receives it as a launch parameter. Keep this file private.

## 5. First launch

1. Open Soulmask Server Manager.
2. Select the desired world slot with the arrow buttons.
3. Select `CLOUD MIST FOREST` or `SHIFTING SANDS` using the map button.
4. Click `START SERVER`.
5. Allow the first world generation to finish.
6. Join the server from the Soulmask client.

The gameplay configuration file does not exist until the server has generated it. Start and stop the server once before using every option in `CONFIGURE WORLD`.

## Windows Firewall

Windows may request network permission the first time `WSServer.exe` runs. Allow access on the network profiles appropriate for your setup. Internet-hosted servers may also require router port forwarding and unique ports for simultaneous instances.

## Custom manager location

The manager normally derives the server root from its installed folder. Advanced users can override it before launch:

```powershell
$env:SOULMASK_SERVER_ROOT = "D:\GameServers\Soulmask"
& "D:\Tools\Soulmask Manager\Soulmask Server Manager.bat"
```

