param(
    [string]$ServerRoot = "C:\SoulmaskServers",
    [switch]$CreateDesktopShortcut
)

$ErrorActionPreference = "Stop"
$ServerRoot = [System.IO.Path]::GetFullPath($ServerRoot)
$packageRoot = Split-Path $PSScriptRoot -Parent
$sourceManager = Join-Path $packageRoot "manager"
$targetManager = Join-Path $ServerRoot "Soulmask server startup"

if (-not (Test-Path $sourceManager)) {
    throw "Manager package folder was not found: $sourceManager"
}

New-Item -ItemType Directory -Path $ServerRoot -Force | Out-Null
New-Item -ItemType Directory -Path $targetManager -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $ServerRoot "ManagerBackups") -Force | Out-Null

foreach ($slot in 1..5) {
    New-Item -ItemType Directory -Path (Join-Path $ServerRoot ("World-{0:D2}" -f $slot)) -Force | Out-Null
}

Copy-Item -Path (Join-Path $sourceManager "*") -Destination $targetManager -Recurse -Force

if ($CreateDesktopShortcut) {
    $desktop = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktop "Soulmask Server Manager.lnk"
    $launcher = Join-Path $targetManager "Soulmask Server Manager.bat"
    $icon = Join-Path $targetManager "Soulmask_Server_Manager.ico"
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $launcher
    $shortcut.WorkingDirectory = $targetManager
    if (Test-Path $icon) { $shortcut.IconLocation = $icon }
    $shortcut.Save()
}

Write-Host "Soulmask Server Manager installed to:"
Write-Host $targetManager
Write-Host ""
Write-Host "Next: install the dedicated-server files into at least one World-XX folder."

