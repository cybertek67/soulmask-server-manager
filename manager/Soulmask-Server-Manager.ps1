$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
try { Add-Type -AssemblyName PresentationCore -ErrorAction Stop } catch {}

$nativeCode = @"
using System;
using System.Runtime.InteropServices;
public static class ConsoleControlV3 {
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool AttachConsole(uint dwProcessId);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool FreeConsole();
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool SetConsoleCtrlHandler(IntPtr HandlerRoutine, bool Add);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool GenerateConsoleCtrlEvent(uint dwCtrlEvent, uint dwProcessGroupId);
    public const uint CTRL_C_EVENT = 0;
    public const uint CTRL_BREAK_EVENT = 1;
}
"@
try { Add-Type -TypeDefinition $nativeCode -ErrorAction Stop } catch {}


if (-not ("ManagedConsoleWindowV41" -as [type])) {
Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class ManagedConsoleWindowV41 {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool IsWindow(IntPtr hWnd);

    public const int SW_RESTORE = 9;
}
"@
}

$Root = if ($env:SOULMASK_SERVER_ROOT) {
    [System.IO.Path]::GetFullPath($env:SOULMASK_SERVER_ROOT)
} else {
    # The installed layout is <server root>\Soulmask server startup\this script.
    [System.IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
}
$Worlds = @("World-01","World-02","World-03","World-04","World-05")
$CurrentIndex = 0
$EchoHost = "127.0.0.1"
$EchoPort = 18888
$GamePort = 8777
$script:OperationBusy = $false
$script:ManagerMusic = $null
$script:ManagerMusicMuted = $false
$ManagerMusicPath = Join-Path $PSScriptRoot "Soulmask-Tribal-Tech-Loop-v1.mp3"
$ManagerAudioSettingsPath = Join-Path $PSScriptRoot "ManagerAudioSettings.json"

function Get-ManagerAudioVolume {
    if (Test-Path $ManagerAudioSettingsPath) {
        try {
            $saved = Get-Content $ManagerAudioSettingsPath -Raw | ConvertFrom-Json
            $volume = [int]$saved.Volume
            if ($volume -ge 0 -and $volume -le 100) { return $volume }
        } catch {}
    }
    return 18
}

function Save-ManagerAudioVolume([int]$volume) {
    $o = [PSCustomObject]@{ Version=1; Volume=$volume; SavedAt=(Get-Date).ToString("o") }
    [System.IO.File]::WriteAllText($ManagerAudioSettingsPath,($o | ConvertTo-Json),(New-Object System.Text.UTF8Encoding($false)))
}

function Start-ManagerMusic {
    if (-not (Test-Path $ManagerMusicPath) -or -not ("System.Windows.Media.MediaPlayer" -as [type])) {
        $musicStatus.Text = "TRIBAL AUDIO: FILE UNAVAILABLE"
        $musicStatus.ForeColor = [System.Drawing.Color]::Salmon
        $musicVolume.Enabled = $false
        $musicMute.Enabled = $false
        return
    }
    try {
        $script:ManagerMusic = New-Object System.Windows.Media.MediaPlayer
        $script:ManagerMusic.Volume = ([double]$musicVolume.Value / 100.0)
        $script:ManagerMusic.Open((New-Object System.Uri -ArgumentList $ManagerMusicPath))
        $script:ManagerMusic.add_MediaEnded({
            try {
                $script:ManagerMusic.Position = [TimeSpan]::Zero
                $script:ManagerMusic.Play()
            } catch {}
        })
        $script:ManagerMusic.Play()
        $musicStatus.Text = "TRIBAL AUDIO"
        $musicStatus.ForeColor = [System.Drawing.Color]::Khaki
    } catch {
        $musicStatus.Text = "TRIBAL AUDIO: COULD NOT START"
        $musicStatus.ForeColor = [System.Drawing.Color]::Salmon
    }
}

function Stop-ManagerMusic {
    try {
        if ($script:ManagerMusic) {
            $script:ManagerMusic.Stop()
            $script:ManagerMusic.Close()
        }
    } catch {}
    $script:ManagerMusic = $null
}

function SelectedWorld { return $Worlds[$CurrentIndex] }
function SelectedPath { return Join-Path $Root (SelectedWorld) }

function Get-WorldMapPreferencesPath([string]$world) {
    return Join-Path (Join-Path $Root $world) "ManagerMap.json"
}

function Get-WorldMapId([string]$world) {
    $path = Get-WorldMapPreferencesPath $world
    if (Test-Path $path) {
        try {
            $saved = Get-Content $path -Raw | ConvertFrom-Json
            if ($saved.MapId -in @("Level01_Main","DLC_Level01_Main")) { return [string]$saved.MapId }
        } catch {}
    }
    return "Level01_Main"
}

function Get-WorldMapName([string]$world) {
    if ((Get-WorldMapId $world) -eq "DLC_Level01_Main") { return "SHIFTING SANDS" }
    return "CLOUD MIST FOREST"
}

function Set-WorldMapId([string]$world,[string]$mapId) {
    if ($mapId -notin @("Level01_Main","DLC_Level01_Main")) { throw "Unsupported Soulmask map: $mapId" }
    $o = [PSCustomObject]@{
        Version = 1
        World = $world
        MapId = $mapId
        MapName = $(if ($mapId -eq "DLC_Level01_Main") { "Shifting Sands" } else { "Cloud Mist Forest" })
        SavedAt = (Get-Date).ToString("o")
    }
    [System.IO.File]::WriteAllText((Get-WorldMapPreferencesPath $world),($o | ConvertTo-Json),(New-Object System.Text.UTF8Encoding($false)))
}

function Get-ServerConsoleTitle([string]$world) {
    return "Soulmask Server - $world"
}

function Get-ManagerLaunchWrapper([string]$world,[string]$launcher,[string]$mapId) {
    $wp = Join-Path $Root $world
    $wrapper = Join-Path $wp "Manager-Launch-$world.bat"
    $title = Get-ServerConsoleTitle $world

    $content = @"
@echo off
title $title
set "SOULMASK_MAP=$mapId"
call "$launcher"
"@
    Set-Content -Path $wrapper -Value $content -Encoding ASCII
    return $wrapper
}


$ManagerSettingsPath = Join-Path $Root "ServerManagerSettings.json"

function Get-WorldPreferencesPath([string]$world) {
    return Join-Path (Join-Path $Root $world) "ManagerPreferences.json"
}

function New-VanillaSettings {
    return [PSCustomObject]@{
        DisableBuildingDecay = $false
        DeployedTribesmen = 3
        SavedTribesmen = 5
        AnimalFollowers = 3
        TamingSpeed = 1.0
        AwarenessXP = 1.0
        CharacterXP = 1.0
        ProficiencyXP = 1.0
        TrainingXP = 1.0
        Gathering = 1.0
        CraftingSpeed = 1.0
        ChestLoot = 1.0
        BossLoot = 1.0
        DurabilityLoss = 1.0
        RepairMaterialCost = 1.0
        CropGrowth = 1.0
        AnimalGrowth = 1.0
        CarryWeight = 1.0
        FuelConsumption = 1.0
        BonfireBurnRate = 1.0
        HungerRate = 1.0
        ThirstRate = 1.0
        DeathPenalty = "Vanilla"
        PortalResources = $true
        RandomAnimalInvasions = $true
        BarbarianInvasions = $true
    }
}

function New-SoloPresetSettings {
    return [PSCustomObject]@{
        DisableBuildingDecay = $true
        DeployedTribesmen = 10
        SavedTribesmen = 10
        AnimalFollowers = 5
        TamingSpeed = 3.0
        AwarenessXP = 2.0
        CharacterXP = 2.0
        ProficiencyXP = 2.0
        TrainingXP = 10.0
        Gathering = 2.5
        CraftingSpeed = 2.0
        ChestLoot = 2.0
        BossLoot = 2.0
        DurabilityLoss = 0.5
        RepairMaterialCost = 0.5
        CropGrowth = 3.0
        AnimalGrowth = 3.0
        CarryWeight = 1.5
        FuelConsumption = 0.5
        BonfireBurnRate = 0.5
        HungerRate = 0.7
        ThirstRate = 0.7
        DeathPenalty = "Keep Inventory"
        PortalResources = $true
        RandomAnimalInvasions = $true
        BarbarianInvasions = $true
    }
}

function Merge-SettingsWithVanilla($source) {
    $base = New-VanillaSettings
    if ($null -eq $source) { return $base }
    foreach ($p in $base.PSObject.Properties) {
        $sp = $source.PSObject.Properties[$p.Name]
        if ($null -ne $sp) { $p.Value = $sp.Value }
    }
    return $base
}

function Get-ManagerDefaults {
    if (-not (Test-Path $ManagerSettingsPath)) { return $null }
    try {
        $o = Get-Content $ManagerSettingsPath -Raw | ConvertFrom-Json
        if ($o.PSObject.Properties["Settings"]) {
            return Merge-SettingsWithVanilla $o.Settings
        }
        # Older v3.4 files contained only two settings. Do not expand those
        # into a full preset automatically, because that could overwrite other
        # existing world preferences. Open Configure World and save once in v3.5.
        if ($o.PSObject.Properties["ApplyGlobalQuickSettings"]) { return $null }
    } catch {}
    return $null
}

function Save-ManagerDefaults($settings) {
    $o = [PSCustomObject]@{
        Version = 3
        ApplyGlobalSettings = $true
        Settings = $settings
        SavedAt = (Get-Date).ToString("o")
    }
    $json = $o | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($ManagerSettingsPath,$json,(New-Object System.Text.UTF8Encoding($false)))
}

function Get-WorldPreferences([string]$world) {
    $path = Get-WorldPreferencesPath $world
    if (-not (Test-Path $path)) { return $null }
    try {
        $o = Get-Content $path -Raw | ConvertFrom-Json
        if ($o.PSObject.Properties["Settings"]) { return Merge-SettingsWithVanilla $o.Settings }
    } catch {}
    return $null
}

function Save-WorldPreferences([string]$world,$settings) {
    $path = Get-WorldPreferencesPath $world
    $o = [PSCustomObject]@{
        Version = 3
        World = $world
        Settings = $settings
        SavedAt = (Get-Date).ToString("o")
    }
    $json = $o | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($path,$json,(New-Object System.Text.UTF8Encoding($false)))
}

function Clear-AllWorldPreferences {
    foreach ($w in $Worlds) {
        $p = Get-WorldPreferencesPath $w
        if (Test-Path $p) { Remove-Item $p -Force -ErrorAction SilentlyContinue }
    }
}

function Get-PersistentSettingsForWorld([string]$world) {
    $worldPrefs = Get-WorldPreferences $world
    if ($worldPrefs) { return $worldPrefs }
    return Get-ManagerDefaults
}

function Get-NumberFromRaw([string]$raw,[string]$key,[double]$fallback) {
    $pattern = '("' + [regex]::Escape($key) + '"\s*:\s*)([-+]?\d+(?:\.\d+)?)'
    $m = [regex]::Match($raw,$pattern)
    if ($m.Success) { return [double]$m.Groups[2].Value }
    return $fallback
}

function Set-NumberInRaw([string]$raw,[string]$key,$value) {
    $pattern = '("' + [regex]::Escape($key) + '"\s*:\s*)[-+]?\d+(?:\.\d+)?'
    $replacement = '${1}' + ([string]::Format([System.Globalization.CultureInfo]::InvariantCulture,"{0}",$value))
    return [regex]::Replace($raw,$pattern,$replacement)
}

function Get-AllSettingsFromConfig([string]$configPath) {
    $s = New-VanillaSettings
    if (-not (Test-Path $configPath)) { return $s }
    $raw = Get-Content $configPath -Raw

    $decaySwitch = Get-NumberFromRaw $raw "JianZhuFuLanKaiGuan" 1
    $decayMul = Get-NumberFromRaw $raw "JianZhuFuLanMul" 1
    $s.DisableBuildingDecay = (($decaySwitch -eq 0) -or ($decayMul -eq 0))
    $s.DeployedTribesmen = [int](Get-NumberFromRaw $raw "ManRenChuZhanCount" 3)
    $s.SavedTribesmen = [int](Get-NumberFromRaw $raw "XinXiLuRu" 5)
    $s.AnimalFollowers = [int](Get-NumberFromRaw $raw "AnimalFollowerMaxCount" 3)
    $s.TamingSpeed = Get-NumberFromRaw $raw "AddRenKeDuRatio" 1
    $s.AwarenessXP = Get-NumberFromRaw $raw "ExpRatio" 1
    $s.CharacterXP = Get-NumberFromRaw $raw "ChengZhangExpRatio" 1
    $s.ProficiencyXP = Get-NumberFromRaw $raw "ShuLianDuExpRatio" 1
    $s.TrainingXP = Get-NumberFromRaw $raw "TrainingExpRatio" 1
    $s.Gathering = Get-NumberFromRaw $raw "CaiJiDiaoLuoRatio" 1
    $s.CraftingSpeed = Get-NumberFromRaw $raw "ZhiZuoTimeRatio" 1
    $s.ChestLoot = Get-NumberFromRaw $raw "BaoXiangDropRatio" 1
    $s.BossLoot = Get-NumberFromRaw $raw "BossRenDiaoLuoRatio" 1
    $s.DurabilityLoss = Get-NumberFromRaw $raw "NaiJiuXiShu" 1
    $s.RepairMaterialCost = Get-NumberFromRaw $raw "XiuLiXuYaoCaiLiaoRatio" 1
    $s.CropGrowth = Get-NumberFromRaw $raw "ZuoWuShengZhangRatio" 1
    $s.AnimalGrowth = Get-NumberFromRaw $raw "DongWuShengZhangRatio" 1
    $s.CarryWeight = Get-NumberFromRaw $raw "MaxFuZhongRatio" 1
    $s.FuelConsumption = Get-NumberFromRaw $raw "RanLiaoXiaoHaoRatio" 1
    $s.BonfireBurnRate = Get-NumberFromRaw $raw "YingHuoRanShaoSuDuRatio" 1
    $s.HungerRate = Get-NumberFromRaw $raw "ShiWuXiaoHaoRatio" 1
    $s.ThirstRate = Get-NumberFromRaw $raw "ShuiXiaoHaoRatio" 1

    $keep = Get-NumberFromRaw $raw "PlayerDeathCantDropItemKaiGuan" 0
    $move = Get-NumberFromRaw $raw "FuHuoMoveSiWangBaoKaiGuan" 0
    if ($keep -eq 1) { $s.DeathPenalty = "Keep Inventory" }
    elseif ($move -eq 1) { $s.DeathPenalty = "Bag at Respawn" }
    else { $s.DeathPenalty = "Vanilla" }

    $s.PortalResources = ((Get-NumberFromRaw $raw "JianZhuChuanSongMenPlusKaiGuan" 1) -ne 0)
    $s.RandomAnimalInvasions = ((Get-NumberFromRaw $raw "SuiJiRuQinKaiGuan" 1) -ne 0)
    $s.BarbarianInvasions = ((Get-NumberFromRaw $raw "RuQinKaiGuan" 1) -ne 0)
    return $s
}

function Set-AllSettingsInConfig([string]$configPath,$settings,[bool]$makeBackup=$true) {
    if (-not (Test-Path $configPath)) {
        return [PSCustomObject]@{Success=$false;Changed=$false;Reason="MissingConfig";Backup=$null;Missing=@()}
    }
    $raw = Get-Content $configPath -Raw
    $state = @{ Text = $raw }
    $missing = New-Object System.Collections.Generic.List[string]

    function Apply-Key([string]$key,$value) {
        if ([regex]::IsMatch($state.Text,'"'+[regex]::Escape($key)+'"\s*:')) {
            $state.Text = Set-NumberInRaw $state.Text $key $value
        } else {
            $missing.Add($key)
        }
    }

    $decayValue = if ([bool]$settings.DisableBuildingDecay) { 0 } else { 1 }
    Apply-Key "JianZhuFuLanKaiGuan" $decayValue
    Apply-Key "JianZhuFuLanMul" $decayValue
    Apply-Key "ManRenChuZhanCount" ([int]$settings.DeployedTribesmen)
    Apply-Key "XinXiLuRu" ([int]$settings.SavedTribesmen)
    Apply-Key "AnimalFollowerMaxCount" ([int]$settings.AnimalFollowers)
    Apply-Key "AddRenKeDuRatio" ([double]$settings.TamingSpeed)
    Apply-Key "ExpRatio" ([double]$settings.AwarenessXP)
    Apply-Key "ChengZhangExpRatio" ([double]$settings.CharacterXP)
    Apply-Key "ShuLianDuExpRatio" ([double]$settings.ProficiencyXP)
    Apply-Key "TrainingExpRatio" ([double]$settings.TrainingXP)
    foreach ($k in @("CaiJiDiaoLuoRatio","FaMuDiaoLuoRatio","CaiKuangDiaoLuoRatio")) { Apply-Key $k ([double]$settings.Gathering) }
    Apply-Key "ZhiZuoTimeRatio" ([double]$settings.CraftingSpeed)
    Apply-Key "BaoXiangDropRatio" ([double]$settings.ChestLoot)
    Apply-Key "BossRenDiaoLuoRatio" ([double]$settings.BossLoot)
    Apply-Key "NaiJiuXiShu" ([double]$settings.DurabilityLoss)
    Apply-Key "XiuLiXuYaoCaiLiaoRatio" ([double]$settings.RepairMaterialCost)
    Apply-Key "ZuoWuShengZhangRatio" ([double]$settings.CropGrowth)
    Apply-Key "DongWuShengZhangRatio" ([double]$settings.AnimalGrowth)
    Apply-Key "MaxFuZhongRatio" ([double]$settings.CarryWeight)
    Apply-Key "RanLiaoXiaoHaoRatio" ([double]$settings.FuelConsumption)
    Apply-Key "YingHuoRanShaoSuDuRatio" ([double]$settings.BonfireBurnRate)
    Apply-Key "ShiWuXiaoHaoRatio" ([double]$settings.HungerRate)
    Apply-Key "ShuiXiaoHaoRatio" ([double]$settings.ThirstRate)

    switch ([string]$settings.DeathPenalty) {
        "Keep Inventory" { Apply-Key "PlayerDeathCantDropItemKaiGuan" 1; Apply-Key "FuHuoMoveSiWangBaoKaiGuan" 0 }
        "Bag at Respawn" { Apply-Key "PlayerDeathCantDropItemKaiGuan" 0; Apply-Key "FuHuoMoveSiWangBaoKaiGuan" 1 }
        default { Apply-Key "PlayerDeathCantDropItemKaiGuan" 0; Apply-Key "FuHuoMoveSiWangBaoKaiGuan" 0 }
    }

    Apply-Key "JianZhuChuanSongMenPlusKaiGuan" $(if([bool]$settings.PortalResources){1}else{0})
    Apply-Key "SuiJiRuQinKaiGuan" $(if([bool]$settings.RandomAnimalInvasions){1}else{0})
    Apply-Key "RuQinKaiGuan" $(if([bool]$settings.BarbarianInvasions){1}else{0})

    $new = $state.Text
    if ($new -eq $raw) {
        return [PSCustomObject]@{Success=$true;Changed=$false;Reason="AlreadySet";Backup=$null;Missing=@($missing)}
    }

    $backup = $null
    if ($makeBackup) {
        $bd = Join-Path (Split-Path $configPath -Parent) "ManagerBackups"
        New-Item -ItemType Directory -Path $bd -Force | Out-Null
        $backup = Join-Path $bd ("GameXishu_"+(Get-Date -Format "yyyy-MM-dd_HH-mm-ss-fff")+".json")
        Copy-Item $configPath $backup -Force
    }
    [System.IO.File]::WriteAllText($configPath,$new,(New-Object System.Text.UTF8Encoding($false)))
    return [PSCustomObject]@{Success=$true;Changed=$true;Reason="Updated";Backup=$backup;Missing=@($missing)}
}

function Apply-ManagerDefaultsToWorld([string]$world) {
    $settings = Get-PersistentSettingsForWorld $world
    if (-not $settings) { return $true }
    $configPath = Join-Path (Join-Path $Root $world) "WS\Saved\GameplaySettings\GameXishu.json"
    if (-not (Test-Path $configPath)) { return $true }
    $result = Set-AllSettingsInConfig $configPath $settings $true
    return [bool]$result.Success
}

function Get-SoulmaskProcesses {
    $items = @()
    try {
        $procs = Get-CimInstance Win32_Process -Filter "Name='WSServer.exe'" -ErrorAction SilentlyContinue
        foreach ($p in $procs) {
            $world = $null
            $path = [string]$p.ExecutablePath
            $cmd = [string]$p.CommandLine
            foreach ($w in $Worlds) {
                $wp = Join-Path $Root $w
                if (($path -and $path.StartsWith($wp,[System.StringComparison]::OrdinalIgnoreCase)) -or
                    ($cmd -and $cmd.IndexOf($wp,[System.StringComparison]::OrdinalIgnoreCase) -ge 0)) {
                    $world = $w
                    break
                }
            }
            $items += [PSCustomObject]@{
                PID=[int]$p.ProcessId; World=$world; Path=$path; CommandLine=$cmd
            }
        }
    } catch {}
    return $items
}

function Get-RunningWorld {
    $p = Get-SoulmaskProcesses | Where-Object {$_.World} | Select-Object -First 1
    return $p
}

function Get-WorldProcess([string]$world) {
    return Get-SoulmaskProcesses | Where-Object {$_.World -eq $world} | Select-Object -First 1
}

function Get-LauncherPath {
    $world = SelectedWorld
    $path = SelectedPath
    $num = $world.Substring(6,2)
    foreach ($name in @("START - WORLD $num.bat","StartServer.bat")) {
        $candidate = Join-Path $path $name
        if (Test-Path $candidate) { return $candidate }
    }
    $bat = Get-ChildItem $path -Filter "*.bat" -File -ErrorAction SilentlyContinue |
           Where-Object {$_.Name -match "start"} | Select-Object -First 1
    if ($bat) { return $bat.FullName }
    return $null
}

function Find-WorldDB([string]$world) {
    $wp = Join-Path $Root $world
    $mapId = Get-WorldMapId $world
    $direct = Join-Path $wp ("WS\Saved\Worlds\Dedicated\" + $mapId)
    if (Test-Path $direct) {
        $db = Get-ChildItem $direct -Filter "world.db" -File -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($db) { return $db.FullName }
    }
    return $null
}

function Get-LastSaveText([string]$world) {
    $db = Find-WorldDB $world
    if (-not $db) { return "No world.db found yet" }
    $f = Get-Item $db
    return $f.LastWriteTime.ToString("MMM d, yyyy h:mm:ss tt")
}


function Get-SaveState([string]$world) {
    $db = Find-WorldDB $world
    if (-not $db) { return $null }

    $dir = Split-Path $db -Parent
    $files = @(Get-ChildItem $dir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "world.db*" } |
        Sort-Object Name)

    if ($files.Count -eq 0) { return $null }

    $latest = $files | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    $total = ($files | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $total) { $total = 0 }

    $signature = ($files | ForEach-Object {
        "{0}|{1}|{2}" -f…8905 tokens truncated…meXishu.json"
                if (-not (Test-Path $cp)) { $skipped += $w; continue }
                $r = Set-AllSettingsInConfig $cp $settings $true
                if ($r.Success) { $applied += $w } else { $failed += $w }
            }
            Save-ManagerDefaults $settings
            Clear-AllWorldPreferences
            Reload-FromDisk
            Refresh-PrefLabel
            $msg = "Persistent all-world settings saved.`n`nApplied now to: " + ($(if($applied.Count){$applied -join ', '}else{'none'}))
            if ($skipped.Count) { $msg += "`n`nNot initialized yet: " + ($skipped -join ', ') + ". They will use the defaults once their GameXishu.json exists and they are started again." }
            if ($failed.Count) { $msg += "`n`nFailed: " + ($failed -join ', ') }
            [System.Windows.Forms.MessageBox]::Show($msg,"All-World Settings Saved","OK","Information") | Out-Null
        } catch {
            [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,"Apply To All Error","OK","Error") | Out-Null
        }
    })

    $btnSaveAdvanced.Add_Click({
        try {
            $null = $txt.Text | ConvertFrom-Json
            $bd = Join-Path (Split-Path $configPath -Parent) "ManagerBackups"
            New-Item -ItemType Directory -Path $bd -Force | Out-Null
            $backup = Join-Path $bd ("GameXishu_"+(Get-Date -Format "yyyy-MM-dd_HH-mm-ss-fff")+".json")
            Copy-Item $configPath $backup -Force
            [System.IO.File]::WriteAllText($configPath,$txt.Text,(New-Object System.Text.UTF8Encoding($false)))
            Reload-FromDisk
            [System.Windows.Forms.MessageBox]::Show("Advanced JSON saved.`n`nBackup:`n$backup","Saved","OK","Information") | Out-Null
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Invalid JSON. Nothing was written.`n`n$($_.Exception.Message)","Invalid JSON","OK","Error") | Out-Null
        }
    })
    $btnOpenConfig.Add_Click({ Start-Process explorer.exe (Split-Path $configPath -Parent) })
    $btnClose.Add_Click({ $cfg.Close() })
    [void]$cfg.ShowDialog($form)
}

