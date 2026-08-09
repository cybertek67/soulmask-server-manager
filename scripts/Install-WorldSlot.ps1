param(
    [Parameter(Mandatory=$true)]
    [ValidateRange(1,5)]
    [int]$Slot,

    [Parameter(Mandatory=$true)]
    [string]$SteamCmdPath,

    [string]$ServerRoot = "C:\SoulmaskServers"
)

$ErrorActionPreference = "Stop"
$SteamCmdPath = [System.IO.Path]::GetFullPath($SteamCmdPath)
$ServerRoot = [System.IO.Path]::GetFullPath($ServerRoot)
$packageRoot = Split-Path $PSScriptRoot -Parent
$templates = Join-Path $packageRoot "templates"
$worldName = "World-{0:D2}" -f $Slot
$worldPath = Join-Path $ServerRoot $worldName

if (-not (Test-Path $SteamCmdPath -PathType Leaf)) {
    throw "steamcmd.exe was not found: $SteamCmdPath"
}

New-Item -ItemType Directory -Path $worldPath -Force | Out-Null

Write-Host "Installing/updating Soulmask Dedicated Server in $worldPath ..."
& $SteamCmdPath +login anonymous +force_install_dir $worldPath +app_update 3017310 validate +quit
if ($LASTEXITCODE -ne 0) {
    throw "SteamCMD failed with exit code $LASTEXITCODE"
}

Copy-Item -LiteralPath (Join-Path $templates "StartServer.bat") -Destination (Join-Path $worldPath "StartServer.bat") -Force
$slotLauncher = Join-Path $worldPath ("START - WORLD {0:D2}.bat" -f $Slot)
if (-not (Test-Path $slotLauncher)) {
    Copy-Item -LiteralPath (Join-Path $templates "START-WORLD.example.bat") -Destination $slotLauncher
}

Write-Host ""
Write-Host "$worldName is installed."
Write-Host "IMPORTANT: Edit the following file and replace CHANGE_THIS_PASSWORD before starting:"
Write-Host $slotLauncher