function Open-StartupVideoHelp {
    $modsDefault="C:\Program Files (x86)\Steam\steamapps\common\Soulmask\WS\Content\Paks\~mods"
    $msg="The No-Intro PAK was confirmed to cause an incompatible-version error when this client connected to the local dedicated server.`n`nKeep No-Intro_P.pak disabled for dedicated-server play.`n`nThe manager will not enable, disable, rename, or delete client movie/mod files automatically."
    [System.Windows.Forms.MessageBox]::Show($msg,"Startup Video / No-Intro","OK","Information") | Out-Null
    if (Test-Path $modsDefault) { Start-Process explorer.exe $modsDefault }
}

function Refresh-Status {
    $world=SelectedWorld
    $running=Get-RunningWorld
    $selectedProc=Get-WorldProcess $world

    $lblWorld.Text=$world
    $lblPath.Text=SelectedPath
    $mapSelect.Text="MAP: "+(Get-WorldMapName $world)+"  (CLICK TO SWITCH)"
    $lblLastSave.Text="Last world.db write: "+(Get-LastSaveText $world)

    if ($running) {
        $lblStatus.Text="RUNNING: $($running.World)   PID $($running.PID)"
        $lblStatus.ForeColor=[System.Drawing.Color]::LimeGreen
        if (-not $script:OperationBusy) {
            if ($selectedProc) {
                $lblAction.Text="Connected locally at 127.0.0.1:$GamePort"
            } else {
                $lblAction.Text="$($running.World) is active; stop it before starting $world."
            }
        }
    } else {
        $lblStatus.Text="STOPPED"
        $lblStatus.ForeColor=[System.Drawing.Color]::Gainsboro
        if (-not $script:OperationBusy -and $lblAction.Text -notlike "STOPPED - SAVE*") { $lblAction.Text="Ready" }
    }
    $lblEcho.Text="EchoPort ${EchoPort}: ON-DEMAND ONLY (no polling)"
    $lblEcho.ForeColor=[System.Drawing.Color]::LightGray

    $worldPrefs = Get-WorldPreferences $world
    $defaults = Get-ManagerDefaults
    if ($worldPrefs) {
        $lblDefaults.Text = "Persistent settings: $world has a per-world override"
        $lblDefaults.ForeColor = [System.Drawing.Color]::Khaki
    } elseif ($defaults) {
        $lblDefaults.Text = "Persistent settings: all-world defaults active"
        $lblDefaults.ForeColor = [System.Drawing.Color]::Khaki
    } else {
        $lblDefaults.Text = "Persistent settings: none stored by manager"
        $lblDefaults.ForeColor = [System.Drawing.Color]::LightGray
    }
}

# UI ASSETS / THEME
function Get-UiBackgroundPath {
    $preferred = @(
        (Join-Path $PSScriptRoot "UI image.png"),
        (Join-Path $PSScriptRoot "UI Image.png"),
        (Join-Path $PSScriptRoot "UI_image.png"),
        (Join-Path $PSScriptRoot "UIimage.png")
    )
    foreach ($p in $preferred) { if (Test-Path $p) { return $p } }

    # If the exact preferred name is not present, accept another common image
    # format whose base name is "UI image".
    try {
        $candidate = Get-ChildItem -Path $PSScriptRoot -File -ErrorAction Stop |
            Where-Object { $_.BaseName -ieq "UI image" -and $_.Extension -match '^\.(png|jpg|jpeg|bmp)$' } |
            Select-Object -First 1
        if ($candidate) { return $candidate.FullName }
    } catch {}
    return $null
}

function Load-UnlockedBitmap([string]$path) {
    if (-not $path -or -not (Test-Path $path)) { return $null }
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $stream = New-Object System.IO.MemoryStream(,$bytes)
    try {
        $temp = [System.Drawing.Image]::FromStream($stream)
        try { return New-Object System.Drawing.Bitmap($temp) }
        finally { $temp.Dispose() }
    } finally {
        $stream.Dispose()
    }
}

function Set-ManagerButtonStyle($button,[bool]$primary=$false) {
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.UseVisualStyleBackColor = $false
    $button.ForeColor = [System.Drawing.Color]::White
    if ($primary) {
        $button.BackColor = [System.Drawing.Color]::FromArgb(28,66,72)
        $button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(64,220,230)
    } else {
        $button.BackColor = [System.Drawing.Color]::FromArgb(30,38,43)
        $button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(47,145,154)
    }
    $button.FlatAppearance.BorderSize = 1
    $button.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(42,72,77)
    $button.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(22,54,59)
}

# MAIN WINDOW
$form=New-Object System.Windows.Forms.Form
$form.Text="Soulmask Server Manager v4.6"
$form.Size=New-Object System.Drawing.Size(700,760)
$form.StartPosition="CenterScreen"
$form.FormBorderStyle="FixedSingle"; $form.MaximizeBox=$false
$form.BackColor=[System.Drawing.Color]::FromArgb(13,18,21)

# Load the background from beside the BAT/PS1.  The preferred filename is:
#     UI image.png
$script:UiBackgroundBitmap = $null
$uiBackgroundPath = Get-UiBackgroundPath
if ($uiBackgroundPath) {
    try {
        $script:UiBackgroundBitmap = Load-UnlockedBitmap $uiBackgroundPath
        if ($script:UiBackgroundBitmap) {
            $form.BackgroundImage = $script:UiBackgroundBitmap
            $form.BackgroundImageLayout = [System.Windows.Forms.ImageLayout]::Stretch
        }
    } catch {}
}

# If the desktop icon file is beside the manager, use it for the title bar and taskbar too.
$script:ManagerWindowIcon = $null
$iconPath = Join-Path $PSScriptRoot "Soulmask_Server_Manager.ico"
if (Test-Path $iconPath) {
    try {
        $script:ManagerWindowIcon = New-Object System.Drawing.Icon($iconPath)
        $form.Icon = $script:ManagerWindowIcon
    } catch {}
}

$title=New-Object System.Windows.Forms.Label
$title.Text="SOULMASK SERVER MANAGER v4.6"
$title.Font=New-Object System.Drawing.Font("Segoe UI",18,[System.Drawing.FontStyle]::Bold)
$title.ForeColor=[System.Drawing.Color]::White; $title.AutoSize=$false
$title.BackColor=[System.Drawing.Color]::Transparent
$title.TextAlign="MiddleCenter"
$title.Size=New-Object System.Drawing.Size(620,42)
$title.Location=New-Object System.Drawing.Point(35,14); $form.Controls.Add($title)

$left=New-Object System.Windows.Forms.Button; $left.Text="◀"; $left.Font=New-Object System.Drawing.Font("Segoe UI",18,[System.Drawing.FontStyle]::Bold)
$left.Size=New-Object System.Drawing.Size(70,55); $left.Location=New-Object System.Drawing.Point(100,80); $form.Controls.Add($left)
$lblWorld=New-Object System.Windows.Forms.Label; $lblWorld.TextAlign="MiddleCenter"; $lblWorld.Font=New-Object System.Drawing.Font("Segoe UI",24,[System.Drawing.FontStyle]::Bold)
$lblWorld.ForeColor=[System.Drawing.Color]::White; $lblWorld.BackColor=[System.Drawing.Color]::Transparent; $lblWorld.Size=New-Object System.Drawing.Size(320,55); $lblWorld.Location=New-Object System.Drawing.Point(185,80); $form.Controls.Add($lblWorld)
$right=New-Object System.Windows.Forms.Button; $right.Text="▶"; $right.Font=New-Object System.Drawing.Font("Segoe UI",18,[System.Drawing.FontStyle]::Bold)
$right.Size=New-Object System.Drawing.Size(70,55); $right.Location=New-Object System.Drawing.Point(520,80); $form.Controls.Add($right)

$lblPath=New-Object System.Windows.Forms.Label; $lblPath.TextAlign="MiddleCenter"; $lblPath.Font=New-Object System.Drawing.Font("Consolas",9)
$lblPath.ForeColor=[System.Drawing.Color]::Gainsboro; $lblPath.BackColor=[System.Drawing.Color]::Transparent; $lblPath.Size=New-Object System.Drawing.Size(620,25); $lblPath.Location=New-Object System.Drawing.Point(35,140); $form.Controls.Add($lblPath)

$lblStatus=New-Object System.Windows.Forms.Label; $lblStatus.TextAlign="MiddleCenter"; $lblStatus.Font=New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Bold)
$lblStatus.BackColor=[System.Drawing.Color]::Transparent; $lblStatus.Size=New-Object System.Drawing.Size(620,28); $lblStatus.Location=New-Object System.Drawing.Point(35,170); $form.Controls.Add($lblStatus)

$lblAction=New-Object System.Windows.Forms.Label; $lblAction.TextAlign="MiddleCenter"; $lblAction.ForeColor=[System.Drawing.Color]::Gainsboro; $lblAction.BackColor=[System.Drawing.Color]::Transparent
$lblAction.Size=New-Object System.Drawing.Size(620,26); $lblAction.Location=New-Object System.Drawing.Point(35,198); $form.Controls.Add($lblAction)

$mapSelect=New-Object System.Windows.Forms.Button
$mapSelect.Font=New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
$mapSelect.Size=New-Object System.Drawing.Size(560,34)
$mapSelect.Location=New-Object System.Drawing.Point(65,225)
$form.Controls.Add($mapSelect)

$start=New-Object System.Windows.Forms.Button; $start.Text="START SERVER"; $start.Font=New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Bold)
$start.Size=New-Object System.Drawing.Size(180,48); $start.Location=New-Object System.Drawing.Point(65,270); $form.Controls.Add($start)
$save=New-Object System.Windows.Forms.Button; $save.Text="SAVE WORLD NOW"; $save.Font=New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Bold)
$save.Size=New-Object System.Drawing.Size(180,48); $save.Location=New-Object System.Drawing.Point(255,270); $form.Controls.Add($save)
$stop=New-Object System.Windows.Forms.Button; $stop.Text="STOP SERVER"; $stop.Font=New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Bold)
$stop.Size=New-Object System.Drawing.Size(180,48); $stop.Location=New-Object System.Drawing.Point(445,270); $form.Controls.Add($stop)

$config=New-Object System.Windows.Forms.Button; $config.Text="CONFIGURE WORLD"; $config.Size=New-Object System.Drawing.Size(180,42); $config.Location=New-Object System.Drawing.Point(65,340); $form.Controls.Add($config)
$backup=New-Object System.Windows.Forms.Button; $backup.Text="BACKUP WORLD"; $backup.Size=New-Object System.Drawing.Size(180,42); $backup.Location=New-Object System.Drawing.Point(255,340); $form.Controls.Add($backup)
$launchGame=New-Object System.Windows.Forms.Button; $launchGame.Text="LAUNCH GAME CLIENT"; $launchGame.Size=New-Object System.Drawing.Size(180,42); $launchGame.Location=New-Object System.Drawing.Point(445,340); $form.Controls.Add($launchGame)

$intro=New-Object System.Windows.Forms.Button; $intro.Text="STARTUP VIDEO OPTIONS"; $intro.Size=New-Object System.Drawing.Size(180,42); $intro.Location=New-Object System.Drawing.Point(65,395); $form.Controls.Add($intro)
$openFolder=New-Object System.Windows.Forms.Button; $openFolder.Text="OPEN WORLD FOLDER"; $openFolder.Size=New-Object System.Drawing.Size(180,42); $openFolder.Location=New-Object System.Drawing.Point(255,395); $form.Controls.Add($openFolder)
$openBackups=New-Object System.Windows.Forms.Button; $openBackups.Text="OPEN BACKUPS"; $openBackups.Size=New-Object System.Drawing.Size(180,42); $openBackups.Location=New-Object System.Drawing.Point(445,395); $form.Controls.Add($openBackups)

$resetTest=New-Object System.Windows.Forms.Button
$resetTest.Text="RESET TEST WORLD / NEW CHARACTER"
$resetTest.Font=New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
$resetTest.Size=New-Object System.Drawing.Size(560,42)
$resetTest.Location=New-Object System.Drawing.Point(65,450)
$form.Controls.Add($resetTest)

# Make every main-menu caption readable over the artwork.
Set-ManagerButtonStyle $left
Set-ManagerButtonStyle $right
Set-ManagerButtonStyle $start $true
Set-ManagerButtonStyle $save $true
Set-ManagerButtonStyle $stop $true
Set-ManagerButtonStyle $mapSelect $true
Set-ManagerButtonStyle $config
Set-ManagerButtonStyle $backup
Set-ManagerButtonStyle $launchGame
Set-ManagerButtonStyle $intro
Set-ManagerButtonStyle $openFolder
Set-ManagerButtonStyle $openBackups
Set-ManagerButtonStyle $resetTest
$resetTest.BackColor=[System.Drawing.Color]::FromArgb(68,34,34)
$resetTest.FlatAppearance.BorderColor=[System.Drawing.Color]::FromArgb(220,100,80)
$resetTest.FlatAppearance.MouseOverBackColor=[System.Drawing.Color]::FromArgb(92,44,40)
$resetTest.FlatAppearance.MouseDownBackColor=[System.Drawing.Color]::FromArgb(55,26,26)

$lblLastSave=New-Object System.Windows.Forms.Label; $lblLastSave.TextAlign="MiddleCenter"; $lblLastSave.ForeColor=[System.Drawing.Color]::Gainsboro; $lblLastSave.BackColor=[System.Drawing.Color]::Transparent
$lblLastSave.Size=New-Object System.Drawing.Size(620,24); $lblLastSave.Location=New-Object System.Drawing.Point(35,510); $form.Controls.Add($lblLastSave)
$lblEcho=New-Object System.Windows.Forms.Label; $lblEcho.TextAlign="MiddleCenter"; $lblEcho.BackColor=[System.Drawing.Color]::Transparent; $lblEcho.Size=New-Object System.Drawing.Size(620,24); $lblEcho.Location=New-Object System.Drawing.Point(35,536); $form.Controls.Add($lblEcho)

$lblDefaults=New-Object System.Windows.Forms.Label
$lblDefaults.TextAlign="MiddleCenter"
$lblDefaults.BackColor=[System.Drawing.Color]::Transparent
$lblDefaults.Size=New-Object System.Drawing.Size(620,24)
$lblDefaults.Location=New-Object System.Drawing.Point(35,560)
$form.Controls.Add($lblDefaults)

$hint=New-Object System.Windows.Forms.Label
$hint.Text="Testing: RESET TEST WORLD → START SERVER for a clean character/world | Normal stop: shutdown 5 + backup"
$hint.TextAlign="MiddleCenter"; $hint.ForeColor=[System.Drawing.Color]::Gainsboro; $hint.BackColor=[System.Drawing.Color]::Transparent
$hint.Size=New-Object System.Drawing.Size(620,25); $hint.Location=New-Object System.Drawing.Point(35,615); $form.Controls.Add($hint)

$musicStatus=New-Object System.Windows.Forms.Label
$musicStatus.Text="TRIBAL AUDIO"
$musicStatus.TextAlign="MiddleLeft"
$musicStatus.Font=New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
$musicStatus.ForeColor=[System.Drawing.Color]::Khaki
$musicStatus.BackColor=[System.Drawing.Color]::Transparent
$musicStatus.Size=New-Object System.Drawing.Size(145,30)
$musicStatus.Location=New-Object System.Drawing.Point(65,657)
$form.Controls.Add($musicStatus)

$musicVolume=New-Object System.Windows.Forms.TrackBar
$musicVolume.Minimum=0
$musicVolume.Maximum=100
$musicVolume.TickFrequency=10
$musicVolume.Value=$(Get-ManagerAudioVolume)
$musicVolume.Size=New-Object System.Drawing.Size(245,45)
$musicVolume.Location=New-Object System.Drawing.Point(205,650)
$musicVolume.BackColor=[System.Drawing.Color]::FromArgb(13,18,21)
$form.Controls.Add($musicVolume)

$musicValue=New-Object System.Windows.Forms.Label
$musicValue.Text=($musicVolume.Value.ToString()+"%")
$musicValue.TextAlign="MiddleCenter"
$musicValue.ForeColor=[System.Drawing.Color]::White
$musicValue.BackColor=[System.Drawing.Color]::Transparent
$musicValue.Size=New-Object System.Drawing.Size(55,30)
$musicValue.Location=New-Object System.Drawing.Point(445,657)
$form.Controls.Add($musicValue)

$musicMute=New-Object System.Windows.Forms.Button
$musicMute.Text="MUTE"
$musicMute.Font=New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
$musicMute.Size=New-Object System.Drawing.Size(120,34)
$musicMute.Location=New-Object System.Drawing.Point(505,654)
$form.Controls.Add($musicMute)
Set-ManagerButtonStyle $musicMute

$left.Add_Click({$script:CurrentIndex--;if($CurrentIndex -lt 0){$script:CurrentIndex=$Worlds.Count-1};Refresh-Status})
$right.Add_Click({$script:CurrentIndex++;if($CurrentIndex -ge $Worlds.Count){$script:CurrentIndex=0};Refresh-Status})
$mapSelect.Add_Click({
    if (Get-RunningWorld) {
        [System.Windows.Forms.MessageBox]::Show("Stop the active server before switching maps.","Server Running","OK","Warning") | Out-Null
        return
    }
    $world = SelectedWorld
    $current = Get-WorldMapId $world
    $next = $(if ($current -eq "DLC_Level01_Main") { "Level01_Main" } else { "DLC_Level01_Main" })
    Set-WorldMapId $world $next
    Refresh-Status
    $lblAction.Text = "$world will start "+(Get-WorldMapName $world)
    $lblAction.ForeColor = [System.Drawing.Color]::Gold
})
$musicVolume.Add_ValueChanged({
    $musicValue.Text=$musicVolume.Value.ToString()+"%"
    try { if ($script:ManagerMusic) { $script:ManagerMusic.Volume=([double]$musicVolume.Value/100.0) } } catch {}
})
$musicMute.Add_Click({
    $script:ManagerMusicMuted = -not $script:ManagerMusicMuted
    try { if ($script:ManagerMusic) { $script:ManagerMusic.IsMuted=$script:ManagerMusicMuted } } catch {}
    if ($script:ManagerMusicMuted) {
        $musicMute.Text="UNMUTE"
        $musicMute.BackColor=[System.Drawing.Color]::FromArgb(90,36,36)
    } else {
        $musicMute.Text="MUTE"
        $musicMute.BackColor=[System.Drawing.Color]::FromArgb(30,38,43)
    }
})
$start.Add_Click({Start-SelectedServer})
$save.Add_Click({Save-RunningWorld | Out-Null})
$stop.Add_Click({Stop-RunningServer})
$config.Add_Click({
    try {
        Show-ConfigureWorld
    } catch {
        $msg = "Configure World encountered an error:`n`n" +
               $_.Exception.Message +
               "`n`nLine: " + $_.InvocationInfo.ScriptLineNumber +
               "`nCode: " + $_.InvocationInfo.Line
        [System.Windows.Forms.MessageBox]::Show(
            $msg,
            "Configure World Error",
            "OK",
            "Error"
        ) | Out-Null
    }
})
$backup.Add_Click({Backup-World (SelectedWorld) | Out-Null; Refresh-Status})
$launchGame.Add_Click({Start-Process "steam://rungameid/2646460"})
$intro.Add_Click({Open-StartupVideoHelp})
$openFolder.Add_Click({if(Test-Path (SelectedPath)){Start-Process explorer.exe (SelectedPath)}})
$resetTest.Add_Click({Reset-TestWorld (SelectedWorld) | Out-Null})
$openBackups.Add_Click({
    $p=Join-Path $Root "ManagerBackups"
    New-Item -ItemType Directory -Path $p -Force | Out-Null
    Start-Process explorer.exe $p
})

$timer=New-Object System.Windows.Forms.Timer
$timer.Interval=2500
$timer.Add_Tick({Refresh-Status})
$timer.Start()

Refresh-Status
$form.Add_FormClosed({
    Save-ManagerAudioVolume $musicVolume.Value
    Stop-ManagerMusic
})
Start-ManagerMusic
[void]$form.ShowDialog()

try { if ($script:UiBackgroundBitmap) { $script:UiBackgroundBitmap.Dispose() } } catch {}
try { if ($script:ManagerWindowIcon) { $script:ManagerWindowIcon.Dispose() } } catch {}

