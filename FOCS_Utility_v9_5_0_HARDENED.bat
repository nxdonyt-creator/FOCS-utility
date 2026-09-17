@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title FOCS Utility v9.5.0 - App Installer Build
set "KXTTS_BASEDIR=%~dp0"
set "KXTTS_SELF=%~f0"

fltmc >nul 2>&1
if not "%errorlevel%"=="0" goto :focs_elevate
goto :focs_extract

:focs_elevate
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process -FilePath $env:KXTTS_SELF -Verb RunAs -ErrorAction Stop; exit 0 } catch { exit 1 }"
if not "%errorlevel%"=="0" (
    echo.
    echo FOCS needs administrator rights, and the elevation prompt was cancelled or blocked.
    echo Right-click this file and choose "Run as administrator" to continue.
    pause
)
exit /b

:focs_extract
set "KXTTS_WORK=%LOCALAPPDATA%\FOCS\Payload"
if not exist "%KXTTS_WORK%" mkdir "%KXTTS_WORK%" >nul 2>&1
if not exist "%KXTTS_WORK%" set "KXTTS_WORK=%TEMP%"
set "KXTTS_PS=%KXTTS_WORK%\FOCS_v9_%RANDOM%%RANDOM%.ps1"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$a=Get-Content -LiteralPath $env:KXTTS_SELF -Encoding UTF8; $i=[Array]::IndexOf($a,'#__KXTTS_PS_START__'); if($i -lt 0){exit 3}; $a[($i+1)..($a.Count-1)] | Set-Content -LiteralPath $env:KXTTS_PS -Encoding UTF8"
if not exist "%KXTTS_PS%" (
    echo FOCS could not extract its PowerShell payload.
    pause
    exit /b 3
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; try { [void][scriptblock]::Create((Get-Content -LiteralPath $env:KXTTS_PS -Raw)); exit 0 } catch { Write-Host ''; Write-Host 'FOCS PowerShell payload failed syntax validation:' -ForegroundColor Red; Write-Host $_.Exception.Message -ForegroundColor Red; exit 9 }"
if not "%errorlevel%"=="0" (
    echo.
    echo The extracted debug payload was kept at:
    echo "%KXTTS_PS%"
    pause
    exit /b 9
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%KXTTS_PS%"
set "RC=%ERRORLEVEL%"
del /f /q "%KXTTS_PS%" >nul 2>&1
if not "%RC%"=="0" (
    echo.
    echo FOCS exited with code %RC%.
    echo Check %%LOCALAPPDATA%%\FOCS\Logs for details.
    pause
)
exit /b %RC%

#__KXTTS_PS_START__
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:BaseDir = $env:KXTTS_BASEDIR.TrimEnd('\')
$script:DataRoot = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'FOCS'
$script:LogRoot = Join-Path $script:DataRoot 'Logs'
$script:BenchmarkRoot = Join-Path $script:DataRoot 'Benchmarks'
$script:ReportRoot = Join-Path $script:DataRoot 'Reports'
$script:ToolRoot = Join-Path $script:DataRoot 'Tools'
$script:PresentMonRoot = Join-Path $script:ToolRoot 'PresentMon'
$script:NpiRoot = Join-Path $script:ToolRoot 'NVIDIAProfileInspector'
$script:LatencyMonRoot = Join-Path $script:ToolRoot 'LatencyMon'
$script:LhmRoot = Join-Path $script:ToolRoot 'LibreHardwareMonitor'
$script:LatencyRoot = Join-Path $script:DataRoot 'LatencyDoctor'
$script:ToolCheckFile = Join-Path $script:ToolRoot 'last_tool_check.txt'
$script:ToolStatusLabels = @{}
$script:SelectedProfile = 'Recommended'
$script:LastNpiBackup = $null
$script:BackupRoot = Join-Path ([Environment]::GetFolderPath('Desktop')) 'FOCS_Backups'
$script:LogBox = $null
$script:ScanBox = $null
$script:BaselineCsv = $null
$script:LastAfterCsv = $null
$script:BaselineSet = @()
$script:AfterSet = @()
$script:BenchmarkTelemetryEnabled = $true
$script:LatestLatencyTrace = $null
$script:LatestLatencyReport = $null

foreach ($dir in @($script:DataRoot,$script:LogRoot,$script:BenchmarkRoot,$script:ReportRoot,$script:BackupRoot,$script:ToolRoot,$script:PresentMonRoot,$script:NpiRoot,$script:LatencyMonRoot,$script:LhmRoot,$script:LatencyRoot)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}
$script:LogFile = Join-Path $script:LogRoot ("FOCS_v9_5_0_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

function Write-KLog {
    param([string]$Message)
    $line = '[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $Message
    try { Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 } catch {}
    if ($script:LogBox -and -not $script:LogBox.IsDisposed) {
        $script:LogBox.AppendText($line + "`r`n")
        $script:LogBox.SelectionStart = $script:LogBox.TextLength
        $script:LogBox.ScrollToCaret()
    }
}

function Show-KMessage {
    param(
        [string]$Text,
        [string]$Title = 'FOCS Utility v9.5.0',
        [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::Information
    )
    [void][System.Windows.Forms.MessageBox]::Show($Text,$Title,[System.Windows.Forms.MessageBoxButtons]::OK,$Icon)
}

# ---------------------------------------------------------------------------
# Re-entrancy guard. The GUI is single-threaded and pumps messages with
# DoEvents during long operations, so without this a user can start a second
# run (and a second QoS policy sequence) on top of the first one.
# ---------------------------------------------------------------------------
$script:UiBusy = $false

function Enter-FocsBusy {
    param([string]$What='Operation')
    if ($script:UiBusy) { return $false }
    $script:UiBusy = $true
    try { if ($script:Ui -and $script:Ui.Form -and -not $script:Ui.Form.IsDisposed) { $script:Ui.Form.UseWaitCursor = $true } } catch {}
    Write-KLog "Started: $What"
    return $true
}

function Exit-FocsBusy {
    $script:UiBusy = $false
    try { if ($script:Ui -and $script:Ui.Form -and -not $script:Ui.Form.IsDisposed) { $script:Ui.Form.UseWaitCursor = $false } } catch {}
}

function Set-FocsOutputText {
    param([System.Windows.Forms.TextBox]$Box,[string]$Text)
    if ($Box -and -not $Box.IsDisposed) {
        $Box.Text = $Text
        $Box.SelectionStart = $Box.TextLength
        $Box.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }
}

# ---------------------------------------------------------------------------
# Live pointer-acceleration control. Writing HKCU\Control Panel\Mouse alone
# does nothing until the next sign-in, so FOCS also calls SPI_SETMOUSE.
# ---------------------------------------------------------------------------
function Ensure-FocsMouseParamType {
    if ('FocsMouseParam' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class FocsMouseParam {
    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SystemParametersInfo(uint uiAction, uint uiParam, int[] pvParam, uint fWinIni);
    public static bool ApplyMouse(int[] values) {
        // SPI_SETMOUSE = 0x0004, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE = 0x0003
        return SystemParametersInfo(0x0004, 0, values, 0x0003);
    }
}
'@
}

function Set-FocsPointerAcceleration {
    param([bool]$Enabled)
    try {
        Ensure-FocsMouseParamType
        $vals = if ($Enabled) { [int[]]@(6,10,1) } else { [int[]]@(0,0,0) }
        return [FocsMouseParam]::ApplyMouse($vals)
    } catch {
        Write-KLog "SPI_SETMOUSE call failed: $($_.Exception.Message)"
        return $false
    }
}

# ---------------------------------------------------------------------------
# Download integrity. FOCS runs downloaded binaries elevated, so nothing is
# executed before its publisher digest or Authenticode signature is checked.
# ---------------------------------------------------------------------------
function Test-FocsSignature {
    param([string]$Path,[string[]]$ExpectedSubjectPatterns)
    $sig = $null
    try { $sig = Get-AuthenticodeSignature -LiteralPath $Path -ErrorAction Stop } catch {
        return [pscustomobject]@{ Status='CheckFailed'; Trusted=$false; Subject=''; Reason="Signature check failed: $($_.Exception.Message)" }
    }
    $status = [string]$sig.Status
    $subject = ''
    if ($sig.SignerCertificate) { $subject = [string]$sig.SignerCertificate.Subject }
    if ($status -ne 'Valid') {
        return [pscustomobject]@{ Status=$status; Trusted=$false; Subject=$subject; Reason="Authenticode status: $status" }
    }
    if ($ExpectedSubjectPatterns -and @($ExpectedSubjectPatterns).Count -gt 0) {
        $match = $false
        foreach ($p in @($ExpectedSubjectPatterns)) { if ($subject -match $p) { $match = $true; break } }
        if (-not $match) {
            return [pscustomobject]@{ Status='WrongPublisher'; Trusted=$false; Subject=$subject; Reason="Valid signature, but an unexpected publisher: $subject" }
        }
    }
    return [pscustomobject]@{ Status='Valid'; Trusted=$true; Subject=$subject; Reason="Valid signature: $subject" }
}

function Test-FocsAssetDigest {
    param([string]$Path,[object]$Asset)
    $declared = $null
    try { if ($Asset -and $Asset.PSObject.Properties['digest'] -and $Asset.digest) { $declared = [string]$Asset.digest } } catch {}
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if (-not $declared) {
        return [pscustomobject]@{ Checked=$false; Match=$false; Actual=$actual; Text='GitHub published no digest for this asset; falling back to signature checks.' }
    }
    $expected = ($declared -replace '(?i)^sha256:','').Trim()
    $match = ($actual -ieq $expected)
    $verdict = if ($match) { 'matched' } else { 'MISMATCH' }
    return [pscustomobject]@{ Checked=$true; Match=$match; Actual=$actual; Text=("GitHub digest $verdict (expected $expected, got $actual)") }
}

function Get-KVerifiedDownload {
    param(
        [Parameter(Mandatory=$true)][string]$Uri,
        [Parameter(Mandatory=$true)][string]$Destination,
        [object]$Asset,
        [string[]]$ExpectedSubjectPatterns,
        [switch]$CheckSignature
    )
    $staging = "$Destination.focsdownload"
    Remove-Item -LiteralPath $staging -Force -ErrorAction SilentlyContinue
    Download-KFile -Uri $Uri -Destination $staging
    try {
        $digest = Test-FocsAssetDigest -Path $staging -Asset $Asset
        Write-KLog "Integrity: $($digest.Text)"
        if ($digest.Checked -and -not $digest.Match) {
            throw "The downloaded file does not match the digest published by GitHub. FOCS discarded it rather than running it. Source: $Uri"
        }
        $sig = $null
        if ($CheckSignature) {
            $sig = Test-FocsSignature -Path $staging -ExpectedSubjectPatterns $ExpectedSubjectPatterns
            Write-KLog "Integrity: $($sig.Reason)"
            if (-not $sig.Trusted) {
                throw "The downloaded file failed Authenticode verification and was discarded. $($sig.Reason)"
            }
        }
        # FOCS runs or loads downloaded code while elevated. A TLS URL and a familiar
        # filename are not integrity checks, so require at least one cryptographic trust
        # result: a GitHub-published SHA-256 digest or a valid expected-publisher signature.
        if (-not $digest.Checked -and (-not $sig -or -not $sig.Trusted)) {
            throw "The publisher supplied neither a verifiable SHA-256 digest nor a trusted Authenticode signature. FOCS discarded the download rather than running unverified code. Source: $Uri"
        }
        Move-Item -LiteralPath $staging -Destination $Destination -Force
        return $digest.Actual
    } finally {
        Remove-Item -LiteralPath $staging -Force -ErrorAction SilentlyContinue
    }
}

function Save-KServiceChangeJournal {
    param([string]$Folder,[object[]]$Entries)
    if (-not $Folder -or -not $Entries -or @($Entries).Count -eq 0) { return }
    $path = Join-Path $Folder 'services_changed.json'
    $existing = @()
    if (Test-Path -LiteralPath $path) {
        try { $existing = @(Get-Content -LiteralPath $path -Raw | ConvertFrom-Json) } catch { $existing = @() }
    }
    $all = @($existing) + @($Entries)
    $all | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $path -Encoding UTF8
}
function Invoke-KStep {
    param([string]$Name,[scriptblock]$Action)
    try {
        & $Action
        Write-KLog "${Name}: OK"
        return $true
    } catch {
        Write-KLog "${Name}: FAILED - $($_.Exception.Message)"
        return $false
    }
}

function Set-RegDword {
    param([string]$Path,[string]$Name,[uint32]$Value)
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null
}

function Set-RegString {
    param([string]$Path,[string]$Name,[string]$Value)
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name $Name -PropertyType String -Value $Value -Force | Out-Null
}

function Get-RegValueSnapshot {
    param([string]$Path,[string]$Name)
    $exists = $false
    $kind = $null
    $value = $null
    try {
        $key = Get-Item -LiteralPath $Path -ErrorAction Stop
        if (@($key.GetValueNames()) -contains $Name) {
            $exists = $true
            $kind = $key.GetValueKind($Name).ToString()
            $value = $key.GetValue($Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        }
    } catch {}
    [pscustomobject]@{ Path=$Path; Name=$Name; Exists=$exists; Kind=$kind; Value=$value }
}

function Save-RegValueJournal {
    param([string]$Folder,[object[]]$Targets)
    if (-not $Targets -or $Targets.Count -eq 0) { return }
    $items = foreach ($t in $Targets) { Get-RegValueSnapshot -Path ([string]$t.Path) -Name ([string]$t.Name) }
    $items | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Folder 'registry_value_journal.json') -Encoding UTF8
}

function Save-NetworkState {
    param([string]$Folder)
    try {
        $tcp = Get-NetTCPSetting -SettingName Internet -ErrorAction Stop
        $off = Get-NetOffloadGlobalSetting -ErrorAction Stop
        [pscustomobject]@{
            AutoTuningLevelLocal = [string]$tcp.AutoTuningLevelLocal
            ReceiveSideScaling = [string]$off.ReceiveSideScaling
        } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Folder 'network_state.json') -Encoding UTF8
    } catch { Write-KLog "Network state snapshot unavailable: $($_.Exception.Message)" }
}

function Get-ActivePowerSchemeGuid {
    try {
        $text = (& powercfg.exe /getactivescheme 2>$null | Out-String)
        $m = [regex]::Match($text,'[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}')
        if ($m.Success) { return $m.Value }
    } catch {}
    return $null
}

function Export-RegKeySafe {
    param([string]$Key,[string]$Destination)
    # reg.exe writes a missing-key message to stderr. With the script-wide
    # ErrorActionPreference=Stop, Windows PowerShell turns that message into a
    # terminating error before the exit-code check below can run. Missing policy
    # keys are normal on a clean Windows installation, so contain the native
    # command's error behavior locally and record the skip in the log.
    $previousPreference = $ErrorActionPreference
    $exitCode = 1
    try {
        $ErrorActionPreference = 'Continue'
        & reg.exe export $Key $Destination /y 1>$null 2>$null
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($exitCode -ne 0) { Write-KLog "Backup skipped unavailable registry key: $Key" }
}

function New-KRestoreScript {
    param([string]$Folder)
    $restore = @'
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Continue'
$folder = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host 'FOCS restore starting...'

Get-ChildItem -LiteralPath $folder -Filter '*.reg' -ErrorAction SilentlyContinue | ForEach-Object {
    & reg.exe import $_.FullName | Out-Null
}

$journalFile = Join-Path $folder 'registry_value_journal.json'
if (Test-Path -LiteralPath $journalFile) {
    $items = @(Get-Content -LiteralPath $journalFile -Raw | ConvertFrom-Json)
    foreach ($item in $items) {
        if ($item.Exists) {
            if (-not (Test-Path -LiteralPath $item.Path)) { New-Item -Path $item.Path -Force | Out-Null }
            New-ItemProperty -Path $item.Path -Name $item.Name -PropertyType $item.Kind -Value $item.Value -Force -ErrorAction SilentlyContinue | Out-Null
        } else {
            Remove-ItemProperty -LiteralPath $item.Path -Name $item.Name -ErrorAction SilentlyContinue
        }
    }
}

$networkFile = Join-Path $folder 'network_state.json'
if (Test-Path -LiteralPath $networkFile) {
    try {
        $net = Get-Content -LiteralPath $networkFile -Raw | ConvertFrom-Json
        if ($net.AutoTuningLevelLocal) { Set-NetTCPSetting -SettingName Internet -AutoTuningLevelLocal $net.AutoTuningLevelLocal -ErrorAction SilentlyContinue }
        if ($net.ReceiveSideScaling) { Set-NetOffloadGlobalSetting -ReceiveSideScaling $net.ReceiveSideScaling -ErrorAction SilentlyContinue }
    } catch { Write-Host "Network state restore failed: $($_.Exception.Message)" }
}

# Only the services FOCS actually changed are replayed. services_inventory.csv is kept as a
# read-only reference so that restoring never reverts unrelated service changes made by
# Windows Update, another tool, or you.
$changedFile = Join-Path $folder 'services_changed.json'
if (Test-Path -LiteralPath $changedFile) {
    try {
        $changed = @(Get-Content -LiteralPath $changedFile -Raw | ConvertFrom-Json)
        foreach ($svc in $changed) {
            $startup = switch ([string]$svc.StartMode) {
                'Auto'      { 'Automatic' }
                'Automatic' { 'Automatic' }
                'Manual'    { 'Manual' }
                'Disabled'  { 'Disabled' }
                default     { $null }
            }
            if ($startup -and $svc.Name) {
                Set-Service -Name ([string]$svc.Name) -StartupType $startup -ErrorAction SilentlyContinue
                Write-Host "Service restored: $($svc.Name) -> $startup"
            }
        }
    } catch { Write-Host "Service restore failed: $($_.Exception.Message)" }
}

# Remove the FOCS outbound QoS guard if one survived, including a trial cap left behind by a
# reducer run that was interrupted.
try {
    if (Get-Command Remove-NetQosPolicy -ErrorAction SilentlyContinue) {
        $q = @(Get-NetQosPolicy -Name 'FOCS Bufferbloat Upload Guard' -ErrorAction SilentlyContinue)
        foreach ($p in $q) { $p | Remove-NetQosPolicy -Confirm:$false -ErrorAction SilentlyContinue }
        if ($q.Count -gt 0) { Write-Host 'FOCS outbound QoS upload guard removed.' }
    }
} catch { Write-Host 'QoS guard removal was not possible on this system.' }

$powerFile = Join-Path $folder 'power.txt'
if (Test-Path -LiteralPath $powerFile) {
    $t = Get-Content -LiteralPath $powerFile -Raw
    $m = [regex]::Match($t,'[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}')
    if ($m.Success) { & powercfg.exe /setactive $m.Value | Out-Null }
}
Write-Host 'FOCS restore complete. Restart Windows before retesting.'
Read-Host 'Press Enter to close'
'@
    Set-Content -LiteralPath (Join-Path $Folder 'RESTORE_FOCS.ps1') -Value $restore -Encoding UTF8
}

function New-KBackup {
    $folder = Join-Path $script:BackupRoot ("Backup_{0}" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
    New-Item -ItemType Directory -Path $folder -Force | Out-Null

    $keys = @(
        'HKCU\Software\Microsoft\GameBar',
        'HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR',
        'HKCU\System\GameConfigStore',
        'HKCU\Control Panel\Mouse',
        'HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager',
        'HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo',
        'HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy',
        'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize',
        'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced',
        'HKCU\SOFTWARE\Policies\Microsoft\Windows\Explorer',
        'HKCU\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot',
        'HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers',
        'HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization',
        'HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent',
        'HKLM\SOFTWARE\Policies\Microsoft\Windows\System',
        'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI',
        'HKLM\SOFTWARE\Policies\Microsoft\Dsh',
        'HKLM\SOFTWARE\Policies\Microsoft\Edge',
        'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile',
        'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
    )
    foreach ($key in $keys) {
        $safe = ($key -replace '[\\/:*?"<>| ]','_') + '.reg'
        Export-RegKeySafe -Key $key -Destination (Join-Path $folder $safe)
    }

    try { & powercfg.exe /getactivescheme | Set-Content -LiteralPath (Join-Path $folder 'power.txt') -Encoding UTF8 } catch { Write-KLog "Power scheme snapshot failed: $($_.Exception.Message)" }
    try { & netsh.exe interface tcp show global | Set-Content -LiteralPath (Join-Path $folder 'tcp.txt') -Encoding UTF8 } catch { Write-KLog "TCP global snapshot failed: $($_.Exception.Message)" }
    try { & bcdedit.exe /enum all | Set-Content -LiteralPath (Join-Path $folder 'bcd.txt') -Encoding UTF8 } catch { Write-KLog "BCD text snapshot failed: $($_.Exception.Message)" }
    try { & bcdedit.exe /export (Join-Path $folder 'bcd_store.bak') 1>$null 2>$null } catch { Write-KLog "BCD store export failed: $($_.Exception.Message)" }
    try {
        # Reference inventory only. RESTORE_FOCS.ps1 deliberately does not replay this file,
        # because blanket-restoring every service start type would also undo unrelated changes.
        Get-CimInstance Win32_Service | Select-Object Name,DisplayName,StartMode,State |
            Export-Csv -LiteralPath (Join-Path $folder 'services_inventory.csv') -NoTypeInformation -Encoding UTF8
    } catch { Write-KLog "Service inventory snapshot failed: $($_.Exception.Message)" }

    New-KRestoreScript -Folder $folder
    Write-KLog "Backup saved: $folder"
    return $folder
}

function Get-SystemSummary {
    $os = Get-CimInstance Win32_OperatingSystem | Select-Object -First 1
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $gpus = @(Get-CimInstance Win32_VideoController | Sort-Object { if ($_.Name -match 'NVIDIA|AMD|Radeon|Intel Arc') {0} else {1} })
    $gpu = $gpus | Select-Object -First 1
    $ramGb = [math]::Round(([double]$os.TotalVisibleMemorySize / 1MB),1)
    $activeScheme = Get-ActivePowerSchemeGuid

    $vendor = 'Unknown'
    if ($gpu.Name -match 'NVIDIA') { $vendor = 'NVIDIA' }
    elseif ($gpu.Name -match 'AMD|Radeon') { $vendor = 'AMD' }
    elseif ($gpu.Name -match 'Intel') { $vendor = 'Intel' }

    $hags = 'Default/unknown'
    try {
        $v = (Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name HwSchMode -ErrorAction Stop).HwSchMode
        if ($v -eq 2) { $hags = 'On (registry request)' }
        elseif ($v -eq 1) { $hags = 'Off (registry request)' }
        else { $hags = "Value $v" }
    } catch {}

    $driver = if ($gpu.DriverVersion) { $gpu.DriverVersion } else { 'Unknown' }
    try {
        $smi = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
        if ($smi) {
            $d = (& $smi.Source --query-gpu=driver_version --format=csv,noheader 2>$null | Select-Object -First 1)
            if ($d) { $driver = $d.Trim() }
        }
    } catch {}

    [pscustomobject]@{
        OS = $os.Caption
        Build = $os.BuildNumber
        CPU = $cpu.Name
        RAM = $ramGb
        GPU = $gpu.Name
        Vendor = $vendor
        Driver = $driver
        HAGS = $hags
        PowerScheme = $activeScheme
    }
}

function Get-BcdTimerReport {
    $lines = @()
    try {
        $text = (& bcdedit.exe /enum '{current}' 2>&1 | Out-String)
        $checks = @('useplatformclock','useplatformtick','disabledynamictick','tscsyncpolicy')
        foreach ($name in $checks) {
            $m = [regex]::Match($text,"(?im)^\s*$name\s+(.+)$")
            if ($m.Success) { $lines += "$name = $($m.Groups[1].Value.Trim())" }
        }
        if ($lines.Count -eq 0) { return 'No common forced timer overrides detected in the current BCD entry.' }
        return "Forced/non-default timer-related BCD entries detected:`r`n  " + ($lines -join "`r`n  ") + "`r`nFOCS does not automatically change BCD values."
    } catch {
        return "BCD scan failed: $($_.Exception.Message)"
    }
}

function Get-NicReport {
    $out = [System.Collections.Generic.List[string]]::new()
    try {
        $adapters = @(Get-NetAdapter -Physical -ErrorAction Stop | Where-Object Status -ne 'Disabled')
        if ($adapters.Count -eq 0) { return 'No enabled physical network adapters found.' }
        foreach ($a in $adapters) {
            $out.Add("[$($a.Name)] $($a.InterfaceDescription) | Link: $($a.LinkSpeed)")
            try {
                $props = Get-NetAdapterAdvancedProperty -Name $a.Name -ErrorAction Stop | Where-Object {
                    $_.DisplayName -match 'Interrupt|RSS|Receive Side|Energy Efficient|Green Ethernet|Power|Flow Control|Offload'
                }
                foreach ($p in $props) {
                    $valid = @($p.ValidDisplayValues) | Where-Object { $_ }
                    if ($valid.Count -gt 0 -and $valid.Count -le 12) {
                        $out.Add("  $($p.DisplayName): $($p.DisplayValue) | Valid: $($valid -join ', ')")
                    } else {
                        $out.Add("  $($p.DisplayName): $($p.DisplayValue)")
                    }
                }
                try {
                    $rss = Get-NetAdapterRss -Name $a.Name -ErrorAction Stop
                    $out.Add("  RSS enabled: $($rss.Enabled) | Queues: $($rss.NumberOfReceiveQueues)")
                } catch {}
            } catch { $out.Add('  Advanced properties unavailable through NetAdapter cmdlets.') }
        }
    } catch { return "NIC scan failed: $($_.Exception.Message)" }
    return ($out -join "`r`n")
}

function Get-MsiReport {
    $out = [System.Collections.Generic.List[string]]::new()
    try {
        $devices = @()
        try { $devices += @(Get-PnpDevice -Class Display -Status OK -ErrorAction Stop) } catch {}
        try { $devices += @(Get-PnpDevice -Class Net -Status OK -ErrorAction Stop | Where-Object FriendlyName -notmatch 'Bluetooth|WAN Miniport') } catch {}
        if ($devices.Count -eq 0) { return 'No Display/Net PnP devices were available for MSI inspection.' }
        foreach ($d in $devices) {
            $reg = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($d.InstanceId)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
            $state = 'not explicitly exposed'
            try {
                $v = (Get-ItemProperty -LiteralPath $reg -Name MSISupported -ErrorAction Stop).MSISupported
                if ($v -eq 1) { $state = 'MSISupported=1' }
                elseif ($v -eq 0) { $state = 'MSISupported=0' }
                else { $state = "MSISupported=$v" }
            } catch {}
            $out.Add("$($d.Class): $($d.FriendlyName) -> $state")
        }
        $out.Add('FOCS intentionally does not force MSI/MSI-X on devices that have not declared a compatible setting.')
    } catch { return "MSI scan failed: $($_.Exception.Message)" }
    return ($out -join "`r`n")
}

function Get-DiagnosticReport {
    $s = Get-SystemSummary
    $lines = @()
    $lines += "Windows: $($s.OS) build $($s.Build)"
    $lines += "CPU: $($s.CPU)"
    $lines += "RAM: $($s.RAM) GB"
    $lines += "GPU: $($s.GPU) | Vendor: $($s.Vendor) | Driver: $($s.Driver)"
    $lines += "HAGS: $($s.HAGS)"
    $lines += "Active power scheme: $($s.PowerScheme)"
    $lines += ''
    $lines += (Get-BcdTimerReport)
    $lines += ''
    $lines += 'NETWORK ADAPTERS'
    $lines += (Get-NicReport)
    $lines += ''
    $lines += 'MSI/MSI-X VISIBILITY'
    $lines += (Get-MsiReport)
    $lines += ''
    $lines += 'SECURITY POLICY'
    $lines += 'FOCS does not disable Defender, Windows Update, VBS/Memory Integrity, firewall, RPC, DHCP, DNS Client, audio, Plug and Play, or other core security/system services.'
    return ($lines -join "`r`n")
}

function Export-DiagnosticReport {
    $path = Join-Path $script:ReportRoot ("FOCS_Diagnostic_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
    $header = @()
    $header += 'FOCS Utility v9.5.0 diagnostic report'
    $header += ('Generated: {0}' -f (Get-Date))
    $header += ('Log file: {0}' -f $script:LogFile)
    $header += ''
    ($header -join "`r`n") + (Get-DiagnosticReport) | Set-Content -LiteralPath $path -Encoding UTF8
    Write-KLog "Diagnostic report exported: $path"
    return $path
}

function Test-NetworkLatency {
    param(
        [string]$HostName,
        [int]$Count=20,
        [int]$TimeoutMs=1200,
        [int]$IntervalMs=120,
        [Nullable[datetime]]$Deadline=$null
    )
    if ([string]::IsNullOrWhiteSpace($HostName)) { throw 'Enter a host name or IP address.' }
    if ($Count -lt 5) { $Count = 5 }
    if ($Count -gt 200) { $Count = 200 }
    if ($IntervalMs -lt 0) { $IntervalMs = 0 }
    $times = [System.Collections.Generic.List[double]]::new()
    $failed = 0
    $attempts = 0
    $truncated = $false
    $pinger = New-Object System.Net.NetworkInformation.Ping
    try {
        for ($i=0; $i -lt $Count; $i++) {
            # A Deadline lets a caller guarantee the probe finishes while the load it is
            # measuring is still running, instead of drifting past the end of the load window.
            if ($Deadline -and (Get-Date) -ge $Deadline) { $truncated = $true; break }
            $attempts++
            try {
                $reply = $pinger.Send($HostName,$TimeoutMs)
                if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) { $times.Add([double]$reply.RoundtripTime) } else { $failed++ }
            } catch { $failed++ }
            if ($i -lt ($Count-1)) { Start-Sleep -Milliseconds $IntervalMs }
            [System.Windows.Forms.Application]::DoEvents()
        }
    } finally { $pinger.Dispose() }
    if ($times.Count -eq 0) { throw "No successful replies from $HostName." }
    $stats = Get-Stats -Values $times.ToArray()
    $jitterValues = [System.Collections.Generic.List[double]]::new()
    for ($i=1; $i -lt $times.Count; $i++) { $jitterValues.Add([math]::Abs($times[$i]-$times[$i-1])) }
    $jitter = if ($jitterValues.Count -gt 0) { ($jitterValues | Measure-Object -Average).Average } else { 0 }
    $loss = if ($attempts -gt 0) { 100.0 * $failed / $attempts } else { 0.0 }
    $sortedTimes = @($times.ToArray() | Sort-Object)
    $p95Index = [Math]::Max(0,[Math]::Min($sortedTimes.Count-1,[Math]::Ceiling($sortedTimes.Count*0.95)-1))
    $p95 = if($sortedTimes.Count -gt 0){[double]$sortedTimes[$p95Index]}else{9999}
    return [pscustomobject]@{ Host=$HostName; Sent=$attempts; Requested=$Count; Truncated=$truncated; Received=$times.Count; LossPct=$loss; Min=$stats.Min; Avg=$stats.Avg; Median=$stats.Median; Max=$stats.Max; P95=$p95; Jitter=$jitter; StdDev=$stats.StdDev }
}

function Get-FocsProbeSeconds {
    param([int]$Count,[double]$ExpectedRttMs,[int]$IntervalMs=120)
    # How long a ping probe of $Count samples will actually take, so callers can size the
    # traffic load around it rather than guessing a fixed number of seconds.
    $perSample = [Math]::Max(20.0,[double]$ExpectedRttMs) + [double]$IntervalMs
    return ([int][Math]::Ceiling(($Count * $perSample) / 1000.0) + 3)
}

function Format-NetworkLatency {
    param([object]$Result)
    @("Host: $($Result.Host)",
      ('Sent/received: {0}/{1} | Loss: {2:N1}%' -f $Result.Sent,$Result.Received,$Result.LossPct),
      ('Latency min/avg/median/max: {0:N1} / {1:N1} / {2:N1} / {3:N1} ms' -f $Result.Min,$Result.Avg,$Result.Median,$Result.Max),
      ('P95 latency: {0:N1} ms' -f $Result.P95),
      ('Average successive-sample jitter: {0:N1} ms' -f $Result.Jitter),
      ('Latency standard deviation: {0:N1} ms' -f $Result.StdDev),
      'This measures the path to the selected host, not game-server processing or input latency.') -join "`r`n"
}

function Get-FocsGamingLatencyState {
    param([double]$P95,[double]$LossPct=0)
    if($LossPct -gt 0.5){return 'FAIL'}
    if($P95 -lt 40.0){return 'PASS'}
    if($P95 -lt 60.0){return 'WARN'}
    return 'FAIL'
}

function Format-FocsGamingGate {
    param([double]$P95,[double]$LossPct=0)
    $state=Get-FocsGamingLatencyState -P95 $P95 -LossPct $LossPct
    return ("{0} - P95 {1:N1} ms, loss {2:N1}%" -f $state,$P95,$LossPct)
}

function Apply-SafeTweaks {
    param([hashtable]$Controls)
    $backup = New-KBackup
    $targets = @()
    if ($Controls.GameMode.Checked) {
        $targets += @{Path='HKCU:\Software\Microsoft\GameBar';Name='AllowAutoGameMode'}
        $targets += @{Path='HKCU:\Software\Microsoft\GameBar';Name='AutoGameModeEnabled'}
        $targets += @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR';Name='AppCaptureEnabled'}
        $targets += @{Path='HKCU:\System\GameConfigStore';Name='GameDVR_Enabled'}
    }
    if ($Controls.Mouse.Checked) {
        $targets += @{Path='HKCU:\Control Panel\Mouse';Name='MouseSpeed'}
        $targets += @{Path='HKCU:\Control Panel\Mouse';Name='MouseThreshold1'}
        $targets += @{Path='HKCU:\Control Panel\Mouse';Name='MouseThreshold2'}
    }
    if ($Controls.Delivery.Checked) { $targets += @{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization';Name='DODownloadMode'} }
    Save-RegValueJournal -Folder $backup -Targets $targets
    if ($Controls.Network.Checked) { Save-NetworkState -Folder $backup }

    $ok = 0
    $fail = 0

    if ($Controls.GameMode.Checked) {
        if (Invoke-KStep 'Game Mode on and Game DVR capture off' {
            Set-RegDword 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1
            Set-RegDword 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
            Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
            Set-RegDword 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
        }) { $ok++ } else { $fail++ }
    }

    if ($Controls.Mouse.Checked) {
        if (Invoke-KStep 'Windows pointer acceleration off' {
            Set-RegString 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '0'
            Set-RegString 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0'
            Set-RegString 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0'
            # The registry values alone take effect only at the next sign-in, so push the
            # change into the live session as well.
            if (-not (Set-FocsPointerAcceleration -Enabled $false)) {
                throw 'Registry values were written, but Windows did not accept the live pointer-acceleration change. Sign out and back in to apply it.'
            }
        }) { $ok++ } else { $fail++ }
    }

    if ($Controls.Delivery.Checked) {
        if (Invoke-KStep 'Delivery Optimization peer-to-peer off' {
            Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 0
        }) { $ok++ } else { $fail++ }
    }

    if ($Controls.Network.Checked) {
        if (Invoke-KStep 'Network conservative baseline' {
            & netsh.exe interface tcp set global autotuninglevel=normal | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'Failed to set TCP autotuning to normal.' }
            & netsh.exe interface tcp set global rss=enabled | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'Failed to enable RSS.' }
            & ipconfig.exe /flushdns | Out-Null
        }) { $ok++ } else { $fail++ }
    }

    Write-KLog "Safe apply complete. OK=$ok Failed=$fail Backup=$backup"
    if ($fail -eq 0) {
        Show-KMessage "Selected safe tweaks were applied.`r`n`r`nBackup: $backup`r`nRestart Windows before comparing benchmark results."
    } else {
        Show-KMessage "FOCS finished with $fail failed group(s).`r`nBackup: $backup`r`nLog: $script:LogFile" 'FOCS Utility v9.5.0' ([System.Windows.Forms.MessageBoxIcon]::Warning)
    }
}

function Apply-HagsChoice {
    param([string]$Choice)
    $backup = New-KBackup
    Save-RegValueJournal -Folder $backup -Targets @(@{Path='HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers';Name='HwSchMode'})
    if ($Choice -eq 'Enable HAGS') {
        Set-RegDword 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2
        Write-KLog 'HAGS registry request set to enabled.'
    } elseif ($Choice -eq 'Disable HAGS') {
        Set-RegDword 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 1
        Write-KLog 'HAGS registry request set to disabled.'
    } else {
        Show-KMessage 'Choose Enable HAGS or Disable HAGS first.' 'FOCS Experimental' ([System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    Show-KMessage "HAGS choice applied. Restart required.`r`n`r`nBackup: $backup`r`nBenchmark both states on the same workload."
}

function Find-NvidiaProfileInspector {
    $candidates = @(
        (Join-Path $script:NpiRoot 'nvidiaProfileInspector.exe'),
        (Join-Path $script:BaseDir 'nvidiaProfileInspector.exe'),
        (Join-Path $env:ProgramFiles 'NVIDIA Corporation\NVIDIA Profile Inspector\nvidiaProfileInspector.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'NVIDIA Corporation\NVIDIA Profile Inspector\nvidiaProfileInspector.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\NVIDIA Profile Inspector\nvidiaProfileInspector.exe'),
        (Join-Path $env:ProgramData 'chocolatey\lib\nvidia-profile-inspector\tools\nvidiaProfileInspector.exe'),
        (Join-Path $env:USERPROFILE 'NVPI\nvidiaProfileInspector.exe')
    )
    foreach ($p in $candidates) { if ($p -and (Test-Path -LiteralPath $p)) { return $p } }
    $cmd = Get-Command nvidiaProfileInspector.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Import-NvidiaProfileWithBackup {
    param([string]$ProfilePath)
    $npi = Find-NvidiaProfileInspector
    if (-not $npi) { throw 'nvidiaProfileInspector.exe was not found. Put it next to this BAT file or install it in a detectable location.' }
    if (-not (Test-Path -LiteralPath $ProfilePath)) { throw 'Selected .nip file does not exist.' }

    $backupDir = Join-Path $script:BackupRoot ("NPI_Backup_{0}" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    $npiDir = Split-Path -Parent $npi
    $before = @{}
    Get-ChildItem -LiteralPath $npiDir -Filter '*.nip' -ErrorAction SilentlyContinue | ForEach-Object { $before[$_.FullName] = $_.LastWriteTimeUtc }

    $export = Start-Process -FilePath $npi -ArgumentList '-exportCustomized' -WorkingDirectory $npiDir -PassThru -Wait
    if ($export.ExitCode -ne 0) { Write-KLog "NPI customized-profile export returned exit code $($export.ExitCode)." }
    Start-Sleep -Milliseconds 400

    $copied = 0
    Get-ChildItem -LiteralPath $npiDir -Filter '*.nip' -ErrorAction SilentlyContinue | ForEach-Object {
        $isNew = (-not $before.ContainsKey($_.FullName)) -or ($_.LastWriteTimeUtc -gt $before[$_.FullName])
        if ($isNew) {
            Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $backupDir $_.Name) -Force
            $copied++
        }
    }
    Write-KLog "NPI customized-profile backup requested. Copied $copied exported .nip file(s) to $backupDir"

    Start-Process -FilePath $npi -ArgumentList ('"' + $ProfilePath + '"') -WorkingDirectory $npiDir
    Show-KMessage "NVIDIA Profile Inspector opened the selected profile interactively.`r`n`r`nCustomized-profile backup folder:`r`n$backupDir`r`n`r`nReview Merge/Replace choices in NPI before applying."
}

function Test-FocsPresentMonConsoleExe {
    param([string]$Path)
    if([string]::IsNullOrWhiteSpace($Path) -or -not(Test-Path -LiteralPath $Path)){return $false}
    $out=Join-Path $env:TEMP ('FOCS_PM_HELP_'+[guid]::NewGuid().ToString('N')+'.out.txt')
    $err=Join-Path $env:TEMP ('FOCS_PM_HELP_'+[guid]::NewGuid().ToString('N')+'.err.txt')
    try{
        $p=Start-Process -FilePath $Path -ArgumentList '--help' -PassThru -Wait -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err
        $txt=''
        if(Test-Path -LiteralPath $out){$txt+=(Get-Content -LiteralPath $out -Raw -ErrorAction SilentlyContinue)}
        if(Test-Path -LiteralPath $err){$txt+="`r`n"+(Get-Content -LiteralPath $err -Raw -ErrorAction SilentlyContinue)}
        return ($txt -match '--process_name' -and $txt -match '--process_id' -and $txt -match '--output_file')
    }catch{return $false}
    finally{Remove-Item -LiteralPath $out,$err -Force -ErrorAction SilentlyContinue}
}

function Find-PresentMon {
    if($script:PresentMonConsolePath -and (Test-Path -LiteralPath $script:PresentMonConsolePath)){
        if(Test-FocsPresentMonConsoleExe -Path $script:PresentMonConsolePath){return $script:PresentMonConsolePath}
        $script:PresentMonConsolePath=$null
    }
    $candidates=[System.Collections.Generic.List[string]]::new()
    try{foreach($f in @(Get-ChildItem -LiteralPath $script:PresentMonRoot -Filter 'PresentMon-*-x64.exe' -File -ErrorAction SilentlyContinue|Sort-Object LastWriteTime -Descending)){$candidates.Add($f.FullName)}}catch{}
    try{foreach($f in @(Get-ChildItem -LiteralPath $script:BaseDir -Filter 'PresentMon-*-x64.exe' -File -ErrorAction SilentlyContinue|Sort-Object LastWriteTime -Descending)){$candidates.Add($f.FullName)}}catch{}
    try{
        $intelRoot=Join-Path $env:ProgramFiles 'Intel\PresentMon'
        if(Test-Path -LiteralPath $intelRoot){foreach($f in @(Get-ChildItem -LiteralPath $intelRoot -Filter 'PresentMon-*-x64.exe' -File -Recurse -ErrorAction SilentlyContinue|Sort-Object LastWriteTime -Descending)){$candidates.Add($f.FullName)}}
    }catch{}
    $seen=@{}
    foreach($p in $candidates){
        if([string]::IsNullOrWhiteSpace($p)){continue};$k=$p.ToLowerInvariant();if($seen.ContainsKey($k)){continue};$seen[$k]=$true
        if(Test-FocsPresentMonConsoleExe -Path $p){$script:PresentMonConsolePath=$p;return $p}
    }
    return $null
}

function Get-NumericColumn {
    param([object[]]$Rows,[string[]]$Names)
    foreach ($name in $Names) {
        if ($Rows.Count -gt 0 -and $Rows[0].PSObject.Properties.Name -contains $name) {
            $values = [System.Collections.Generic.List[double]]::new()
            foreach ($r in $Rows) {
                $raw = [string]$r.$name
                if ($raw -and $raw -ne 'NA') {
                    $d = 0.0
                    if ([double]::TryParse($raw,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$d)) {
                        if ($d -ge 0) { $values.Add($d) }
                    }
                }
            }
            return ,$values.ToArray()
        }
    }
    return @()
}

function Get-Percentile {
    param([double[]]$Values,[double]$P)
    if (-not $Values -or $Values.Count -eq 0) { return $null }
    $s = @($Values | Sort-Object)
    $idx = [math]::Ceiling(($P / 100.0) * $s.Count) - 1
    if ($idx -lt 0) { $idx = 0 }
    if ($idx -ge $s.Count) { $idx = $s.Count - 1 }
    return [double]$s[$idx]
}

function Get-Stats {
    param([double[]]$Values)
    if (-not $Values -or $Values.Count -eq 0) { return $null }
    $avg = ($Values | Measure-Object -Average).Average
    $sum = 0.0
    foreach ($v in $Values) { $sum += [math]::Pow(($v - $avg),2) }
    $sd = [math]::Sqrt($sum / [math]::Max(1,$Values.Count))
    [pscustomobject]@{
        Count = $Values.Count
        Min = [double](($Values | Measure-Object -Minimum).Minimum)
        Max = [double](($Values | Measure-Object -Maximum).Maximum)
        Avg = [double]$avg
        Median = Get-Percentile -Values $Values -P 50
        P95 = Get-Percentile -Values $Values -P 95
        P99 = Get-Percentile -Values $Values -P 99
        P999 = Get-Percentile -Values $Values -P 99.9
        StdDev = $sd
    }
}

function Get-FocsWorstPercentAverageFps {
    param([double[]]$FrameTimes,[double]$Percent)
    if (-not $FrameTimes -or $FrameTimes.Count -lt 2 -or $Percent -le 0) { return 0.0 }
    $sorted = @($FrameTimes | Sort-Object -Descending)
    $take = [Math]::Max(1,[Math]::Ceiling($sorted.Count * ($Percent / 100.0)))
    $worst = @($sorted | Select-Object -First $take)
    $avg = ($worst | Measure-Object -Average).Average
    if ($avg -gt 0) { return (1000.0 / [double]$avg) }
    return 0.0
}

function Get-FocsMedianNumber {
    param([double[]]$Values)
    if (-not $Values -or $Values.Count -eq 0) { return 0.0 }
    return [double](Get-Percentile -Values $Values -P 50)
}

function Get-FocsRelativeMadPct {
    param([double[]]$Values)
    if (-not $Values -or $Values.Count -lt 2) { return 0.0 }
    $m = Get-FocsMedianNumber $Values
    if ([Math]::Abs($m) -lt 0.000001) { return 0.0 }
    $dev = @($Values | ForEach-Object { [Math]::Abs([double]$_ - $m) })
    $mad = Get-FocsMedianNumber $dev
    return (100.0 * $mad / [Math]::Abs($m))
}

function Get-FocsTelemetrySummary {
    param([string]$CsvPath)
    $path = [IO.Path]::ChangeExtension($CsvPath,'.telemetry.csv')
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    try {
        $rows = @(Import-Csv -LiteralPath $path)
        if ($rows.Count -eq 0) { return $null }
        function _nums([string]$n) {
            $vals=[System.Collections.Generic.List[double]]::new()
            foreach($r in $rows){
                $raw=[string]$r.$n;$d=0.0
                if($raw -and [double]::TryParse($raw,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$d)){$vals.Add($d)}
            }
            return ,$vals.ToArray()
        }
        $cpuTemp=_nums 'CpuTempC';$gpuTemp=_nums 'GpuTempC';$cpuLoad=_nums 'CpuLoadPct';$gpuLoad=_nums 'GpuLoadPct';$cpuClock=_nums 'CpuClockMHz';$gpuClock=_nums 'GpuClockMHz';$cpuPower=_nums 'CpuPowerW';$gpuPower=_nums 'GpuPowerW'
        [pscustomobject]@{
            Samples=$rows.Count
            CpuTempMax=if($cpuTemp.Count){($cpuTemp|Measure-Object -Maximum).Maximum}else{$null}
            GpuTempMax=if($gpuTemp.Count){($gpuTemp|Measure-Object -Maximum).Maximum}else{$null}
            CpuLoadAvg=if($cpuLoad.Count){($cpuLoad|Measure-Object -Average).Average}else{$null}
            GpuLoadAvg=if($gpuLoad.Count){($gpuLoad|Measure-Object -Average).Average}else{$null}
            CpuClockAvg=if($cpuClock.Count){($cpuClock|Measure-Object -Average).Average}else{$null}
            GpuClockAvg=if($gpuClock.Count){($gpuClock|Measure-Object -Average).Average}else{$null}
            CpuPowerAvg=if($cpuPower.Count){($cpuPower|Measure-Object -Average).Average}else{$null}
            GpuPowerAvg=if($gpuPower.Count){($gpuPower|Measure-Object -Average).Average}else{$null}
        }
    } catch { return $null }
}

function Analyze-PresentMonCsv {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "CSV not found: $Path" }
    $rows = @(Import-Csv -LiteralPath $Path)
    if ($rows.Count -lt 2) { throw 'PresentMon CSV does not contain enough captured frames.' }

    $frame = Get-NumericColumn -Rows $rows -Names @('FrameTime','MsBetweenAppStart','MsBetweenPresents')
    $displayLatency = Get-NumericColumn -Rows $rows -Names @('DisplayLatency','MsUntilDisplayed')
    $click = Get-NumericColumn -Rows $rows -Names @('ClickToPhotonLatency','MsClickToPhotonLatency')
    $pc = Get-NumericColumn -Rows $rows -Names @('MsPCLatency')

    $fs = Get-Stats $frame
    $ds = Get-Stats $displayLatency
    $cs = Get-Stats $click
    $ps = Get-Stats $pc
    if (-not $fs) { throw 'Could not locate a supported frame-time column in the PresentMon CSV.' }

    $avgFps = if ($fs.Avg -gt 0) { 1000.0 / $fs.Avg } else { 0 }
    [pscustomobject]@{
        File = $Path
        Frames = $fs.Count
        AvgFPS = $avgFps
        OnePercentLowFPS = Get-FocsWorstPercentAverageFps -FrameTimes $frame -Percent 1
        PointOnePercentLowFPS = Get-FocsWorstPercentAverageFps -FrameTimes $frame -Percent 0.1
        P1EquivalentFPS = if ($fs.P99 -gt 0) { 1000.0 / $fs.P99 } else { 0 }
        AvgFrameMs = $fs.Avg
        MedianFrameMs = $fs.Median
        P95FrameMs = $fs.P95
        P99FrameMs = $fs.P99
        P999FrameMs = $fs.P999
        FrameStdDev = $fs.StdDev
        FrameCvPct = if ($fs.Avg -gt 0) { 100.0 * $fs.StdDev / $fs.Avg } else { 0 }
        AvgDisplayLatency = if ($ds) { $ds.Avg } else { $null }
        P95DisplayLatency = if ($ds) { $ds.P95 } else { $null }
        AvgClickLatency = if ($cs) { $cs.Avg } else { $null }
        AvgPCLatency = if ($ps) { $ps.Avg } else { $null }
        Telemetry = Get-FocsTelemetrySummary -CsvPath $Path
    }
}

function Format-BenchmarkStats {
    param([object]$Stats,[string]$Label)
    $t = [System.Collections.Generic.List[string]]::new()
    $t.Add("$Label")
    $t.Add(('Frames: {0}' -f $Stats.Frames))
    $t.Add(('Average FPS (from average frame time): {0:N2}' -f $Stats.AvgFPS))
    $t.Add(('1% low average FPS (worst 1% frames): {0:N2}' -f $Stats.OnePercentLowFPS))
    $t.Add(('0.1% low average FPS (worst 0.1% frames): {0:N2}' -f $Stats.PointOnePercentLowFPS))
    $t.Add(('P1 FPS equivalent (from P99 frametime): {0:N2}' -f $Stats.P1EquivalentFPS))
    $t.Add(('Average / median frame time: {0:N3} / {1:N3} ms' -f $Stats.AvgFrameMs,$Stats.MedianFrameMs))
    $t.Add(('P95 / P99 / P99.9 frame time: {0:N3} / {1:N3} / {2:N3} ms' -f $Stats.P95FrameMs,$Stats.P99FrameMs,$Stats.P999FrameMs))
    $t.Add(('Frame-time standard deviation: {0:N3} ms | CV: {1:N2}%' -f $Stats.FrameStdDev,$Stats.FrameCvPct))
    if ($null -ne $Stats.AvgDisplayLatency) { $t.Add(('Average display latency: {0:N3} ms' -f $Stats.AvgDisplayLatency)) }
    if ($null -ne $Stats.P95DisplayLatency) { $t.Add(('P95 display latency: {0:N3} ms' -f $Stats.P95DisplayLatency)) }
    if ($null -ne $Stats.AvgClickLatency) { $t.Add(('Average click-to-photon latency: {0:N3} ms' -f $Stats.AvgClickLatency)) }
    if ($null -ne $Stats.AvgPCLatency) { $t.Add(('Average PC latency: {0:N3} ms' -f $Stats.AvgPCLatency)) }
    if($Stats.Telemetry){$tm=$Stats.Telemetry;$t.Add(('Telemetry samples: {0}' -f $tm.Samples));if($null -ne $tm.CpuTempMax){$t.Add(('CPU temp max: {0:N1} C' -f $tm.CpuTempMax))};if($null -ne $tm.GpuTempMax){$t.Add(('GPU temp max: {0:N1} C' -f $tm.GpuTempMax))};if($null -ne $tm.GpuLoadAvg){$t.Add(('GPU load avg: {0:N1}%' -f $tm.GpuLoadAvg))};if($null -ne $tm.GpuClockAvg){$t.Add(('GPU clock avg: {0:N0} MHz' -f $tm.GpuClockAvg))};if($null -ne $tm.CpuPowerAvg){$t.Add(('CPU package power avg: {0:N1} W' -f $tm.CpuPowerAvg))};if($null -ne $tm.GpuPowerAvg){$t.Add(('GPU power avg: {0:N1} W' -f $tm.GpuPowerAvg))}}
    return ($t -join "`r`n")
}

function Get-FocsPresentMonErrorText {
    param([string]$StdOut,[string]$StdErr)
    $parts=[System.Collections.Generic.List[string]]::new()
    foreach($f in @($StdErr,$StdOut)){
        if($f -and (Test-Path -LiteralPath $f)){
            try{$raw=(Get-Content -LiteralPath $f -Raw -ErrorAction Stop).Trim();if($raw){$parts.Add($raw)}}catch{}
        }
    }
    if($parts.Count -eq 0){return ''}
    $txt=($parts -join "`r`n").Trim()
    if($txt.Length -gt 2200){$txt=$txt.Substring($txt.Length-2200)}
    return $txt
}

function Test-FocsPresentMonCsvUsable {
    param([string]$Path)
    if([string]::IsNullOrWhiteSpace($Path) -or -not(Test-Path -LiteralPath $Path)){return $false}
    try{
        $fi=Get-Item -LiteralPath $Path -ErrorAction Stop
        if($fi.Length -lt 128){return $false}
        $head=Get-Content -LiteralPath $Path -TotalCount 2 -ErrorAction Stop
        return (@($head).Count -ge 2)
    }catch{return $false}
}

function Invoke-FocsPresentMonAttempt {
    param(
        [string]$PresentMonExe,
        [string]$Arguments,
        [string]$StdOut,
        [string]$StdErr,
        [switch]$CollectTelemetry
    )
    Remove-Item -LiteralPath $StdOut,$StdErr -Force -ErrorAction SilentlyContinue
    $telemetry=[System.Collections.Generic.List[object]]::new();$computer=$null
    if($CollectTelemetry){$computer=Open-FocsTelemetryComputer}
    $exit=$null
    try{
        $p=Start-Process -FilePath $PresentMonExe -ArgumentList $Arguments -WorkingDirectory (Split-Path -Parent $PresentMonExe) -PassThru -WindowStyle Hidden -RedirectStandardOutput $StdOut -RedirectStandardError $StdErr
        while(-not $p.HasExited){
            if($CollectTelemetry -and ($computer -or (Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue))){$telemetry.Add((Get-FocsTelemetrySample -Computer $computer))}
            [System.Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 500;$p.Refresh()
        }
        $exit=$p.ExitCode
    }finally{if($computer){try{$computer.Close()}catch{}}}
    return [pscustomobject]@{ExitCode=$exit;Telemetry=$telemetry.ToArray()}
}

function Convert-FocsPresentMonAllProcessCsv {
    param([string]$InputPath,[string]$OutputPath,[int]$TargetPid,[string]$TargetExe)
    if(-not(Test-FocsPresentMonCsvUsable -Path $InputPath)){return 0}
    try{
        $rows=@(Import-Csv -LiteralPath $InputPath -ErrorAction Stop)
        if($rows.Count -eq 0){return 0}
        $pidRows=@($rows|Where-Object{([string]$_.ProcessID) -eq ([string]$TargetPid)})
        $selected=$pidRows
        if($selected.Count -eq 0){
            $selected=@($rows|Where-Object{([string]$_.Application) -ieq $TargetExe})
        }
        if($selected.Count -eq 0){return 0}
        $selected|Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding ASCII
        return $selected.Count
    }catch{Write-KLog "Global PresentMon CSV filtering failed: $($_.Exception.Message)";return 0}
}

function Start-PresentMonCapture {
    param([string]$ProcessName,[int]$Seconds,[string]$Label)
    $pm=Find-PresentMon
    if(-not $pm){
        [void](Update-PresentMonTool -Force);$script:PresentMonConsolePath=$null;$pm=Find-PresentMon
    }
    if(-not $pm){throw 'The standalone PresentMon console executable was not found. FOCS will not use the Intel PresentMon GUI executable as a CLI.'}
    $target=Resolve-FocsBenchmarkTarget -ProcessText $ProcessName
    $name=[string]$target.Exe;$targetPid=[int]$target.Pid
    if($Seconds -lt 5){$Seconds=5};if($Seconds -gt 300){$Seconds=300}
    $csv=Join-Path $script:BenchmarkRoot ("{0}_{1}_{2}.csv" -f $Label,($name -replace '[^A-Za-z0-9_.-]','_'),(Get-Date -Format 'yyyyMMdd_HHmmss'))
    $stdout=[IO.Path]::ChangeExtension($csv,'.presentmon.stdout.log');$stderr=[IO.Path]::ChangeExtension($csv,'.presentmon.stderr.log');$allCsv=[IO.Path]::ChangeExtension($csv,'.allprocess.csv')
    Remove-Item -LiteralPath $csv,$stdout,$stderr,$allCsv -Force -ErrorAction SilentlyContinue

    $session=('FOCS'+$targetPid)
    $common='--timed {0} --terminate_after_timed --stop_existing_session --session_name "{1}" --no_console_stats --v2_metrics' -f $Seconds,$session
    if($script:ControlsForBenchmark -and $script:ControlsForBenchmark.PcLatency.Checked){$common+=' --track_pc_latency'}

    # Attempt 1: process name. This is the normal path and works well when PresentMon can resolve the process name.
    $args1='--process_name "{0}" {1} --output_file "{2}"' -f $name,$common,$csv
    Write-KLog "PresentMon attempt 1/3 (process name): EXE=$pm | Target=$name PID=$targetPid | Args=$args1"
    $a1=Invoke-FocsPresentMonAttempt -PresentMonExe $pm -Arguments $args1 -StdOut $stdout -StdErr $stderr -CollectTelemetry:$script:BenchmarkTelemetryEnabled
    $usable=Test-FocsPresentMonCsvUsable -Path $csv
    $telemetry=@($a1.Telemetry)
    if(-not $usable){
        $d1=Get-FocsPresentMonErrorText -StdOut $stdout -StdErr $stderr
        Write-KLog "PresentMon attempt 1 produced no usable target CSV. Exit=$($a1.ExitCode) | $d1"

        # Attempt 2: exact PID. A successful process exit is not enough; PresentMon may exit cleanly after seeing zero target presents.
        Remove-Item -LiteralPath $csv -Force -ErrorAction SilentlyContinue
        $args2='--process_id {0} {1} --output_file "{2}"' -f $targetPid,$common,$csv
        Write-KLog "PresentMon attempt 2/3 (PID): $args2"
        $a2=Invoke-FocsPresentMonAttempt -PresentMonExe $pm -Arguments $args2 -StdOut $stdout -StdErr $stderr -CollectTelemetry:$script:BenchmarkTelemetryEnabled
        $usable=Test-FocsPresentMonCsvUsable -Path $csv
        $telemetry=@($a2.Telemetry)
        if(-not $usable){
            $d2=Get-FocsPresentMonErrorText -StdOut $stdout -StdErr $stderr
            Write-KLog "PresentMon attempt 2 produced no usable target CSV. Exit=$($a2.ExitCode) | $d2"

            # Attempt 3: capture all graphical processes, then keep only rows belonging to the selected game.
            # This bypasses target-filter edge cases while still analyzing only the requested game.
            Remove-Item -LiteralPath $csv,$allCsv -Force -ErrorAction SilentlyContinue
            $args3='{0} --output_file "{1}"' -f $common,$allCsv
            Write-KLog "PresentMon attempt 3/3 (all-process capture + target-row filter): $args3"
            $a3=Invoke-FocsPresentMonAttempt -PresentMonExe $pm -Arguments $args3 -StdOut $stdout -StdErr $stderr -CollectTelemetry:$script:BenchmarkTelemetryEnabled
            $matched=Convert-FocsPresentMonAllProcessCsv -InputPath $allCsv -OutputPath $csv -TargetPid $targetPid -TargetExe $name
            $usable=Test-FocsPresentMonCsvUsable -Path $csv
            $telemetry=@($a3.Telemetry)
            Write-KLog "PresentMon attempt 3 exit=$($a3.ExitCode), matched target rows=$matched, usable=$usable"
        }
    }

    if(-not $usable){
        $detail=Get-FocsPresentMonErrorText -StdOut $stdout -StdErr $stderr
        $allHint=''
        if(Test-FocsPresentMonCsvUsable -Path $allCsv){
            try{
                $apps=@(Import-Csv -LiteralPath $allCsv|Group-Object Application|Sort-Object Count -Descending|Select-Object -First 8|ForEach-Object{"$($_.Name) ($($_.Count) frames)"})
                if($apps.Count){$allHint="`r`n`r`nPresentMon captured other graphical processes, but not the selected target. Top captured apps:`r`n"+($apps -join "`r`n")}
            }catch{}
        }
        $hint=''
        if($detail -match '(?i)access denied|failed to start trace session'){$hint="`r`nPresentMon could not start its ETW trace. FOCS should already be elevated; Windows can also require Performance Log Users/ETW permission."}
        elseif($detail -match '(?i)unrecognized option|unknown option'){$hint="`r`nThe PresentMon console binary does not match the expected CLI. Use CHECK / UPDATE TOOLS and retry."}
        elseif($detail -match '(?i)already exists|session'){$hint="`r`nAnother ETW/PresentMon capture session may be active. Close other PresentMon/benchmark capture tools and retry."}
        else{$hint="`r`nAll three capture modes were tried: process name, exact PID, and an unfiltered all-process capture. If the all-process capture also has no game frames, the issue is below FOCS's target-selection logic."}
        throw "PresentMon could not capture usable frames for $name (PID $targetPid).$hint$allHint`r`n`r`nPresentMon output:`r`n$detail`r`n`r`nLogs: $stderr"
    }

    if($telemetry.Count){$telemetry|Export-Csv -LiteralPath ([IO.Path]::ChangeExtension($csv,'.telemetry.csv')) -NoTypeInformation -Encoding UTF8}
    try{$sys=Get-SystemSummary;[pscustomobject]@{Label=$Label;Process=$name;ProcessId=$targetPid;ProcessPath=$target.Path;PresentMonExe=$pm;Seconds=$Seconds;CapturedAt=(Get-Date).ToString('o');Windows=$sys.OS;Build=$sys.Build;CPU=$sys.CPU;GPU=$sys.GPU;Driver=$sys.Driver;HAGS=$sys.HAGS;PowerScheme=(Get-ActivePowerSchemeGuid);TelemetrySamples=$telemetry.Count;FallbackAllProcessCsv=if(Test-Path -LiteralPath $allCsv){$allCsv}else{$null}}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath ([IO.Path]::ChangeExtension($csv,'.json')) -Encoding UTF8}catch{Write-KLog "Benchmark metadata write failed: $($_.Exception.Message)"}
    return $csv
}

function Get-KWinget {
    # An orphaned WindowsApps execution alias can still be returned by Get-Command
    # even when Microsoft.DesktopAppInstaller is missing. Verify that each candidate
    # actually starts before treating WinGet as available.
    $candidates = @()
    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { $candidates += [string]$cmd.Source }
    $alias = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
    if (Test-Path -LiteralPath $alias) { $candidates += $alias }
    foreach ($candidate in @($candidates | Select-Object -Unique)) {
        try {
            $version = (& $candidate --version 2>$null | Out-String).Trim()
            if ($LASTEXITCODE -eq 0 -and $version -match '^v?[0-9]+\.') { return $candidate }
        } catch {}
    }
    return $null
}

function Get-KChocolatey {
    $cmd = Get-Command choco.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidate = Join-Path $env:ProgramData 'chocolatey\bin\choco.exe'
    if (Test-Path -LiteralPath $candidate) { return $candidate }
    return $null
}

function Get-WingetPackageVersion {
    param([Parameter(Mandatory=$true)][string]$PackageId)
    $winget = Get-KWinget
    if (-not $winget) { return $null }
    try {
        $out = (& $winget show --id $PackageId --exact --source winget --accept-source-agreements --disable-interactivity 2>$null | Out-String)
        $m = [regex]::Match($out,'(?im)^Version:\s*([^\r\n]+)')
        if ($m.Success) { return $m.Groups[1].Value.Trim() }
    } catch {}
    return $null
}

function Get-ChocoPackageVersion {
    param([Parameter(Mandatory=$true)][string]$PackageName)
    $choco = Get-KChocolatey
    if (-not $choco) { return $null }
    try {
        $out = (& $choco search $PackageName --exact --limit-output --no-progress 2>$null | Out-String).Trim()
        $m = [regex]::Match($out,'(?im)^' + [regex]::Escape($PackageName) + '\|([^\r\n]+)$')
        if ($m.Success) { return $m.Groups[1].Value.Trim() }
    } catch {}
    return $null
}

function Convert-KVersionText {
    param([string]$Version)
    if (-not $Version) { return '' }
    return (($Version.Trim() -replace '^[vV]','') -replace '[^0-9.]','').Trim('.')
}

function Test-KVersionEquivalent {
    param([string]$A,[string]$B)
    $a1 = Convert-KVersionText $A
    $b1 = Convert-KVersionText $B
    if (-not $a1 -or -not $b1) { return $false }
    return ($a1 -eq $b1 -or $a1.StartsWith($b1 + '.') -or $b1.StartsWith($a1 + '.'))
}

function Invoke-WingetInstallOrUpgrade {
    param([Parameter(Mandatory=$true)][string]$PackageId)
    $winget = Get-KWinget
    if (-not $winget) { throw 'winget is not available.' }
    $verb = if (Get-WingetInstalledVersion -PackageId $PackageId) { 'upgrade' } else { 'install' }
    Write-KLog "winget: $verb $PackageId"
    $wingetArgs = @($verb,'--id',$PackageId,'--exact','--source','winget','--silent','--accept-source-agreements','--accept-package-agreements','--disable-interactivity')
    $p = Start-Process -FilePath $winget -ArgumentList $wingetArgs -PassThru -Wait -WindowStyle Hidden
    if ($p.ExitCode -ne 0) { throw "winget returned exit code $($p.ExitCode) for $PackageId." }
}

function Get-FocsAppCatalog {
    return @(
        [pscustomobject]@{ Name='Chromium'; PackageId='Hibbiki.Chromium'; Description='Open-source Chromium browser build maintained by Hibbiki.' }
        [pscustomobject]@{ Name='Discord'; PackageId='Discord.Discord'; Description='Voice, video and text chat client.' }
        [pscustomobject]@{ Name='Steam'; PackageId='Valve.Steam'; Description='Valve game library, store and launcher.' }
        [pscustomobject]@{ Name='Epic Games Launcher'; PackageId='EpicGames.EpicGamesLauncher'; Description='Epic Games Store and Unreal Engine launcher.' }
        [pscustomobject]@{ Name='Logitech Onboard Memory Manager'; PackageId='Logitech.OnboardMemoryManager'; Description='Configure supported Logitech gaming-device onboard profiles.' }
    )
}

function Get-WingetInstalledVersion {
    param([Parameter(Mandatory=$true)][string]$PackageId)
    $winget = Get-KWinget
    if (-not $winget) { return $null }
    try {
        $out = (& $winget list --id $PackageId --exact --source winget --accept-source-agreements --disable-interactivity 2>$null | Out-String)
        if ($LASTEXITCODE -ne 0 -or $out -match '(?i)No installed package found') { return $null }
        $line = @($out -split "`r?`n" | Where-Object { $_ -match ('(?i)^\s*.+\s+' + [regex]::Escape($PackageId) + '\s+') }) | Select-Object -First 1
        if ($line -and $line -match ('(?i)' + [regex]::Escape($PackageId) + '\s+([^\s]+)')) { return $Matches[1].Trim() }
        return 'installed'
    } catch { return $null }
}

function Get-FocsLogitechOmmExe {
    $candidates = [System.Collections.Generic.List[string]]::new()
    $candidates.Add((Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\OnboardMemoryManager.exe'))
    try {
        $uninstall = Get-ItemProperty -LiteralPath 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Logitech.OnboardMemoryManager_Microsoft.Winget.Source_8wekyb3d8bbwe' -ErrorAction Stop
        if ($uninstall.InstallLocation) { $candidates.Add((Join-Path ([string]$uninstall.InstallLocation) 'OnboardMemoryManager.exe')) }
    } catch {}
    $packageRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    if (Test-Path -LiteralPath $packageRoot) {
        foreach ($file in @(Get-ChildItem -LiteralPath $packageRoot -Filter 'OnboardMemoryManager.exe' -File -Recurse -ErrorAction SilentlyContinue)) {
            $candidates.Add($file.FullName)
        }
    }
    foreach ($candidate in @($candidates | Select-Object -Unique)) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return (Get-Item -LiteralPath $candidate).FullName
        }
    }
    return $null
}

function Ensure-FocsLogitechOmmShortcut {
    $exe = Get-FocsLogitechOmmExe
    if (-not $exe) { throw 'WinGet registered Logitech Onboard Memory Manager, but OnboardMemoryManager.exe was not found.' }
    $programs = [Environment]::GetFolderPath([Environment+SpecialFolder]::Programs)
    if (-not $programs) { throw 'The current user Start Menu folder could not be resolved.' }
    $shortcutPath = Join-Path $programs 'Logitech Onboard Memory Manager.lnk'
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $exe
    $shortcut.WorkingDirectory = Split-Path -Parent $exe
    $shortcut.IconLocation = $exe
    $shortcut.Description = 'Logitech Onboard Memory Manager'
    $shortcut.Save()
    if (-not (Test-Path -LiteralPath $shortcutPath)) { throw 'The Logitech OMM Start Menu shortcut could not be created.' }
    Write-KLog "Logitech OMM verified and Start Menu shortcut ready: $shortcutPath | EXE=$exe"
    return [pscustomobject]@{ Exe=$exe; Shortcut=$shortcutPath }
}

function Get-FocsAppInstallerStatus {
    $winget = Get-KWinget
    if (-not $winget) { throw 'WinGet is not available. Install or update Microsoft App Installer, then reopen FOCS.' }
    $rows = foreach ($app in Get-FocsAppCatalog) {
        $installed = Get-WingetInstalledVersion -PackageId $app.PackageId
        $available = Get-WingetPackageVersion -PackageId $app.PackageId
        [pscustomobject]@{
            Name = $app.Name
            PackageId = $app.PackageId
            Installed = if($installed){$installed}else{'Not installed'}
            Available = if($available){$available}else{'Unavailable'}
        }
    }
    return @($rows)
}

function Format-FocsAppInstallerStatus {
    param([object[]]$Status)
    $lines = @('APP INSTALLER STATUS','')
    foreach ($row in @($Status)) {
        $lines += ("{0}`r`n  ID: {1}`r`n  Installed: {2} | Available: {3}" -f $row.Name,$row.PackageId,$row.Installed,$row.Available)
    }
    return ($lines -join "`r`n")
}

function Install-FocsSelectedApps {
    param(
        [Parameter(Mandatory=$true)][string[]]$PackageIds,
        [System.Windows.Forms.TextBoxBase]$OutputBox
    )
    $catalog = @(Get-FocsAppCatalog)
    $allowed = @{}
    foreach ($app in $catalog) { $allowed[$app.PackageId] = $app }
    $selected = @($PackageIds | Select-Object -Unique)
    if (-not $selected.Count) { throw 'Select at least one application.' }
    foreach ($id in $selected) { if (-not $allowed.ContainsKey($id)) { throw "Unsupported app package ID: $id" } }
    if (-not (Get-KWinget)) { throw 'WinGet is not available. Install or update Microsoft App Installer, then reopen FOCS.' }

    $results = New-Object System.Collections.Generic.List[string]
    foreach ($id in $selected) {
        $name = $allowed[$id].Name
        try {
            if ($OutputBox) { $OutputBox.Text = "Installing or updating $name..."; [System.Windows.Forms.Application]::DoEvents() }
            Invoke-WingetInstallOrUpgrade -PackageId $id
            $installed = Get-WingetInstalledVersion -PackageId $id
            if (-not $installed) { throw 'WinGet completed without registering the package as installed.' }
            $detail = ''
            if ($id -eq 'Logitech.OnboardMemoryManager') {
                $omm = Ensure-FocsLogitechOmmShortcut
                $detail = " | Start Menu shortcut created | EXE: $($omm.Exe)"
            }
            $msg = "OK - $name ($installed)$detail"
            $results.Add($msg)
            Write-KLog $msg
        } catch {
            $msg = "FAILED - ${name}: $($_.Exception.Message)"
            $results.Add($msg)
            Write-KLog $msg
        }
        if ($OutputBox) { $OutputBox.Text = ($results -join "`r`n"); [System.Windows.Forms.Application]::DoEvents() }
    }
    return ($results -join "`r`n")
}

function Invoke-ChocoInstallOrUpgrade {
    param([Parameter(Mandatory=$true)][string]$PackageName)
    $choco = Get-KChocolatey
    if (-not $choco) { throw 'Chocolatey is not installed.' }
    Write-KLog "Chocolatey: installing/upgrading $PackageName"
    $p = Start-Process -FilePath $choco -ArgumentList @('upgrade',$PackageName,'-y','--no-progress') -PassThru -Wait -WindowStyle Hidden
    if ($p.ExitCode -notin @(0,1605,1614,1641,3010)) { throw "Chocolatey returned exit code $($p.ExitCode) for $PackageName." }
}

function Invoke-KWebJson {
    param([Parameter(Mandatory=$true)][string]$Uri)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    return Invoke-RestMethod -Uri $Uri -Headers @{ 'User-Agent'='FOCS-Utility-v9.5.0'; 'Accept'='application/vnd.github+json' } -UseBasicParsing -ErrorAction Stop
}

function Download-KFile {
    param([Parameter(Mandatory=$true)][string]$Uri,[Parameter(Mandatory=$true)][string]$Destination)
    $parsed = $null
    if (-not [Uri]::TryCreate($Uri,[UriKind]::Absolute,[ref]$parsed) -or $parsed.Scheme -ne 'https') {
        throw "FOCS only downloads tools over HTTPS: $Uri"
    }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $parent = Split-Path -Parent $Destination
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    Invoke-WebRequest -Uri $Uri -OutFile $Destination -UseBasicParsing -Headers @{ 'User-Agent'='FOCS-Utility-v9.5.0' } -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $Destination) -or (Get-Item -LiteralPath $Destination).Length -lt 1024) { throw "Download did not produce a valid file: $Uri" }
}

function Install-FocsStagedDirectory {
    param(
        [Parameter(Mandatory=$true)][string]$Root,
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$RequiredFileName
    )
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) { throw "Staged tool directory is missing: $Source" }
    $parent = Split-Path -Parent $Root
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $backup = "$Root.focsbackup.$([guid]::NewGuid().ToString('N'))"
    $hadExisting = Test-Path -LiteralPath $Root
    try {
        if ($hadExisting) { Move-Item -LiteralPath $Root -Destination $backup -Force -ErrorAction Stop }
        Move-Item -LiteralPath $Source -Destination $Root -Force -ErrorAction Stop
        $required = Get-ChildItem -LiteralPath $Root -Filter $RequiredFileName -File -Recurse -ErrorAction Stop | Select-Object -First 1
        if (-not $required) { throw "Atomic tool install completed without required file: $RequiredFileName" }
        if ($hadExisting) { Remove-Item -LiteralPath $backup -Recurse -Force -ErrorAction Stop }
        return $required.FullName
    } catch {
        $failure = $_
        Remove-Item -LiteralPath $Root -Recurse -Force -ErrorAction SilentlyContinue
        if ($hadExisting -and (Test-Path -LiteralPath $backup)) {
            Move-Item -LiteralPath $backup -Destination $Root -Force -ErrorAction SilentlyContinue
        }
        throw $failure
    }
}

function Get-GitHubLatestStableRelease {
    param([Parameter(Mandatory=$true)][string]$Repository)
    return Invoke-KWebJson -Uri ("https://api.github.com/repos/{0}/releases/latest" -f $Repository)
}

function Get-ManagedVersion {
    param([string]$Root)
    $f = Join-Path $Root 'version.txt'
    if (Test-Path -LiteralPath $f) { return (Get-Content -LiteralPath $f -Raw).Trim() }
    return $null
}

function Set-ManagedVersion {
    param([string]$Root,[string]$Version)
    $Version | Set-Content -LiteralPath (Join-Path $Root 'version.txt') -Encoding ASCII
}

function Update-PresentMonTool {
    param([switch]$Force)
    $release=Get-GitHubLatestStableRelease -Repository 'GameTechDev/PresentMon';$tag=[string]$release.tag_name
    if(-not $tag){throw 'GitHub did not return a PresentMon release tag.'}
    # FOCS requires the standalone console binary. The Intel.PresentMon winget package installs the capture UI/service,
    # whose PresentMon.exe is a different program and must not be used with console CLI flags.
    $asset=@($release.assets)|Where-Object{$_.name -match '^PresentMon-.*-x64\.exe$'}|Select-Object -First 1
    if(-not $asset){throw 'Latest PresentMon release has no x64 standalone console executable asset.'}
    $dest=Join-Path $script:PresentMonRoot ([string]$asset.name);$current=Get-ManagedVersion -Root $script:PresentMonRoot
    if(-not $Force -and $current -match [regex]::Escape($tag) -and (Test-Path -LiteralPath $dest) -and (Test-FocsPresentMonConsoleExe -Path $dest)){$script:PresentMonConsolePath=$dest;return "PresentMon $tag console is current"}
    # Verify the digest and the Intel signature before the binary is ever executed, not after.
    $sha=Get-KVerifiedDownload -Uri ([string]$asset.browser_download_url) -Destination $dest -Asset $asset -CheckSignature -ExpectedSubjectPatterns @('Intel')
    if(-not(Test-FocsPresentMonConsoleExe -Path $dest)){Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue;throw 'Downloaded PresentMon asset did not identify as the standalone console application.'}
    Get-ChildItem -LiteralPath $script:PresentMonRoot -Filter 'PresentMon*.exe' -File -ErrorAction SilentlyContinue|Where-Object{$_.FullName -ne $dest}|Remove-Item -Force -ErrorAction SilentlyContinue
    Set-ManagedVersion -Root $script:PresentMonRoot -Version ($tag+' console official');$script:PresentMonConsolePath=$dest
    Write-KLog "PresentMon console updated from official GitHub release to $tag | SHA256=$sha"
    return "PresentMon $tag console official"
}

function Update-NpiTool {
    param([switch]$Force)
    $release = Get-GitHubLatestStableRelease -Repository 'Orbmu2k/nvidiaProfileInspector'
    $tag = [string]$release.tag_name
    if (-not $tag) { throw 'GitHub did not return an NVIDIA Profile Inspector release tag.' }

    $choco = Get-KChocolatey
    if ($choco) {
        $cv = Get-ChocoPackageVersion -PackageName 'nvidia-profile-inspector'
        if ($cv -and (Test-KVersionEquivalent $cv $tag)) {
            try {
                Invoke-ChocoInstallOrUpgrade -PackageName 'nvidia-profile-inspector'
                Start-Sleep -Milliseconds 300
                $exe = Find-NvidiaProfileInspector
                if ($exe) {
                    Set-ManagedVersion -Root $script:NpiRoot -Version ($tag + ' via Chocolatey')
                    Write-KLog "NVIDIA Profile Inspector $tag installed/updated through Chocolatey: $exe"
                    return "NVIDIA Profile Inspector $tag via Chocolatey"
                }
            } catch { Write-KLog "NPI Chocolatey path failed; using official release fallback: $($_.Exception.Message)" }
        } elseif ($cv) {
            Write-KLog "Chocolatey NPI version $cv does not match GitHub stable $tag; official stable release will be used instead."
        }
    }

    $asset = @($release.assets) | Where-Object { $_.name -ieq 'nvidiaProfileInspector.zip' } | Select-Object -First 1
    if (-not $asset) { $asset = @($release.assets) | Where-Object { $_.name -match '(?i)nvidiaProfileInspector.*\.zip$' } | Select-Object -First 1 }
    if (-not $asset) { throw 'Latest NVIDIA Profile Inspector release has no application ZIP asset.' }
    $exe = Join-Path $script:NpiRoot 'nvidiaProfileInspector.exe'
    $current = Get-ManagedVersion -Root $script:NpiRoot
    if (-not $Force -and $current -match [regex]::Escape($tag) -and (Test-Path -LiteralPath $exe)) { return "NVIDIA Profile Inspector $tag is current" }

    $work = Join-Path $env:TEMP ('FOCS_NPI_' + [guid]::NewGuid().ToString('N'))
    $zip = "$work.zip"
    $stage = Join-Path $work 'extracted'
    try {
        New-Item -ItemType Directory -Path $stage -Force | Out-Null
        [void](Get-KVerifiedDownload -Uri ([string]$asset.browser_download_url) -Destination $zip -Asset $asset)
        Expand-Archive -LiteralPath $zip -DestinationPath $stage -Force
        $found = Get-ChildItem -LiteralPath $stage -Filter 'nvidiaProfileInspector.exe' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        # Everything is verified in a staging folder first, so a bad download can never leave the
        # user with no tool at all.
        if (-not $found) { throw 'NVIDIA Profile Inspector executable was not found after extracting the official release.' }
        $keep = @(Get-ChildItem -LiteralPath $script:NpiRoot -Filter '*.nip' -File -ErrorAction SilentlyContinue)
        $nipBackup = Join-Path $work 'nip'
        if ($keep.Count -gt 0) {
            New-Item -ItemType Directory -Path $nipBackup -Force | Out-Null
            foreach ($n in $keep) { Copy-Item -LiteralPath $n.FullName -Destination $nipBackup -Force }
        }
        if (Test-Path -LiteralPath $nipBackup) {
            Get-ChildItem -LiteralPath $nipBackup -Filter '*.nip' -File | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $found.DirectoryName -Force }
        }
        [void](Install-FocsStagedDirectory -Root $script:NpiRoot -Source $found.DirectoryName -RequiredFileName 'nvidiaProfileInspector.exe')
        Set-ManagedVersion -Root $script:NpiRoot -Version ($tag + ' official')
        Write-KLog "NVIDIA Profile Inspector updated from official GitHub release to $tag"
        return "NVIDIA Profile Inspector $tag official"
    } finally {
        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Get-LatencyMonInstalledExe {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'LatencyMon\LatMon.exe'),
        (Join-Path $env:ProgramFiles 'Resplendence\LatencyMon\LatMon.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'LatencyMon\LatMon.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Resplendence\LatencyMon\LatMon.exe')
    )
    foreach ($p in $candidates) { if ($p -and (Test-Path -LiteralPath $p)) { return $p } }
    $cmd = Get-Command LatMon.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Get-LatencyMonLatestVersion {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $html = (Invoke-WebRequest -Uri 'https://www.resplendence.com/latencymon_whatsnew' -UseBasicParsing -Headers @{ 'User-Agent'='FOCS-Utility-v9.5.0' } -ErrorAction Stop).Content
        $m = [regex]::Match($html,'LatencyMon\s+(?:v\s*)?([0-9]+\.[0-9]+)',[Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($m.Success) { return $m.Groups[1].Value }
    } catch { Write-KLog "LatencyMon version check failed: $($_.Exception.Message)" }
    return 'latest'
}

function Update-LatencyMonTool {
    param([switch]$Force)
    $ver = Get-LatencyMonLatestVersion
    $choco = Get-KChocolatey
    if ($choco) {
        $cv = Get-ChocoPackageVersion -PackageName 'latencymon'
        if ($cv -and (Test-KVersionEquivalent $cv $ver)) {
            try {
                Invoke-ChocoInstallOrUpgrade -PackageName 'latencymon'
                Start-Sleep -Milliseconds 300
                $exe = Get-LatencyMonInstalledExe
                if ($exe) {
                    Set-ManagedVersion -Root $script:LatencyMonRoot -Version ($ver + ' via Chocolatey')
                    Write-KLog "LatencyMon $ver installed/updated through Chocolatey: $exe"
                    return "LatencyMon $ver via Chocolatey"
                }
            } catch { Write-KLog "LatencyMon Chocolatey path failed; using official installer fallback: $($_.Exception.Message)" }
        } elseif ($cv) {
            Write-KLog "Chocolatey LatencyMon version $cv does not match official latest $ver; official installer will be used instead."
        }
    }

    $installer = Join-Path $script:LatencyMonRoot 'LatencyMon-Setup.exe'
    $current = Get-ManagedVersion -Root $script:LatencyMonRoot
    if (-not $Force -and $current -match [regex]::Escape($ver) -and (Test-Path -LiteralPath $installer)) { return "LatencyMon $ver installer is current" }
    # Current official LatencyMon installers are signed by the publisher's named
    # certificate holder, Daniel Terhell, rather than a subject containing the
    # Resplendence product name. Keep the match anchored to the certificate CN.
    [void](Get-KVerifiedDownload -Uri 'https://www.resplendence.com/download/LatencyMon.exe' -Destination $installer -CheckSignature -ExpectedSubjectPatterns @('Resplendence','^CN=Daniel Terhell(?:,|$)'))
    Set-ManagedVersion -Root $script:LatencyMonRoot -Version ($ver + ' official installer')
    $sha = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash
    Write-KLog "LatencyMon installer downloaded from official site: version=$ver | SHA256=$sha"
    return "LatencyMon $ver official installer"
}

function Install-LatencyMonTool {
    $existing = Get-LatencyMonInstalledExe
    $choco = Get-KChocolatey
    if ($choco) {
        $ver = Get-LatencyMonLatestVersion
        $cv = Get-ChocoPackageVersion -PackageName 'latencymon'
        if ($cv -and (Test-KVersionEquivalent $cv $ver)) {
            try {
                Invoke-ChocoInstallOrUpgrade -PackageName 'latencymon'
                $exe = Get-LatencyMonInstalledExe
                if ($exe) { return $exe }
            } catch { Write-KLog "LatencyMon Chocolatey install failed; falling back to official installer: $($_.Exception.Message)" }
        }
    }
    $installer = Join-Path $script:LatencyMonRoot 'LatencyMon-Setup.exe'
    if (-not (Test-Path -LiteralPath $installer)) { [void](Update-LatencyMonTool -Force) }
    $p = Start-Process -FilePath $installer -ArgumentList @('/SP-','/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART') -PassThru -Wait
    if ($p.ExitCode -notin @(0,5,1641,3010)) { throw "LatencyMon installer returned exit code $($p.ExitCode)." }
    $exe = Get-LatencyMonInstalledExe
    if (-not $exe) { throw 'LatencyMon installation finished but LatMon.exe could not be located.' }
    Write-KLog "LatencyMon installed/updated: $exe"
    return $exe
}

function Update-ToolStatusLabels {
    try {
        if ($script:ToolStatusLabels.ContainsKey('PresentMon')) {
            $v = Get-ManagedVersion $script:PresentMonRoot; if (-not $v) { $v='not downloaded' }
            $script:ToolStatusLabels.PresentMon.Text = "PresentMon: $v"
        }
        if ($script:ToolStatusLabels.ContainsKey('NPI')) {
            $v = Get-ManagedVersion $script:NpiRoot; if (-not $v) { $v='not downloaded' }
            $script:ToolStatusLabels.NPI.Text = "NVIDIA Profile Inspector: $v"
        }
        if ($script:ToolStatusLabels.ContainsKey('LatencyMon')) {
            $v = Get-ManagedVersion $script:LatencyMonRoot; if (-not $v) { $v='not downloaded' }
            $installed = if (Get-LatencyMonInstalledExe) { 'installed' } else { 'installer ready' }
            $script:ToolStatusLabels.LatencyMon.Text = "LatencyMon: $v ($installed)"
        }
        if ($script:ToolStatusLabels.ContainsKey('LHM')) {
            $v = Get-ManagedVersion $script:LhmRoot; if (-not $v) { $v='not downloaded' }
            $script:ToolStatusLabels.LHM.Text = "Hardware telemetry: $v"
        }
    } catch {}
}

function Update-ManagedTools {
    param([switch]$Force)
    $results = [System.Collections.Generic.List[string]]::new()
    $failed = 0
    foreach ($item in @(
        @{Name='PresentMon'; Action={ if ($Force) { Update-PresentMonTool -Force } else { Update-PresentMonTool } }},
        @{Name='NVIDIA Profile Inspector'; Action={ if ($Force) { Update-NpiTool -Force } else { Update-NpiTool } }},
        @{Name='LatencyMon'; Action={ if ($Force) { Update-LatencyMonTool -Force } else { Update-LatencyMonTool } }},
        @{Name='LibreHardwareMonitor'; Action={ if ($Force) { Update-LibreHardwareMonitorTool -Force } else { Update-LibreHardwareMonitorTool } }}
    )) {
        try {
            $r = & $item.Action
            $results.Add("$($item.Name): $r")
        } catch {
            $failed++
            $results.Add("$($item.Name): update failed - $($_.Exception.Message)")
            Write-KLog "$($item.Name) update failed: $($_.Exception.Message)"
        }
        [System.Windows.Forms.Application]::DoEvents()
    }
    # Do not suppress retries for 24 hours when any managed tool failed its check/update.
    if ($failed -eq 0) {
        try { (Get-Date).ToString('o') | Set-Content -LiteralPath $script:ToolCheckFile -Encoding ASCII } catch {}
    }
    Update-ToolStatusLabels
    return ($results -join "`r`n")
}

function Test-ToolAutoUpdateDue {
    if (-not (Test-Path -LiteralPath $script:ToolCheckFile)) { return $true }
    try {
        $d = [datetime]::Parse((Get-Content -LiteralPath $script:ToolCheckFile -Raw).Trim(),[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind)
        return ((Get-Date) - $d).TotalHours -ge 24
    } catch { return $true }
}

function Export-NpiCustomizedBackup {
    $npi = Find-NvidiaProfileInspector
    if (-not $npi) { throw 'NVIDIA Profile Inspector is not available yet. Update managed tools first.' }
    $backupDir = Join-Path $script:BackupRoot ("NPI_Backup_{0}" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    $npiDir = Split-Path -Parent $npi
    $before = @{}
    Get-ChildItem -LiteralPath $npiDir -Filter '*.nip' -ErrorAction SilentlyContinue | ForEach-Object { $before[$_.FullName] = $_.LastWriteTimeUtc }
    $p = Start-Process -FilePath $npi -ArgumentList '-exportCustomized' -WorkingDirectory $npiDir -PassThru -Wait
    if ($p.ExitCode -ne 0) { Write-KLog "NPI export returned exit code $($p.ExitCode)" }
    Start-Sleep -Milliseconds 500
    Get-ChildItem -LiteralPath $npiDir -Filter '*.nip' -ErrorAction SilentlyContinue | ForEach-Object {
        $isNew = (-not $before.ContainsKey($_.FullName)) -or ($_.LastWriteTimeUtc -gt $before[$_.FullName])
        if ($isNew) { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $backupDir $_.Name) -Force }
    }
    $script:LastNpiBackup = $backupDir
    Write-KLog "NPI customized-profile backup: $backupDir"
    return $backupDir
}

function New-NpiKxttsPreset {
    param([ValidateSet('Fortnite','CS2')][string]$Game,[ValidateSet('Recommended','Competitive')][string]$Mode)
    $profileName = if ($Game -eq 'Fortnite') { 'Fortnite' } else { 'Counter-Strike 2' }
    $executables = if ($Game -eq 'Fortnite') {
        @('FortniteClient-Win64-Shipping.exe','FortniteClient-Win64-Shipping_EAC_EOS.exe','FortniteClient-Win64-Shipping_BE.exe')
    } else { @('cs2.exe') }
    $exeXml = ($executables | ForEach-Object { '      <string>' + [Security.SecurityElement]::Escape($_) + '</string>' }) -join "`r`n"
    $settings = @(
        @{Name='Power management mode'; Id='274197361'; Value='1'}
    )
    if ($Mode -eq 'Competitive') {
        $settings += @{Name='Texture filtering - Quality'; Id='13510289'; Value='20'}
    }
    $settingsXml = ($settings | ForEach-Object {
@"
      <ProfileSetting>
        <SettingNameInfo>$($_.Name)</SettingNameInfo>
        <SettingID>$($_.Id)</SettingID>
        <SettingValue>$($_.Value)</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
"@
    }) -join ''
    $xml = @"
<?xml version="1.0" encoding="utf-16"?>
<ArrayOfProfile>
  <Profile>
    <ProfileName>$profileName</ProfileName>
    <Executeables>
$exeXml
    </Executeables>
    <Settings>
$settingsXml    </Settings>
  </Profile>
</ArrayOfProfile>
"@
    $dir = Join-Path $script:DataRoot 'GeneratedProfiles'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $path = Join-Path $dir ("FOCS_{0}_{1}_{2}.nip" -f $Game,$Mode,(Get-Date -Format 'yyyyMMdd_HHmmss'))
    [IO.File]::WriteAllText($path,$xml,[Text.Encoding]::Unicode)
    return $path
}

function Apply-NpiKxttsPreset {
    param([ValidateSet('Fortnite','CS2')][string]$Game,[ValidateSet('Recommended','Competitive')][string]$Mode)
    if (-not (Find-NvidiaProfileInspector)) { [void](Update-NpiTool -Force) }
    $npi = Find-NvidiaProfileInspector
    if (-not $npi) { throw 'NVIDIA Profile Inspector is not available.' }
    $backup = Export-NpiCustomizedBackup
    $npiProfileFile = New-NpiKxttsPreset -Game $Game -Mode $Mode
    $p = Start-Process -FilePath $npi -ArgumentList @('-silentImport',('"' + $npiProfileFile + '"')) -WorkingDirectory (Split-Path -Parent $npi) -PassThru -Wait
    if ($p.ExitCode -ne 0) { throw "NVIDIA Profile Inspector import failed with exit code $($p.ExitCode)." }
    Write-KLog "NPI $Mode preset applied for $Game. Profile=$npiProfileFile Backup=$backup"
    return "Applied $Mode NVIDIA profile for $Game.`r`nBackup: $backup`r`nProfile: $npiProfileFile"
}

function Apply-OptionalServices {
    param([System.Windows.Forms.CheckedListBox]$List)
    $selected = @($List.CheckedItems)
    if ($selected.Count -eq 0) { throw 'No optional services are selected.' }
    $backup = New-KBackup
    $changed = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $selected) {
        $name = ([string]$item -split ' - ',2)[0].Trim()
        if (-not $name) { continue }
        $svc = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f ($name -replace "'","''")) -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $svc) { Write-KLog "Optional service not present, skipped: $name"; continue }
        try {
            # Record the previous start type before changing it, so RESTORE_FOCS.ps1 can put
            # back exactly these services and nothing else.
            $changed.Add([pscustomobject]@{ Name=$name; StartMode=[string]$svc.StartMode; ChangedTo='Manual'; At=(Get-Date).ToString('o') })
            Set-Service -Name $name -StartupType Manual -ErrorAction Stop
            Write-KLog "Optional service set to Manual: $name (was $($svc.StartMode))"
        } catch {
            Write-KLog "Optional service change failed ${name}: $($_.Exception.Message)"
        }
    }
    Save-KServiceChangeJournal -Folder $backup -Entries $changed.ToArray()
    return $backup
}


# ============================================================================
# FOCS v9 power-user modules: profiles, debloat, registry, services, NIC editor
# ============================================================================
$script:Ui = @{}

function Get-KDebloatCatalog {
    return [ordered]@{
        'Clipchamp' = @('Clipchamp.Clipchamp')
        'Microsoft News' = @('Microsoft.BingNews','Microsoft.News')
        'Microsoft Weather' = @('Microsoft.BingWeather')
        'Solitaire Collection' = @('Microsoft.MicrosoftSolitaireCollection')
        'Feedback Hub' = @('Microsoft.WindowsFeedbackHub')
        'Maps' = @('Microsoft.WindowsMaps')
        'Microsoft 365 / Office Hub' = @('Microsoft.MicrosoftOfficeHub')
        'Teams (personal/new)' = @('MicrosoftTeams','MSTeams')
        'New Outlook' = @('Microsoft.OutlookForWindows')
        'Phone Link' = @('Microsoft.YourPhone')
        'Microsoft To Do' = @('Microsoft.Todos')
        'Microsoft Journal' = @('Microsoft.MicrosoftJournal')
        'Skype' = @('Microsoft.SkypeApp')
        'Mixed Reality Portal' = @('Microsoft.MixedReality.Portal')
        'Power Automate Desktop' = @('Microsoft.PowerAutomateDesktop')
        'Microsoft Copilot app' = @('Microsoft.Copilot')
        'Dev Home' = @('Microsoft.Windows.DevHome')
        'Xbox app (Game Pass users: keep)' = @('Microsoft.GamingApp')
        'Xbox Game Bar / overlays' = @('Microsoft.XboxGamingOverlay','Microsoft.XboxGameOverlay')
    }
}

function Get-KRegistryCatalog {
    return [ordered]@{
        'Disable Microsoft consumer experiences' = 'Consumer'
        'Disable Windows tips, suggestions and silent app suggestions' = 'Suggestions'
        'Disable advertising ID and tailored experiences' = 'Ads'
        'Disable Activity History publishing/upload' = 'Activity'
        'Disable Edge Startup Boost + background mode' = 'EdgeBackground'
        'Disable Widgets + hide taskbar Widgets button' = 'Widgets'
        'Disable Bing web suggestions in Windows Search' = 'BingSearch'
        'Disable Microsoft Copilot' = 'Copilot'
        'Disable Windows Recall availability (restart; advanced)' = 'Recall'
        'Disable transparency effects' = 'Transparency'
        'Disable Game DVR/background capture' = 'GameDvr'
        'Disable Delivery Optimization P2P' = 'Delivery'
    }
}

function Get-KRegistryPlan {
    param([string[]]$Keys)
    # Single source of truth for what each module writes. Previously the target list and the
    # apply logic were two parallel switch statements that could drift apart, which also made
    # a change preview impossible.
    $plan = [System.Collections.Generic.List[object]]::new()
    $add = { param([string]$K,[string]$P,[string]$N,[uint32]$V,[string]$D) $plan.Add([pscustomobject]@{Key=$K;Path=$P;Name=$N;Value=$V;Description=$D}) }
    foreach ($k in @($Keys)) {
        switch ($k) {
            'Consumer' {
                & $add $k 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1 'Disable Microsoft consumer experiences'
            }
            'Suggestions' {
                foreach($n in @('SilentInstalledAppsEnabled','SoftLandingEnabled','SystemPaneSuggestionsEnabled','SubscribedContent-338388Enabled','SubscribedContent-338389Enabled','SubscribedContent-353694Enabled','SubscribedContent-353696Enabled')) {
                    & $add $k 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' $n 0 'Disable tips, suggestions and silent app installs'
                }
            }
            'Ads' {
                & $add $k 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0 'Disable advertising ID'
                & $add $k 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0 'Disable tailored experiences'
            }
            'Activity' {
                foreach($n in @('EnableActivityFeed','PublishUserActivities','UploadUserActivities')) {
                    & $add $k 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' $n 0 'Disable Activity History publishing/upload'
                }
            }
            'EdgeBackground' {
                & $add $k 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'StartupBoostEnabled' 0 'Disable Edge startup boost'
                & $add $k 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'BackgroundModeEnabled' 0 'Disable Edge background mode'
            }
            'Widgets' {
                & $add $k 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0 'Disable Widgets'
                & $add $k 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarDa' 0 'Hide the taskbar Widgets button'
            }
            'BingSearch' {
                & $add $k 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1 'Disable Bing web suggestions in Search'
            }
            'Copilot' {
                & $add $k 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1 'Disable Microsoft Copilot'
            }
            'Recall' {
                & $add $k 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'AllowRecallEnablement' 0 'Disable Windows Recall availability'
            }
            'Transparency' {
                & $add $k 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0 'Disable transparency effects'
            }
            'GameDvr' {
                & $add $k 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0 'Disable Game DVR background capture'
                & $add $k 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0 'Disable Game DVR'
            }
            'Delivery' {
                & $add $k 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 0 'Disable Delivery Optimization peer-to-peer'
            }
        }
    }
    return $plan.ToArray()
}

function Get-KRegistryTargetsForKeys {
    param([string[]]$Keys)
    return @(Get-KRegistryPlan -Keys $Keys | ForEach-Object { @{Path=$_.Path;Name=$_.Name} })
}

function Get-KRegistryChangePreview {
    param([string[]]$Keys)
    $plan = @(Get-KRegistryPlan -Keys $Keys)
    if ($plan.Count -eq 0) { return 'Nothing selected.' }
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add(('FOCS will write {0} registry value(s):' -f $plan.Count))
    $lines.Add('')
    foreach ($p in $plan) {
        $snap = Get-RegValueSnapshot -Path $p.Path -Name $p.Name
        $current = if ($snap.Exists) { [string]$snap.Value } else { '(not set)' }
        if ([string]$current -eq [string]$p.Value) {
            $lines.Add(('  {0}\{1}: already {2} - no change' -f $p.Path,$p.Name,$p.Value))
        } else {
            $lines.Add(('  {0}\{1}: {2} -> {3}' -f $p.Path,$p.Name,$current,$p.Value))
        }
    }
    $lines.Add('')
    $lines.Add('Every value above is captured in registry_value_journal.json first, and RESTORE_FOCS.ps1 puts them back.')
    return ($lines -join "`r`n")
}

function Apply-KRegistryKeys {
    param([string[]]$Keys,[string]$Reason='Custom registry selection')
    if (-not $Keys -or $Keys.Count -eq 0) { return $null }
    $plan = @(Get-KRegistryPlan -Keys $Keys)
    if ($plan.Count -eq 0) { return $null }
    $backup = New-KBackup
    Save-RegValueJournal -Folder $backup -Targets (Get-KRegistryTargetsForKeys -Keys $Keys)
    $written = 0
    $failed = 0
    foreach ($p in $plan) {
        try {
            Set-RegDword $p.Path $p.Name $p.Value
            $written++
        } catch {
            $failed++
            Write-KLog "Registry write failed $($p.Path)\$($p.Name): $($_.Exception.Message)"
        }
    }
    Write-KLog "$Reason complete. Values written=$written failed=$failed Backup=$backup"
    if ($failed -gt 0 -and $written -eq 0) { throw "None of the selected registry changes could be written. See $script:LogFile." }
    return $backup
}

function Apply-KRegistryList {
    param([System.Windows.Forms.CheckedListBox]$List,[switch]$NoPrompt)
    $catalog = Get-KRegistryCatalog
    $keys = [System.Collections.Generic.List[string]]::new()
    foreach($item in @($List.CheckedItems)) {
        $display = [string]$item
        if ($catalog.Contains($display)) { $keys.Add([string]$catalog[$display]) }
    }
    if ($keys.Count -eq 0) { throw 'No registry/debloat tweaks are selected.' }
    if (-not $NoPrompt) {
        # Show exactly what will change before anything is written.
        $preview = Get-KRegistryChangePreview -Keys $keys.ToArray()
        $answer = [System.Windows.Forms.MessageBox]::Show(
            ($preview + "`r`n`r`nApply these changes?"),
            'FOCS registry change preview',
            [System.Windows.Forms.MessageBoxButtons]::OKCancel,
            [System.Windows.Forms.MessageBoxIcon]::Information)
        if ($answer -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
    }
    return Apply-KRegistryKeys -Keys $keys.ToArray() -Reason 'Registry selection'
}

function Apply-KProfileRegistryDefaults {
    param([ValidateSet('Recommended','Minimal','Competitive','Custom')][string]$Profile)
    if ($Profile -eq 'Minimal' -or $Profile -eq 'Custom') { return $null }
    $keys = @('Consumer','Suggestions','Ads','EdgeBackground','Widgets')
    if ($Profile -eq 'Competitive') { $keys += @('Transparency','BingSearch') }
    return Apply-KRegistryKeys -Keys $keys -Reason ("Profile registry preset: $Profile")
}

function Remove-KAppxPattern {
    param([string]$Pattern,[ValidateSet('CurrentUser','AllUsers')][string]$Scope='CurrentUser')
    $removed = 0
    if ($Scope -eq 'AllUsers') {
        $pkgs = @(Get-AppxPackage -AllUsers -Name $Pattern -ErrorAction SilentlyContinue)
        foreach($pkg in $pkgs) {
            try { Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop; $removed++; Write-KLog "Removed AppX all-users: $($pkg.Name)" } catch { Write-KLog "AppX remove failed $($pkg.Name): $($_.Exception.Message)" }
        }
        $prov = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $Pattern })
        foreach($pkg in $prov) {
            try { Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop | Out-Null; Write-KLog "Deprovisioned AppX: $($pkg.DisplayName)" } catch { Write-KLog "AppX deprovision failed $($pkg.DisplayName): $($_.Exception.Message)" }
        }
    } else {
        $pkgs = @(Get-AppxPackage -Name $Pattern -ErrorAction SilentlyContinue)
        foreach($pkg in $pkgs) {
            try { Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop; $removed++; Write-KLog "Removed AppX current-user: $($pkg.Name)" } catch { Write-KLog "AppX remove failed $($pkg.Name): $($_.Exception.Message)" }
        }
    }
    return $removed
}

function Remove-KSelectedBloat {
    param([System.Windows.Forms.CheckedListBox]$List,[ValidateSet('CurrentUser','AllUsers')][string]$Scope='CurrentUser')
    $selected = @($List.CheckedItems)
    if ($selected.Count -eq 0) { throw 'No apps are selected for removal.' }
    $catalog = Get-KDebloatCatalog
    $backup = New-KBackup
    try {
        Get-AppxPackage -AllUsers | Select-Object Name,PackageFullName,PackageFamilyName,InstallLocation | Export-Csv -LiteralPath (Join-Path $backup 'appx_before.csv') -NoTypeInformation -Encoding UTF8
        Get-AppxProvisionedPackage -Online | Select-Object DisplayName,PackageName | Export-Csv -LiteralPath (Join-Path $backup 'provisioned_appx_before.csv') -NoTypeInformation -Encoding UTF8
    } catch { Write-KLog "Could not save complete AppX inventory: $($_.Exception.Message)" }
    $count = 0
    foreach($item in $selected) {
        $display = [string]$item
        if (-not $catalog.Contains($display)) { continue }
        foreach($pattern in @($catalog[$display])) { $count += Remove-KAppxPattern -Pattern ([string]$pattern) -Scope $Scope }
    }
    Write-KLog "Debloat removal completed. Removed registered packages=$count Scope=$Scope Backup=$backup"
    return "Removal pass complete. Registered packages removed: $count`r`nScope: $Scope`r`nInventory/backup: $backup"
}

function Uninstall-KOneDrive {
    $winget = Get-KWinget
    try { Get-Process OneDrive -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue } catch {}
    if ($winget) {
        $p = Start-Process -FilePath $winget -ArgumentList @('uninstall','--id','Microsoft.OneDrive','--exact','--silent','--accept-source-agreements','--disable-interactivity') -PassThru -Wait
        if ($p.ExitCode -eq 0) { Write-KLog 'OneDrive uninstalled via winget.'; return 'OneDrive uninstall completed via winget.' }
        # 0x8A150014 / -1978335212 is WinGet's documented
        # APPINSTALLER_CLI_ERROR_NO_APPLICATIONS_FOUND result. For an uninstall
        # request this means the desired end state is already satisfied.
        if ($p.ExitCode -eq -1978335212) {
            Write-KLog 'OneDrive is already absent; winget found no installed package.'
            return 'OneDrive is not installed. No changes were needed.'
        }
        Write-KLog "winget OneDrive uninstall exit code $($p.ExitCode); trying Windows setup fallback."
    }
    $candidates = @((Join-Path $env:SystemRoot 'SysWOW64\OneDriveSetup.exe'),(Join-Path $env:SystemRoot 'System32\OneDriveSetup.exe'))
    foreach($setup in $candidates) {
        if (Test-Path -LiteralPath $setup) {
            $p = Start-Process -FilePath $setup -ArgumentList '/uninstall' -PassThru -Wait
            Write-KLog "OneDriveSetup uninstall exit code $($p.ExitCode)."
            return 'OneDrive uninstall command completed. Existing synced files are not deleted by the uninstaller.'
        }
    }
    throw 'No supported OneDrive uninstaller was found.'
}

function Install-KOneDrive {
    $winget = Get-KWinget
    if (-not $winget) { throw 'winget is required for the FOCS OneDrive reinstall button.' }
    $p = Start-Process -FilePath $winget -ArgumentList @('install','--id','Microsoft.OneDrive','--exact','--silent','--accept-package-agreements','--accept-source-agreements','--disable-interactivity') -PassThru -Wait
    if ($p.ExitCode -ne 0) { throw "winget OneDrive install returned $($p.ExitCode)." }
    Write-KLog 'OneDrive installed via winget.'
    return 'OneDrive install/update completed through winget.'
}

function Uninstall-KEdgeSupported {
    $winget = Get-KWinget
    if (-not $winget) { throw 'winget is not available. FOCS will not use force-delete Edge removal methods.' }
    $p = Start-Process -FilePath $winget -ArgumentList @('uninstall','--id','Microsoft.Edge','--exact','--silent','--accept-source-agreements','--disable-interactivity') -PassThru -Wait
    if ($p.ExitCode -ne 0) {
        throw "Windows/winget did not expose a supported Edge uninstall on this system (exit $($p.ExitCode)). FOCS intentionally will not force-delete Edge/WebView components. Use the Edge background/debloat policies instead."
    }
    Write-KLog 'Microsoft Edge uninstalled through supported winget path.'
    return 'Microsoft Edge uninstall completed through the supported package-manager path.'
}

function Set-KSelectedServices {
    param([System.Windows.Forms.CheckedListBox]$List,[ValidateSet('Manual','Disabled')][string]$Mode='Manual')
    $selected = @($List.CheckedItems)
    if ($selected.Count -eq 0) { throw 'No services are selected.' }
    $backup = New-KBackup
    $changed = [System.Collections.Generic.List[object]]::new()
    foreach($item in $selected) {
        $name = ([string]$item -split ' - ',2)[0].Trim()
        if (-not $name) { continue }
        $svc = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f ($name -replace "'","''")) -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $svc) { Write-KLog "Service not present, skipped: $name"; continue }
        try {
            $changed.Add([pscustomobject]@{ Name=$name; StartMode=[string]$svc.StartMode; ChangedTo=$Mode; At=(Get-Date).ToString('o') })
            if ($Mode -eq 'Disabled') {
                if ($svc.State -eq 'Running') { Stop-Service -Name $name -Force -ErrorAction SilentlyContinue }
                Set-Service -Name $name -StartupType Disabled -ErrorAction Stop
            } else { Set-Service -Name $name -StartupType Manual -ErrorAction Stop }
            Write-KLog "Service $name -> $Mode (was $($svc.StartMode))"
        } catch { Write-KLog "Service change failed ${name}: $($_.Exception.Message)" }
    }
    Save-KServiceChangeJournal -Folder $backup -Entries $changed.ToArray()
    return $backup
}

function Get-KPhysicalAdapters {
    try { return @(Get-NetAdapter -Physical -ErrorAction Stop | Where-Object Status -ne 'Disabled' | Sort-Object Name) } catch { return @() }
}

function Set-FocsRscState {
    param(
        [Parameter(Mandatory=$true)][string]$AdapterName,
        [Nullable[bool]]$IPv4=$null,
        [Nullable[bool]]$IPv6=$null
    )
    if ($null -ne $IPv4) {
        if ($IPv4) { Enable-NetAdapterRsc -Name $AdapterName -IPv4 -NoRestart -ErrorAction Stop }
        else { Disable-NetAdapterRsc -Name $AdapterName -IPv4 -NoRestart -ErrorAction Stop }
    }
    if ($null -ne $IPv6) {
        if ($IPv6) { Enable-NetAdapterRsc -Name $AdapterName -IPv6 -NoRestart -ErrorAction Stop }
        else { Disable-NetAdapterRsc -Name $AdapterName -IPv6 -NoRestart -ErrorAction Stop }
    }
}

function Get-KNicTunableProperties {
    param([string]$AdapterName)
    if ([string]::IsNullOrWhiteSpace($AdapterName)) { return @() }
    try {
        return @(Get-NetAdapterAdvancedProperty -Name $AdapterName -ErrorAction Stop | Where-Object {
            $_.DisplayName -match 'Interrupt|Energy Efficient|EEE|Green Ethernet|Flow Control|Receive Side|RSS|Large Send Offload|LSO|Jumbo|Power|Priority|VLAN'
        } | Sort-Object DisplayName)
    } catch { return @() }
}

function Save-KNicState {
    param([string]$Folder,[string]$AdapterName)
    $props = @()
    try {
        $props = @(Get-NetAdapterAdvancedProperty -Name $AdapterName -ErrorAction Stop | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.DisplayName) -and -not [string]::IsNullOrWhiteSpace([string]$_.DisplayValue) } | Select-Object DisplayName,DisplayValue,RegistryKeyword)
    } catch {}
    $rss = $null; $rsc = $null
    try { $rss = Get-NetAdapterRss -Name $AdapterName -ErrorAction Stop } catch {}
    try { $rsc = Get-NetAdapterRsc -Name $AdapterName -ErrorAction Stop } catch {}
    [pscustomobject]@{
        Adapter=$AdapterName
        Properties=$props
        RssEnabled=if($rss){[bool]$rss.Enabled}else{$null}
        RscV4=if($rsc){[bool]$rsc.IPv4Enabled}else{$null}
        RscV6=if($rsc){[bool]$rsc.IPv6Enabled}else{$null}
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Folder 'nic_advanced.json') -Encoding UTF8

    $restore = Join-Path $Folder 'RESTORE_FOCS.ps1'
    if (Test-Path -LiteralPath $restore) {
        Add-Content -LiteralPath $restore -Encoding UTF8 -Value @'

# FOCS NIC advanced-property restore
$nicFile = Join-Path $folder 'nic_advanced.json'
if (Test-Path -LiteralPath $nicFile) {
    try {
        $nic = Get-Content -LiteralPath $nicFile -Raw | ConvertFrom-Json
        foreach ($p in @($nic.Properties)) {
            $dn=[string]$p.DisplayName; $dv=[string]$p.DisplayValue
            if (-not [string]::IsNullOrWhiteSpace($dn) -and -not [string]::IsNullOrWhiteSpace($dv)) {
                try { Set-NetAdapterAdvancedProperty -Name $nic.Adapter -DisplayName $dn -DisplayValue $dv -NoRestart -ErrorAction Stop } catch {}
            }
        }
        if ($null -ne $nic.RssEnabled) { if ($nic.RssEnabled) { Enable-NetAdapterRss -Name $nic.Adapter -ErrorAction SilentlyContinue } else { Disable-NetAdapterRss -Name $nic.Adapter -ErrorAction SilentlyContinue } }
        if ($null -ne $nic.RscV4) { if ($nic.RscV4) { Enable-NetAdapterRsc -Name $nic.Adapter -IPv4 -NoRestart -ErrorAction SilentlyContinue } else { Disable-NetAdapterRsc -Name $nic.Adapter -IPv4 -NoRestart -ErrorAction SilentlyContinue } }
        if ($null -ne $nic.RscV6) { if ($nic.RscV6) { Enable-NetAdapterRsc -Name $nic.Adapter -IPv6 -NoRestart -ErrorAction SilentlyContinue } else { Disable-NetAdapterRsc -Name $nic.Adapter -IPv6 -NoRestart -ErrorAction SilentlyContinue } }
        Restart-NetAdapter -Name $nic.Adapter -Confirm:$false -ErrorAction SilentlyContinue
    } catch {}
}
'@
    }
}

function Get-KActualValidNicValue {
    param([object]$Property,[string[]]$Candidates)
    $valid = @($Property.ValidDisplayValues) | Where-Object { $_ }
    foreach($c in $Candidates) {
        $m = $valid | Where-Object { ([string]$_).Equals($c,[StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
        if ($m) { return [string]$m }
    }
    return $null
}

function Set-KNicAdvancedValue {
    param([string]$AdapterName,[string]$DisplayName,[string]$DisplayValue,[string]$BackupFolder=$null)
    if([string]::IsNullOrWhiteSpace($AdapterName) -or [string]::IsNullOrWhiteSpace($DisplayName) -or [string]::IsNullOrWhiteSpace($DisplayValue)){throw 'Choose an adapter, property and a non-empty driver value.'}
    if (-not $BackupFolder) { $BackupFolder = New-KBackup; Save-KNicState -Folder $BackupFolder -AdapterName $AdapterName }
    Set-NetAdapterAdvancedProperty -Name $AdapterName -DisplayName $DisplayName -DisplayValue $DisplayValue -NoRestart -ErrorAction Stop
    Restart-NetAdapter -Name $AdapterName -Confirm:$false -ErrorAction SilentlyContinue
    Write-KLog "NIC advanced property: [$AdapterName] $DisplayName -> $DisplayValue | Backup=$BackupFolder"
    return $BackupFolder
}

function Apply-KNicLatencyPreset {
    param(
        [string]$AdapterName,
        [bool]$InterruptModeration=$false,
        [bool]$EnergyEfficient=$false,
        [bool]$FlowControl=$false,
        [bool]$LargeSendOffload=$false,
        [bool]$DisableRsc=$false
    )
    if ([string]::IsNullOrWhiteSpace($AdapterName)) { throw 'Choose a network adapter first.' }
    $backup = New-KBackup
    Save-KNicState -Folder $backup -AdapterName $AdapterName
    $props = @(Get-NetAdapterAdvancedProperty -Name $AdapterName -ErrorAction Stop)
    $changes = [System.Collections.Generic.List[string]]::new()
    foreach($p in $props) {
        $target = $null
        if ($InterruptModeration -and $p.DisplayName -match '^Interrupt Moderation$') { $target = Get-KActualValidNicValue $p @('Low','Minimal','Adaptive','Enabled','On') }
        elseif ($InterruptModeration -and $p.DisplayName -match 'Interrupt Moderation Rate') { $target = Get-KActualValidNicValue $p @('Low','Minimal','Adaptive') }
        elseif ($EnergyEfficient -and $p.DisplayName -match 'Energy Efficient|Green Ethernet|Advanced EEE|^EEE') { $target = Get-KActualValidNicValue $p @('Disabled','Off') }
        elseif ($FlowControl -and $p.DisplayName -match '^Flow Control$') { $target = Get-KActualValidNicValue $p @('Disabled','Off') }
        elseif ($LargeSendOffload -and $p.DisplayName -match 'Large Send Offload|LSO') { $target = Get-KActualValidNicValue $p @('Disabled','Off') }
        elseif ($p.DisplayName -match 'Receive Side Scaling|^RSS$') { $target = Get-KActualValidNicValue $p @('Enabled','On') }
        if ($target) {
            try { Set-NetAdapterAdvancedProperty -Name $AdapterName -DisplayName $p.DisplayName -DisplayValue $target -NoRestart -ErrorAction Stop; $changes.Add("$($p.DisplayName)=$target") } catch { Write-KLog "NIC preset skipped $($p.DisplayName): $($_.Exception.Message)" }
        }
    }
    try { Enable-NetAdapterRss -Name $AdapterName -ErrorAction Stop; $changes.Add('RSS=Enabled') } catch {}
    if ($DisableRsc) { try { Disable-NetAdapterRsc -Name $AdapterName -ErrorAction Stop; $changes.Add('RSC=Disabled') } catch {} }
    Restart-NetAdapter -Name $AdapterName -Confirm:$false -ErrorAction SilentlyContinue
    Write-KLog "NIC latency preset: [$AdapterName] $($changes -join ', ') | Backup=$backup"
    return "Applied adapter-specific latency preset to $AdapterName.`r`nChanges: $($changes -join ', ')`r`nBackup: $backup`r`nRe-test ping/jitter and game behavior; lower interrupt moderation can increase CPU load."
}

function Restore-KLatestNicBackup {
    $latest = Get-ChildItem -LiteralPath $script:BackupRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'nic_advanced.json') } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latest) { throw 'No FOCS NIC backup was found.' }
    $nic = Get-Content -LiteralPath (Join-Path $latest.FullName 'nic_advanced.json') -Raw | ConvertFrom-Json
    $restoredProps=0; $skippedProps=0
    foreach($p in @($nic.Properties)) {
        $dn=[string]$p.DisplayName; $dv=[string]$p.DisplayValue
        if([string]::IsNullOrWhiteSpace($dn) -or [string]::IsNullOrWhiteSpace($dv)) { $skippedProps++; continue }
        try {
            Set-NetAdapterAdvancedProperty -Name $nic.Adapter -DisplayName $dn -DisplayValue $dv -NoRestart -ErrorAction Stop
            $restoredProps++
        } catch {
            $skippedProps++
            Write-KLog "NIC restore skipped ${dn}=${dv}: $($_.Exception.Message)"
        }
    }
    if($null -ne $nic.RssEnabled){if($nic.RssEnabled){Enable-NetAdapterRss -Name $nic.Adapter -ErrorAction SilentlyContinue}else{Disable-NetAdapterRss -Name $nic.Adapter -ErrorAction SilentlyContinue}}
    try { Set-FocsRscState -AdapterName ([string]$nic.Adapter) -IPv4 $nic.RscV4 -IPv6 $nic.RscV6 } catch { Write-KLog "RSC restore failed: $($_.Exception.Message)" }
    & netsh.exe interface tcp set global autotuninglevel=normal | Out-Null
    & netsh.exe interface tcp set global rss=enabled | Out-Null
    & netsh.exe interface tcp set global rsc=default | Out-Null
    Restart-NetAdapter -Name $nic.Adapter -Confirm:$false -ErrorAction SilentlyContinue
    Write-KLog "Restored latest NIC snapshot from $($latest.FullName)"
    return "Restored NIC settings from:`r`n$($latest.FullName)`r`nAdvanced properties restored: $restoredProps | skipped: $skippedProps`r`nRestart Windows before testing again."
}

function Reset-KNicDriverDefaults {
    param([string]$AdapterName)
    if([string]::IsNullOrWhiteSpace($AdapterName)){throw 'Choose a network adapter first.'}
    $backup=New-KBackup
    Save-KNicState -Folder $backup -AdapterName $AdapterName
    Reset-NetAdapterAdvancedProperty -Name $AdapterName -DisplayName '*' -NoRestart -ErrorAction Stop
    Enable-NetAdapterRss -Name $AdapterName -ErrorAction SilentlyContinue
    & netsh.exe interface tcp set global autotuninglevel=normal | Out-Null
    & netsh.exe interface tcp set global rss=enabled | Out-Null
    & netsh.exe interface tcp set global rsc=default | Out-Null
    Restart-NetAdapter -Name $AdapterName -Confirm:$false -ErrorAction SilentlyContinue
    Write-KLog "NIC driver defaults restored: $AdapterName | pre-reset backup=$backup"
    return "Factory/default advanced properties restored for $AdapterName.`r`nPre-reset backup: $backup"
}


function Get-FocsNicCounters {
    param([string]$AdapterName)
    try {
        $s=Get-NetAdapterStatistics -Name $AdapterName -ErrorAction Stop
        return [pscustomobject]@{
            RxErrors=[uint64]$s.ReceivedPacketErrors
            TxErrors=[uint64]$s.OutboundPacketErrors
            RxDiscards=[uint64]$s.ReceivedDiscardedPackets
            TxDiscards=[uint64]$s.OutboundDiscardedPackets
        }
    } catch {
        return [pscustomobject]@{RxErrors=0;TxErrors=0;RxDiscards=0;TxDiscards=0}
    }
}

function Get-FocsCounterDelta {
    param([object]$Before,[object]$After)
    $rxErr=[math]::Max([double]0,([double]$After.RxErrors-[double]$Before.RxErrors))
    $txErr=[math]::Max([double]0,([double]$After.TxErrors-[double]$Before.TxErrors))
    $rxDrop=[math]::Max([double]0,([double]$After.RxDiscards-[double]$Before.RxDiscards))
    $txDrop=[math]::Max([double]0,([double]$After.TxDiscards-[double]$Before.TxDiscards))
    [pscustomobject]@{Errors=($rxErr+$txErr);Discards=($rxDrop+$txDrop)}
}

function Get-FocsValidPropertyValue {
    param([object]$Property,[string[]]$Preferred)
    $valid=@($Property.ValidDisplayValues)|Where-Object{$_}
    foreach($v in $Preferred){
        $m=$valid|Where-Object{([string]$_).Equals($v,[StringComparison]::OrdinalIgnoreCase)}|Select-Object -First 1
        if($m){return [string]$m}
    }
    return $null
}

function Set-FocsPropertyPattern {
    param([string]$AdapterName,[string]$Pattern,[string[]]$Preferred,[System.Collections.Generic.List[string]]$Changes)
    $props=@(Get-NetAdapterAdvancedProperty -Name $AdapterName -ErrorAction SilentlyContinue|Where-Object{$_.DisplayName -match $Pattern})
    foreach($p in $props){
        $value=Get-FocsValidPropertyValue -Property $p -Preferred $Preferred
        if($value -and ([string]$p.DisplayValue) -ne $value){
            try{
                Set-NetAdapterAdvancedProperty -Name $AdapterName -DisplayName ([string]$p.DisplayName) -DisplayValue $value -NoRestart -ErrorAction Stop
                $Changes.Add("$($p.DisplayName)=$value")
            }catch{Write-KLog "Stability profile skipped $($p.DisplayName): $($_.Exception.Message)"}
        }
    }
}

function Set-FocsMaxNumericProperty {
    param([string]$AdapterName,[string]$Pattern,[System.Collections.Generic.List[string]]$Changes)
    $props=@(Get-NetAdapterAdvancedProperty -Name $AdapterName -ErrorAction SilentlyContinue|Where-Object{$_.DisplayName -match $Pattern})
    foreach($p in $props){
        $vals=@($p.ValidDisplayValues)|Where-Object{$_ -and ([string]$_ -match '^\\d+$')}|ForEach-Object{[int]([string]$_)}
        if($vals.Count -gt 0){
            $max=($vals|Measure-Object -Maximum).Maximum
            if($max -and ([string]$p.DisplayValue) -ne ([string]$max)){
                try{Set-NetAdapterAdvancedProperty -Name $AdapterName -DisplayName ([string]$p.DisplayName) -DisplayValue ([string]$max) -NoRestart -ErrorAction Stop;$Changes.Add("$($p.DisplayName)=$max")}catch{}
            }
        }
    }
}

function Apply-FocsFortniteStabilityBaseline {
    param([string]$AdapterName)
    if([string]::IsNullOrWhiteSpace($AdapterName)){throw 'Choose a network adapter first.'}
    $backup=New-KBackup
    Save-KNicState -Folder $backup -AdapterName $AdapterName
    $changes=[System.Collections.Generic.List[string]]::new()

    # Windows baseline: keep scaling/offloads enabled and avoid power-saving transitions.
    try{& netsh.exe interface tcp set global autotuninglevel=normal|Out-Null;$changes.Add('TCP Auto-Tuning=Normal')}catch{}
    try{& netsh.exe interface tcp set global rss=enabled|Out-Null;$changes.Add('OS RSS=Enabled')}catch{}
    try{Enable-NetAdapterRss -Name $AdapterName -ErrorAction Stop;$changes.Add('NIC RSS=Enabled')}catch{}
    try{Enable-NetAdapterRsc -Name $AdapterName -ErrorAction Stop;$changes.Add('RSC=Enabled')}catch{}
    try{Enable-NetAdapterLso -Name $AdapterName -IPv4 -IPv6 -NoRestart -ErrorAction Stop;$changes.Add('LSO=Enabled')}catch{}
    try{Enable-NetAdapterChecksumOffload -Name $AdapterName -IpIPv4 -TcpIPv4 -TcpIPv6 -UdpIPv4 -UdpIPv6 -NoRestart -ErrorAction Stop;$changes.Add('Checksum Offload=Enabled')}catch{}

    # Stability-first driver values. Every setting is applied only when the driver exposes the value.
    Set-FocsPropertyPattern -AdapterName $AdapterName -Pattern 'Speed.*Duplex|Link Speed.*Duplex' -Preferred @('Auto Negotiation','Auto','Auto Detect') -Changes $changes
    Set-FocsPropertyPattern -AdapterName $AdapterName -Pattern 'Jumbo' -Preferred @('Disabled','Off','1514 Bytes','1500 Bytes') -Changes $changes
    Set-FocsPropertyPattern -AdapterName $AdapterName -Pattern 'Energy Efficient|Green Ethernet|Advanced EEE|^EEE' -Preferred @('Disabled','Off') -Changes $changes
    Set-FocsPropertyPattern -AdapterName $AdapterName -Pattern '^Interrupt Moderation$' -Preferred @('Enabled','On','Adaptive') -Changes $changes
    Set-FocsPropertyPattern -AdapterName $AdapterName -Pattern 'Interrupt Moderation Rate' -Preferred @('Adaptive','Medium','Normal','Enabled') -Changes $changes
    Set-FocsPropertyPattern -AdapterName $AdapterName -Pattern 'Receive Side Scaling|^RSS$' -Preferred @('Enabled','On') -Changes $changes
    Set-FocsPropertyPattern -AdapterName $AdapterName -Pattern 'Large Send Offload|LSO' -Preferred @('Enabled','On') -Changes $changes
    Set-FocsPropertyPattern -AdapterName $AdapterName -Pattern 'TCP.*Checksum|UDP.*Checksum|IPv4.*Checksum' -Preferred @('Rx & Tx Enabled','Rx and Tx Enabled','Enabled','On') -Changes $changes
    Set-FocsMaxNumericProperty -AdapterName $AdapterName -Pattern 'Receive Buffers' -Changes $changes
    Set-FocsMaxNumericProperty -AdapterName $AdapterName -Pattern 'Transmit Buffers' -Changes $changes

    try{
        $pm=Get-NetAdapterPowerManagement -Name $AdapterName -ErrorAction Stop
        if($pm.PSObject.Properties['SelectiveSuspend'] -and [string]$pm.SelectiveSuspend -ne 'Unsupported'){$pm.SelectiveSuspend='Disabled'}
        if($pm.PSObject.Properties['DeviceSleepOnDisconnect'] -and [string]$pm.DeviceSleepOnDisconnect -ne 'Unsupported'){$pm.DeviceSleepOnDisconnect='Disabled'}
        if($pm.PSObject.Properties['D0PacketCoalescing'] -and [string]$pm.D0PacketCoalescing -ne 'Unsupported'){$pm.D0PacketCoalescing='Disabled'}
        if($pm.PSObject.Properties['AllowComputerToTurnOffDevice'] -and [string]$pm.AllowComputerToTurnOffDevice -ne 'Unsupported'){$pm.AllowComputerToTurnOffDevice='Disabled'}
        $pm|Set-NetAdapterPowerManagement -NoRestart -ErrorAction SilentlyContinue
        $changes.Add('NIC power-saving sleep=Disabled')
    }catch{}

    Restart-NetAdapter -Name $AdapterName -Confirm:$false -ErrorAction SilentlyContinue
    $deadline=(Get-Date).AddSeconds(20)
    do{Start-Sleep -Milliseconds 500;try{$up=(Get-NetAdapter -Name $AdapterName -ErrorAction Stop).Status -eq 'Up'}catch{$up=$false}}while(-not $up -and (Get-Date) -lt $deadline)
    Start-Sleep -Seconds 2
    Write-KLog "Fortnite stability baseline applied: [$AdapterName] $($changes -join ', ') | Backup=$backup"
    [pscustomobject]@{Backup=$backup;Changes=$changes.ToArray()}
}

function Invoke-FocsFortniteStabilityTune {
    param([string]$AdapterName,[ValidateSet('Quick','Balanced','Deep')][string]$Mode='Balanced',[string]$CustomTarget,[System.Windows.Forms.TextBox]$OutputBox)
    if([string]::IsNullOrWhiteSpace($AdapterName)){throw 'Choose a network adapter first.'}
    $plan=Get-FocsNetworkTestPlan -Mode $Mode
    $original=Get-FocsNicSnapshot -AdapterName $AdapterName
    $write={param([string]$t)if($OutputBox -and -not $OutputBox.IsDisposed){$OutputBox.AppendText(($t+"`r`n"));$OutputBox.SelectionStart=$OutputBox.TextLength;$OutputBox.ScrollToCaret();[System.Windows.Forms.Application]::DoEvents()}}
    if($OutputBox){$OutputBox.Clear()}
    & $write 'FORTNITE / DISCORD STABILITY TUNE'
    & $write 'Measuring current connection...'
    $before=Test-FocsNetworkSuite -AdapterName $AdapterName -CustomTarget $CustomTarget -Count $plan.Count -Repeats $plan.Repeats
    & $write (Format-FocsNetworkSuite $before 'CURRENT')
    & $write ''
    & $write 'Applying stability-first NIC and Windows settings...'
    $applied=Apply-FocsFortniteStabilityBaseline -AdapterName $AdapterName
    $after=Test-FocsNetworkSuite -AdapterName $AdapterName -CustomTarget $CustomTarget -Count $plan.Count -Repeats $plan.Repeats
    & $write (Format-FocsNetworkSuite $after 'STABILITY PROFILE')
    $keep=Test-FocsCandidateIsBetter -Candidate $after -Current $before
    if(-not $keep -and $after.GatewayLoss -le $before.GatewayLoss -and $after.LocalErrors -le $before.LocalErrors -and $after.LocalDiscards -le $before.LocalDiscards -and $after.InternetLoss -le ($before.InternetLoss+0.01)){
        # Keep a neutral stability result if it does not worsen loss/errors and tail latency is within noise.
        $keep=($after.InternetP95 -le ($before.InternetP95*1.03))
    }
    if($keep){
        & $write '';& $write 'KEEP: stability profile measured equal or better.'
        $labRoot=Join-Path $script:DataRoot 'NetworkLab';New-Item -ItemType Directory -Path $labRoot -Force|Out-Null
        $safe=($AdapterName -replace '[^A-Za-z0-9_.-]','_')
        $state=Get-FocsNicSnapshot -AdapterName $AdapterName
        [pscustomobject]@{Version=2;Created=(Get-Date).ToString('o');Adapter=$AdapterName;Mode='FortniteStability';FinalScore=$after.Score;FinalInternetLoss=$after.InternetLoss;FinalP95=$after.InternetP95;State=$state;Changes=$applied.Changes}|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $labRoot ("best_{0}.json" -f $safe)) -Encoding UTF8
    } else {
        & $write '';& $write 'ROLLBACK: measured result was worse; restoring original NIC state.'
        Set-FocsNicSnapshot -Snapshot $original
    }
    [pscustomobject]@{Kept=$keep;Before=$before;After=$after;Backup=$applied.Backup;Changes=$applied.Changes}
}


function Get-FocsNicSnapshot {
    param([string]$AdapterName)
    $props=@()
    try{$props=@(Get-NetAdapterAdvancedProperty -Name $AdapterName -ErrorAction Stop | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.DisplayName) -and -not [string]::IsNullOrWhiteSpace([string]$_.DisplayValue) } | Select-Object DisplayName,DisplayValue,RegistryKeyword)}catch{}
    $rss=$null;$rsc=$null
    try{$rss=Get-NetAdapterRss -Name $AdapterName -ErrorAction Stop}catch{}
    try{$rsc=Get-NetAdapterRsc -Name $AdapterName -ErrorAction Stop}catch{}
    [pscustomobject]@{
        Adapter=$AdapterName
        Properties=$props
        RssEnabled=if($rss){[bool]$rss.Enabled}else{$null}
        RscV4=if($rsc){[bool]$rsc.IPv4Enabled}else{$null}
        RscV6=if($rsc){[bool]$rsc.IPv6Enabled}else{$null}
    }
}

function Set-FocsNicSnapshot {
    param([object]$Snapshot,[object[]]$ExtraSettings=@(),[switch]$NoRestart)
    if(-not $Snapshot -or -not $Snapshot.Adapter){throw 'Invalid NIC snapshot.'}
    $name=[string]$Snapshot.Adapter
    foreach($p in @($Snapshot.Properties)){
        $dn=[string]$p.DisplayName; $dv=[string]$p.DisplayValue
        if(-not [string]::IsNullOrWhiteSpace($dn) -and -not [string]::IsNullOrWhiteSpace($dv)){
            try{Set-NetAdapterAdvancedProperty -Name $name -DisplayName $dn -DisplayValue $dv -NoRestart -ErrorAction Stop}catch{Write-KLog "Snapshot restore skipped ${dn}=${dv}: $($_.Exception.Message)"}
        }
    }
    if($null -ne $Snapshot.RssEnabled){try{if([bool]$Snapshot.RssEnabled){Enable-NetAdapterRss -Name $name -ErrorAction Stop}else{Disable-NetAdapterRss -Name $name -ErrorAction Stop}}catch{}}
    try { Set-FocsRscState -AdapterName $name -IPv4 $Snapshot.RscV4 -IPv6 $Snapshot.RscV6 } catch { Write-KLog "RSC snapshot restore failed for ${name}: $($_.Exception.Message)" }
    foreach($x in @($ExtraSettings)){
        if($x.Type -eq 'Property'){
            $xdn=[string]$x.DisplayName; $xdv=[string]$x.Value
            if([string]::IsNullOrWhiteSpace($xdn) -or [string]::IsNullOrWhiteSpace($xdv)){Write-KLog "Network Lab skipped blank property value: $($x.Label)";continue}
            try{Set-NetAdapterAdvancedProperty -Name $name -DisplayName $xdn -DisplayValue $xdv -NoRestart -ErrorAction Stop}catch{Write-KLog "Network Lab apply skipped $($x.Label): $($_.Exception.Message)"}
        } elseif($x.Type -eq 'RSC') {
            try{if([bool]$x.Enabled){Enable-NetAdapterRsc -Name $name -ErrorAction Stop}else{Disable-NetAdapterRsc -Name $name -ErrorAction Stop}}catch{}
        } elseif($x.Type -eq 'RSS') {
            try{if([bool]$x.Enabled){Enable-NetAdapterRss -Name $name -ErrorAction Stop}else{Disable-NetAdapterRss -Name $name -ErrorAction Stop}}catch{}
        }
    }
    if(-not $NoRestart){
        Restart-NetAdapter -Name $name -Confirm:$false -ErrorAction SilentlyContinue
        $deadline=(Get-Date).AddSeconds(20)
        do{Start-Sleep -Milliseconds 500;try{$up=(Get-NetAdapter -Name $name -ErrorAction Stop).Status -eq 'Up'}catch{$up=$false}}while(-not $up -and (Get-Date) -lt $deadline)
        Start-Sleep -Seconds 2
    }
}

function Get-FocsDefaultGateway {
    try{
        $r=Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction Stop | Where-Object {$_.NextHop -and $_.NextHop -ne '0.0.0.0'} | Sort-Object RouteMetric,InterfaceMetric | Select-Object -First 1
        if($r){return [string]$r.NextHop}
    }catch{}
    return $null
}

function Get-FocsNetworkTestPlan {
    param([ValidateSet('Quick','Balanced','Deep')][string]$Mode='Balanced')
    switch($Mode){
        'Quick'    {return [pscustomobject]@{Count=8;Repeats=1;Label='Quick'}}
        'Deep'     {return [pscustomobject]@{Count=20;Repeats=3;Label='Deep'}}
        default    {return [pscustomobject]@{Count=12;Repeats=2;Label='Balanced'}}
    }
}

function Test-FocsNetworkSuite {
    param([string]$AdapterName,[string]$CustomTarget,[int]$Count=12,[int]$Repeats=2)
    $gateway=Get-FocsDefaultGateway
    if(-not $gateway){throw 'Default IPv4 gateway was not found.'}
    $statsBefore=if($AdapterName){Get-FocsNicCounters -AdapterName $AdapterName}else{[pscustomobject]@{RxErrors=0;TxErrors=0;RxDiscards=0;TxDiscards=0}}
    $targets=[System.Collections.Generic.List[object]]::new()
    $targets.Add([pscustomobject]@{Name='Gateway';Host=$gateway;Kind='Gateway'})
    $targets.Add([pscustomobject]@{Name='Cloudflare';Host='1.1.1.1';Kind='Internet'})
    $targets.Add([pscustomobject]@{Name='Google';Host='8.8.8.8';Kind='Internet'})
    if(-not [string]::IsNullOrWhiteSpace($CustomTarget)){
        $ct=$CustomTarget.Trim()
        if(@($targets.ToArray() | ForEach-Object {$_.Host}) -notcontains $ct){$targets.Add([pscustomobject]@{Name='Game target';Host=$ct;Kind='Internet'})}
    }
    $rows=[System.Collections.Generic.List[object]]::new()
    foreach($t in $targets.ToArray()){
        for($r=1;$r -le $Repeats;$r++){
            try{$m=Test-NetworkLatency -HostName $t.Host -Count $Count -TimeoutMs 1200}
            catch{$m=[pscustomobject]@{Host=$t.Host;Sent=$Count;Received=0;LossPct=100;Min=9999;Avg=9999;Max=9999;P95=9999;Jitter=9999;StdDev=9999}}
            $rows.Add([pscustomobject]@{Name=$t.Name;Host=$t.Host;Kind=$t.Kind;Repeat=$r;LossPct=[double]$m.LossPct;Avg=[double]$m.Avg;P95=[double]$m.P95;Jitter=[double]$m.Jitter;StdDev=[double]$m.StdDev})
        }
    }
    $all=$rows.ToArray();$g=@($all|Where-Object Kind -eq 'Gateway');$i=@($all|Where-Object Kind -eq 'Internet')
    $gLoss=if($g){($g|Measure-Object LossPct -Average).Average}else{100};$iLoss=if($i){($i|Measure-Object LossPct -Average).Average}else{100}
    $gP95=if($g){($g|Measure-Object P95 -Average).Average}else{9999};$iP95=if($i){($i|Measure-Object P95 -Average).Average}else{9999}
    $iAvg=if($i){($i|Measure-Object Avg -Average).Average}else{9999};$iJitter=if($i){($i|Measure-Object Jitter -Average).Average}else{9999}
    $perTarget=[System.Collections.Generic.List[object]]::new()
    foreach($grp in @($i|Group-Object Host)){
        $pp=($grp.Group|Measure-Object P95 -Average).Average;$ll=($grp.Group|Measure-Object LossPct -Average).Average
        $perTarget.Add([pscustomobject]@{Host=$grp.Name;P95=[double]$pp;Loss=[double]$ll})
    }
    $worstInternetP95=if($perTarget.Count){[double](($perTarget.ToArray()|Measure-Object P95 -Maximum).Maximum)}else{9999}
    $gameTargetP95=$null
    if(-not [string]::IsNullOrWhiteSpace($CustomTarget)){
        $gt=@($perTarget.ToArray()|Where-Object Host -eq $CustomTarget.Trim()|Select-Object -First 1)
        if($gt){$gameTargetP95=[double]$gt[0].P95}
    }
    $gamingState=Get-FocsGamingLatencyState -P95 $worstInternetP95 -LossPct $iLoss
    $statsAfter=if($AdapterName){Get-FocsNicCounters -AdapterName $AdapterName}else{[pscustomobject]@{RxErrors=0;TxErrors=0;RxDiscards=0;TxDiscards=0}}
    $local=Get-FocsCounterDelta -Before $statsBefore -After $statsAfter
    # Low-latency gaming is tail-latency sensitive. Packet loss and NIC errors dominate,
    # then every millisecond above the 40 ms gaming P95 gate is penalised heavily.
    $gamingPenalty=[Math]::Max(0.0,$worstInternetP95-40.0)*60.0
    $score=($gLoss*6000)+($iLoss*5000)+($local.Errors*12000)+($local.Discards*6000)+($gP95*4)+($iP95*3)+($iJitter*12)+$iAvg+$gamingPenalty
    [pscustomobject]@{Gateway=$gateway;GatewayLoss=[double]$gLoss;InternetLoss=[double]$iLoss;GatewayP95=[double]$gP95;InternetP95=[double]$iP95;InternetWorstP95=[double]$worstInternetP95;GameTargetP95=$gameTargetP95;GamingState=$gamingState;InternetAvg=[double]$iAvg;InternetJitter=[double]$iJitter;LocalErrors=[double]$local.Errors;LocalDiscards=[double]$local.Discards;Score=[double]$score;Rows=$all;Targets=$perTarget.ToArray()}
}

function Format-FocsNetworkSuite {
    param([object]$M,[string]$Label='RESULT')
    $gt=if($null -ne $M.GameTargetP95){(' | game target P95: {0:N1} ms' -f $M.GameTargetP95)}else{''}
    @(
        $Label,
        ('Score: {0:N1} (lower is better)' -f $M.Score),
        ('Gaming gate: {0} | worst public/game P95: {1:N1} ms{2}' -f $M.GamingState,$M.InternetWorstP95,$gt),
        ('Gateway loss: {0:N2}% | P95: {1:N1} ms' -f $M.GatewayLoss,$M.GatewayP95),
        ('Internet loss: {0:N2}% | Avg: {1:N1} ms | mean P95: {2:N1} ms | Jitter: {3:N1} ms' -f $M.InternetLoss,$M.InternetAvg,$M.InternetP95,$M.InternetJitter),
        ('NIC errors/discards during test: {0:N0} / {1:N0}' -f $M.LocalErrors,$M.LocalDiscards)
    ) -join "`r`n"
}

function Test-FocsCandidateIsBetter {
    param([object]$Candidate,[object]$Current,[switch]$StrictLatency)
    if(-not $Candidate -or -not $Current){return $false}
    if($Candidate.GatewayLoss -gt ($Current.GatewayLoss + 0.01)){return $false}
    if($Candidate.InternetLoss -gt ($Current.InternetLoss + 0.50)){return $false}
    if($Current.InternetLoss -le 0.01 -and $Candidate.InternetLoss -gt 0.01){return $false}
    if($Current.GatewayLoss -le 0.01 -and $Candidate.GatewayLoss -gt 0.01){return $false}
    if($Candidate.LocalErrors -gt $Current.LocalErrors){return $false}
    if($Candidate.LocalDiscards -gt ($Current.LocalDiscards+1)){return $false}
    $curP95=[double]$Current.InternetWorstP95;$candP95=[double]$Candidate.InternetWorstP95
    $p95Slack=[Math]::Max(2.0,$curP95*0.05)
    if($candP95 -gt ($curP95+$p95Slack)){return $false}
    # Never trade a sub-40 ms gaming tail for a configuration that crosses the gaming gate.
    if($curP95 -lt 40.0 -and $candP95 -ge 40.0){return $false}
    if($StrictLatency -and $candP95 -gt ($curP95+2.0)){return $false}
    # If the current system fails the gaming gate, a meaningful P95 reduction is valuable even
    # when the aggregate score moves only slightly.
    if($curP95 -ge 40.0 -and $candP95 -le ($curP95-3.0) -and $Candidate.InternetLoss -le ($Current.InternetLoss+0.10)){return $true}
    if($Candidate.Score -lt ($Current.Score*0.985)){return $true}
    if($Candidate.InternetLoss -lt $Current.InternetLoss -and $candP95 -le ($curP95*1.03)){return $true}
    return $false
}

function Get-FocsNicLabCandidates {
    param([string]$AdapterName,[object]$BaseSnapshot)
    $list=[System.Collections.Generic.List[object]]::new()
    $props=@(Get-NetAdapterAdvancedProperty -Name $AdapterName -ErrorAction SilentlyContinue)
    foreach($p in $props){
        $name=[string]$p.DisplayName;$cur=[string]$p.DisplayValue;$valid=@($p.ValidDisplayValues)|Where-Object{$_}
        $wanted=@()
        if($name -match 'Speed.*Duplex|Link Speed.*Duplex'){$wanted=@('Auto Negotiation','Auto','Auto Detect')}
        elseif($name -match 'Jumbo'){$wanted=@('Disabled','Off','1514 Bytes','1500 Bytes')}
        elseif($name -match '^Interrupt Moderation$'){$wanted=@('Adaptive','Enabled','On','Low','Minimal','Disabled','Off')}
        elseif($name -match 'Interrupt Moderation Rate'){$wanted=@('Adaptive','Medium','Normal','Low','Minimal','Off')}
        elseif($name -match 'Energy Efficient|Green Ethernet|Advanced EEE|^EEE'){$wanted=@('Disabled','Off')}
        elseif($name -match '^Flow Control$'){$wanted=@('Rx & Tx Enabled','Rx and Tx Enabled','Enabled','Disabled','Off')}
        elseif($name -match 'Large Send Offload|LSO'){$wanted=@('Enabled','On','Disabled','Off')}
        elseif($name -match 'TCP.*Checksum|UDP.*Checksum|IPv4.*Checksum'){$wanted=@('Rx & Tx Enabled','Rx and Tx Enabled','Enabled','On')}
        elseif($name -match 'Receive Side Scaling|^RSS$'){$wanted=@('Enabled','On')}
        elseif($name -match 'Receive Buffers|Transmit Buffers'){
            # Ring-buffer growth trades throughput headroom for queueing delay: a bigger buffer
            # can let more traffic sit in the NIC before it is serviced. FOCS still tries the
            # driver's maximum, but Get-FocsNicCandidateRisk below forces a latency-safe
            # acceptance check for it, rather than accepting on aggregate score alone.
            $nums=$valid|Where-Object{([string]$_) -match '^\d+$'}|ForEach-Object{[int]([string]$_)}
            if($nums){$wanted=@([string](($nums|Measure-Object -Maximum).Maximum))}
        }
        elseif($name -match 'Power Saving|PowerSave'){$wanted=@('Disabled','Off')}
        else{continue}
        foreach($w in $wanted){
            $actual=$valid|Where-Object{([string]$_).Equals($w,[StringComparison]::OrdinalIgnoreCase)}|Select-Object -First 1
            if($actual -and ([string]$actual) -ne $cur){
                $risky=[bool]($name -match 'Receive Buffers|Transmit Buffers|^Flow Control$')
                $list.Add([pscustomobject]@{Type='Property';DisplayName=$name;Value=[string]$actual;Label="$name -> $actual";StrictLatency=$risky})
                break
            }
        }
    }
    $rsc=$null;try{$rsc=Get-NetAdapterRsc -Name $AdapterName -ErrorAction Stop}catch{}
    if($rsc){
        $enabled=[bool]($rsc.IPv4Enabled -or $rsc.IPv6Enabled)
        # RSC coalesces received segments and can add its own latency; treat it the same way.
        $list.Add([pscustomobject]@{Type='RSC';Enabled=(-not $enabled);Label=('RSC -> '+$(if($enabled){'Disabled'}else{'Enabled'}));StrictLatency=$true})
    }
    return @($list | Select-Object -First 14)
}

function Start-FocsNetworkAutoTune {
    param([string]$AdapterName,[ValidateSet('Quick','Balanced','Deep')][string]$Mode='Balanced',[string]$CustomTarget,[System.Windows.Forms.TextBox]$OutputBox)
    if([string]::IsNullOrWhiteSpace($AdapterName)){throw 'Choose a network adapter first.'}
    $plan=Get-FocsNetworkTestPlan -Mode $Mode
    $labRoot=Join-Path $script:DataRoot 'NetworkLab';New-Item -ItemType Directory -Path $labRoot -Force|Out-Null
    $runDir=Join-Path $labRoot (Get-Date -Format 'yyyyMMdd_HHmmss');New-Item -ItemType Directory -Path $runDir -Force|Out-Null
    $safeName=($AdapterName -replace '[^A-Za-z0-9_.-]','_')
    $bestPath=Join-Path $labRoot ("best_{0}.json" -f $safeName)
    $results=[System.Collections.Generic.List[object]]::new()
    $logLines=[System.Collections.Generic.List[string]]::new()
    $writeProgress={param([string]$Text)$logLines.Add($Text);if($OutputBox -and -not $OutputBox.IsDisposed){$OutputBox.Text=($logLines -join "`r`n");$OutputBox.SelectionStart=$OutputBox.TextLength;$OutputBox.ScrollToCaret();[System.Windows.Forms.Application]::DoEvents()}}

    & $writeProgress "FOCS Network Performance Lab - $Mode"
    & $writeProgress "Adapter: $AdapterName"
    & $writeProgress 'Stage 1/4: measuring current configuration...'
    $original=Get-FocsNicSnapshot -AdapterName $AdapterName
    $original|ConvertTo-Json -Depth 10|Set-Content -LiteralPath (Join-Path $runDir 'original_state.json') -Encoding UTF8
    $backup=New-KBackup
    Save-KNicState -Folder $backup -AdapterName $AdapterName
    & $writeProgress "Recovery backup: $backup"
    $completed=$false
    try {
    $currentMetrics=Test-FocsNetworkSuite -AdapterName $AdapterName -CustomTarget $CustomTarget -Count $plan.Count -Repeats $plan.Repeats
    $results.Add([pscustomobject]@{Stage='Current';Label='Current configuration';Accepted=$true;Score=$currentMetrics.Score;GatewayLoss=$currentMetrics.GatewayLoss;InternetLoss=$currentMetrics.InternetLoss;InternetP95=$currentMetrics.InternetP95;GamingP95=$currentMetrics.InternetWorstP95;GamingState=$currentMetrics.GamingState;InternetJitter=$currentMetrics.InternetJitter})
    & $writeProgress (Format-FocsNetworkSuite $currentMetrics 'CURRENT BASELINE')

    & $writeProgress '';& $writeProgress 'Stage 2/4: comparing NIC driver defaults...'
    try{
        Reset-NetAdapterAdvancedProperty -Name $AdapterName -DisplayName '*' -NoRestart -ErrorAction Stop
        Enable-NetAdapterRss -Name $AdapterName -ErrorAction SilentlyContinue
        & netsh.exe interface tcp set global autotuninglevel=normal | Out-Null
        & netsh.exe interface tcp set global rss=enabled | Out-Null
        & netsh.exe interface tcp set global rsc=default | Out-Null
        Restart-NetAdapter -Name $AdapterName -Confirm:$false -ErrorAction SilentlyContinue;Start-Sleep -Seconds 4
        $defaultSnapshot=Get-FocsNicSnapshot -AdapterName $AdapterName
        $defaultMetrics=Test-FocsNetworkSuite -AdapterName $AdapterName -CustomTarget $CustomTarget -Count $plan.Count -Repeats $plan.Repeats
        $acceptDefaults=Test-FocsCandidateIsBetter -Candidate $defaultMetrics -Current $currentMetrics
        $results.Add([pscustomobject]@{Stage='Defaults';Label='Driver defaults';Accepted=$acceptDefaults;Score=$defaultMetrics.Score;GatewayLoss=$defaultMetrics.GatewayLoss;InternetLoss=$defaultMetrics.InternetLoss;InternetP95=$defaultMetrics.InternetP95;GamingP95=$defaultMetrics.InternetWorstP95;GamingState=$defaultMetrics.GamingState;InternetJitter=$defaultMetrics.InternetJitter})
        & $writeProgress (Format-FocsNetworkSuite $defaultMetrics ('DRIVER DEFAULTS - '+$(if($acceptDefaults){'BETTER'}else{'NOT BETTER'})))
        if($acceptDefaults){$baseSnapshot=$defaultSnapshot;$bestMetrics=$defaultMetrics;& $writeProgress 'Using driver defaults as the new measured baseline.'}
        else{$baseSnapshot=$original;$bestMetrics=$currentMetrics;Set-FocsNicSnapshot -Snapshot $original;& $writeProgress 'Restored the original configuration.'}
    }catch{
        & $writeProgress "Driver-default comparison failed: $($_.Exception.Message)"
        $baseSnapshot=$original;$bestMetrics=$currentMetrics;Set-FocsNicSnapshot -Snapshot $original
    }

    & $writeProgress '';& $writeProgress 'Stage 3/4: testing supported NIC options one at a time...'
    $accepted=[System.Collections.Generic.List[object]]::new()
    $candidates=@(Get-FocsNicLabCandidates -AdapterName $AdapterName -BaseSnapshot $baseSnapshot)
    $idx=0
    foreach($cand in $candidates){
        $idx++
        & $writeProgress "[$idx/$($candidates.Count)] Testing: $($cand.Label)"
        $trialSettings=@($accepted.ToArray()) + @($cand)
        Set-FocsNicSnapshot -Snapshot $baseSnapshot -ExtraSettings $trialSettings
        $m=Test-FocsNetworkSuite -AdapterName $AdapterName -CustomTarget $CustomTarget -Count $plan.Count -Repeats $plan.Repeats
        $strict=[bool]$cand.StrictLatency
        $better=Test-FocsCandidateIsBetter -Candidate $m -Current $bestMetrics -StrictLatency:$strict
        $results.Add([pscustomobject]@{Stage='Candidate';Label=$cand.Label;Accepted=$better;Score=$m.Score;GatewayLoss=$m.GatewayLoss;InternetLoss=$m.InternetLoss;InternetP95=$m.InternetP95;GamingP95=$m.InternetWorstP95;GamingState=$m.GamingState;InternetJitter=$m.InternetJitter;StrictLatency=$strict})
        if($better){$accepted.Add($cand);$bestMetrics=$m;& $writeProgress ("KEEP - score {0:N1}, loss {1:N2}%, gaming P95 {2:N1} ms ({3})" -f $m.Score,$m.InternetLoss,$m.InternetWorstP95,$m.GamingState)}
        elseif($strict -and $m.InternetWorstP95 -gt ($bestMetrics.InternetWorstP95+2.0)){& $writeProgress ("REJECT (latency regression on a buffer/flow-control change) - score {0:N1}, loss {1:N2}%, gaming P95 {2:N1} ms vs {3:N1} ms baseline" -f $m.Score,$m.InternetLoss,$m.InternetWorstP95,$bestMetrics.InternetWorstP95)}
        else{& $writeProgress ("REJECT - score {0:N1}, loss {1:N2}%, gaming P95 {2:N1} ms ({3})" -f $m.Score,$m.InternetLoss,$m.InternetWorstP95,$m.GamingState)}
    }

    & $writeProgress '';& $writeProgress 'Stage 4/4: validating the best measured combination...'
    Set-FocsNicSnapshot -Snapshot $baseSnapshot -ExtraSettings $accepted.ToArray()
    $final=Test-FocsNetworkSuite -AdapterName $AdapterName -CustomTarget $CustomTarget -Count ([Math]::Max([int]$plan.Count,[int]12)) -Repeats ([Math]::Max([int]$plan.Repeats,[int]2))
    $p95Slack=[Math]::Max(3.0,[double]$currentMetrics.InternetWorstP95*0.08)
    $finalRegression=[bool]([double]$final.GatewayLoss -gt ([double]$currentMetrics.GatewayLoss+0.01) -or [double]$final.InternetLoss -gt ([double]$currentMetrics.InternetLoss+0.50) -or [double]$final.InternetWorstP95 -gt ([double]$currentMetrics.InternetWorstP95+$p95Slack) -or [double]$final.LocalErrors -gt [double]$currentMetrics.LocalErrors -or [double]$final.LocalDiscards -gt ([double]$currentMetrics.LocalDiscards+1))
    $rolledBack=$false
    if($finalRegression){
        & $writeProgress 'FINAL SAFETY GATE: regression detected. Restoring the original NIC state instead of saving the tuned combination.'
        Set-FocsNicSnapshot -Snapshot $original
        $final=Test-FocsNetworkSuite -AdapterName $AdapterName -CustomTarget $CustomTarget -Count ([Math]::Max([int]$plan.Count,[int]12)) -Repeats ([Math]::Max([int]$plan.Repeats,[int]2))
        $finalState=Get-FocsNicSnapshot -AdapterName $AdapterName;$rolledBack=$true;$accepted.Clear()
    }else{$finalState=Get-FocsNicSnapshot -AdapterName $AdapterName}
    $profile=[pscustomobject]@{Version=2;Created=(Get-Date).ToString('o');Adapter=$AdapterName;Mode=$Mode;OriginalScore=$currentMetrics.Score;FinalScore=$final.Score;OriginalInternetLoss=$currentMetrics.InternetLoss;FinalInternetLoss=$final.InternetLoss;OriginalP95=$currentMetrics.InternetP95;FinalP95=$final.InternetP95;OriginalGamingP95=$currentMetrics.InternetWorstP95;FinalGamingP95=$final.InternetWorstP95;FinalGamingState=$final.GamingState;RolledBack=$rolledBack;AcceptedChanges=$accepted.ToArray();State=$finalState}
    $profile|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $bestPath -Encoding UTF8
    $profile|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $runDir 'best_profile.json') -Encoding UTF8
    $results|Export-Csv -LiteralPath (Join-Path $runDir 'results.csv') -NoTypeInformation -Encoding UTF8
    & $writeProgress (Format-FocsNetworkSuite $final 'FINAL VALIDATION')
    & $writeProgress '';& $writeProgress ("Saved best measured profile: $bestPath")
    & $writeProgress ("Accepted changes: " + $(if($accepted.Count){(@($accepted|ForEach-Object{$_.Label}) -join '; ')}else{'none - baseline/defaults measured best'}))
    Write-KLog "Network Lab completed. Adapter=$AdapterName Mode=$Mode Best=$bestPath Score=$($final.Score)"
    $completed=$true
    return $profile
    } finally {
        if (-not $completed) {
            & $writeProgress 'Network Lab was interrupted or failed. Restoring the original NIC state...'
            try { Set-FocsNicSnapshot -Snapshot $original; & $writeProgress "Original NIC state restored. Recovery backup: $backup" }
            catch { Write-KLog "Emergency NIC rollback failed: $($_.Exception.Message)" }
        }
    }
}

function Apply-FocsSavedNetworkProfile {
    param([string]$AdapterName)
    if([string]::IsNullOrWhiteSpace($AdapterName)){throw 'Choose a network adapter first.'}
    $labRoot=Join-Path $script:DataRoot 'NetworkLab';$safeName=($AdapterName -replace '[^A-Za-z0-9_.-]','_');$bestPath=Join-Path $labRoot ("best_{0}.json" -f $safeName)
    if(-not(Test-Path -LiteralPath $bestPath)){throw 'No saved measured network profile exists for this adapter yet.'}
    $p=Get-Content -LiteralPath $bestPath -Raw|ConvertFrom-Json;if(-not $p.State){throw 'Saved network profile is invalid.'}
    Set-FocsNicSnapshot -Snapshot $p.State;Write-KLog "Applied saved measured network profile: $bestPath"
    $fp95=if($p.PSObject.Properties['FinalGamingP95']){[double]$p.FinalGamingP95}else{[double]$p.FinalP95};$state=if($p.PSObject.Properties['FinalGamingState']){[string]$p.FinalGamingState}else{Get-FocsGamingLatencyState -P95 $fp95 -LossPct ([double]$p.FinalInternetLoss)}
    return ("Applied saved measured profile for {0}.`r`nFinal measured loss: {1:N2}%`r`nGaming P95: {2:N1} ms ({3})" -f $AdapterName,[double]$p.FinalInternetLoss,$fp95,$state)
}

function New-NpiCustomPreset {
    param(
        [ValidateSet('Fortnite','CS2','Custom')][string]$Game,
        [string]$CustomExe,
        [bool]$PowerMax=$true,
        [bool]$HighestRefresh=$true,
        [bool]$TextureHighPerf=$false,
        [bool]$VSyncOff=$false,
        [bool]$PreRendered1=$false
    )
    $profileName = 'FOCS Custom Game'
    $executables = @()
    if ($Game -eq 'Fortnite') { $profileName='Fortnite'; $executables=@('FortniteClient-Win64-Shipping.exe','FortniteClient-Win64-Shipping_EAC_EOS.exe','FortniteClient-Win64-Shipping_BE.exe') }
    elseif ($Game -eq 'CS2') { $profileName='Counter-Strike 2'; $executables=@('cs2.exe') }
    else {
        $exe = [IO.Path]::GetFileName($CustomExe.Trim())
        if (-not $exe) { throw 'Enter a custom game executable, for example game.exe.' }
        $profileName = [IO.Path]::GetFileNameWithoutExtension($exe)
        $executables=@($exe)
    }
    $settings = @()
    if ($PowerMax) { $settings += @{Name='Power management mode';Id='274197361';Value='1'} }
    if ($HighestRefresh) { $settings += @{Name='Preferred refresh rate';Id='6600001';Value='1'} }
    if ($TextureHighPerf) { $settings += @{Name='Texture filtering - Quality';Id='13510289';Value='20'} }
    if ($VSyncOff) { $settings += @{Name='Vertical Sync';Id='11041231';Value='138504007'} }
    if ($PreRendered1) { $settings += @{Name='Maximum pre-rendered frames';Id='8102046';Value='1'} }
    if ($settings.Count -eq 0) { throw 'Select at least one NVIDIA setting.' }
    $exeXml = ($executables | ForEach-Object { '      <string>' + [Security.SecurityElement]::Escape($_) + '</string>' }) -join "`r`n"
    $settingsXml = ($settings | ForEach-Object {
@"
      <ProfileSetting>
        <SettingNameInfo>$($_.Name)</SettingNameInfo>
        <SettingID>$($_.Id)</SettingID>
        <SettingValue>$($_.Value)</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
"@
    }) -join ''
    $xml = @"
<?xml version="1.0" encoding="utf-16"?>
<ArrayOfProfile>
  <Profile>
    <ProfileName>$profileName</ProfileName>
    <Executeables>
$exeXml
    </Executeables>
    <Settings>
$settingsXml    </Settings>
  </Profile>
</ArrayOfProfile>
"@
    $dir = Join-Path $script:DataRoot 'GeneratedProfiles'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $path = Join-Path $dir ("FOCS_NPI_{0}_{1}.nip" -f ($profileName -replace '[^A-Za-z0-9_.-]','_'),(Get-Date -Format 'yyyyMMdd_HHmmss'))
    [IO.File]::WriteAllText($path,$xml,[Text.Encoding]::Unicode)
    return $path
}

function Apply-NpiCustomPreset {
    param(
        [ValidateSet('Fortnite','CS2','Custom')][string]$Game,
        [string]$CustomExe,
        [bool]$PowerMax=$true,
        [bool]$HighestRefresh=$true,
        [bool]$TextureHighPerf=$false,
        [bool]$VSyncOff=$false,
        [bool]$PreRendered1=$false
    )
    if (-not (Find-NvidiaProfileInspector)) { [void](Update-NpiTool -Force) }
    $npi = Find-NvidiaProfileInspector
    if (-not $npi) { throw 'NVIDIA Profile Inspector is not available.' }
    $backup = Export-NpiCustomizedBackup
    $profile = New-NpiCustomPreset -Game $Game -CustomExe $CustomExe -PowerMax $PowerMax -HighestRefresh $HighestRefresh -TextureHighPerf $TextureHighPerf -VSyncOff $VSyncOff -PreRendered1 $PreRendered1
    $p = Start-Process -FilePath $npi -ArgumentList @('-silentImport',('"' + $profile + '"')) -WorkingDirectory (Split-Path -Parent $npi) -PassThru -Wait
    if ($p.ExitCode -ne 0) { throw "NVIDIA Profile Inspector import returned $($p.ExitCode)." }
    Write-KLog "Custom NPI preset applied. Game=$Game Profile=$profile Backup=$backup"
    return "NVIDIA profile applied.`r`nGenerated profile: $profile`r`nCustomized-driver backup: $backup"
}

function Set-KProfileSelection {
    param([ValidateSet('Recommended','Minimal','Competitive','Custom')][string]$Name)
    $script:SelectedProfile = $Name
    $c = $script:Ui.Controls
    if ($c) {
        if ($Name -eq 'Recommended') {
            $c.GameMode.Checked=$true; $c.Mouse.Checked=$true; $c.Delivery.Checked=$true; $c.Network.Checked=$false; $c.Hags.Checked=$false
        } elseif ($Name -eq 'Minimal') {
            $c.GameMode.Checked=$true; $c.Mouse.Checked=$true; $c.Delivery.Checked=$false; $c.Network.Checked=$false; $c.Hags.Checked=$false
        } elseif ($Name -eq 'Competitive') {
            $c.GameMode.Checked=$true; $c.Mouse.Checked=$true; $c.Delivery.Checked=$true; $c.Network.Checked=$false; $c.Hags.Checked=$false
        }
    }
    if ($script:Ui.ProfileButtons) {
        foreach($key in @($script:Ui.ProfileButtons.Keys)) {
            $btn=$script:Ui.ProfileButtons[$key]
            $btn.BackColor=[System.Drawing.Color]::FromArgb(22,11,37); $btn.FlatAppearance.BorderColor=[System.Drawing.Color]::Black; $btn.FlatAppearance.BorderSize=1
        }
        $sel=$script:Ui.ProfileButtons[$Name]
        if($sel){$sel.BackColor=[System.Drawing.Color]::FromArgb(58,29,100);$sel.FlatAppearance.BorderColor=[System.Drawing.Color]::FromArgb(129,73,214);$sel.FlatAppearance.BorderSize=3}
    }
    if($script:Ui.ProfileStatus){$script:Ui.ProfileStatus.Text="Selected profile: $Name"}
    if($script:Ui.ProfileExplain){
        $script:Ui.ProfileExplain.Text = switch($Name){
            'Minimal' { "Minimal: Game Mode + Game DVR baseline and pointer acceleration off. No debloat preset is added automatically." }
            'Recommended' { "Recommended: low-risk gaming baseline plus consumer-content, suggestions, ads, Edge background mode and Widgets reductions. App removal stays manual." }
            'Competitive' { "Competitive: Recommended plus transparency and Bing web suggestions off. NVIDIA and NIC latency changes stay on their own pages so you can A/B test them." }
            default { "Custom: FOCS leaves your current checkboxes alone. Choose exactly what you want on each page." }
        }
    }
    Write-KLog "Profile selected: $Name"
}

function Set-KRoundedRegion {
    param([System.Windows.Forms.Control]$Control,[int]$Radius=14)
    if (-not $Control -or $Control.Width -lt 2 -or $Control.Height -lt 2) { return }
    $diameter = [Math]::Min(($Radius * 2), [Math]::Min($Control.Width,$Control.Height))
    if ($diameter -lt 2) { return }
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    try {
        $w = $Control.Width - 1
        $h = $Control.Height - 1
        $d = $diameter
        $path.AddArc(0,0,$d,$d,180,90)
        $path.AddArc($w-$d,0,$d,$d,270,90)
        $path.AddArc($w-$d,$h-$d,$d,$d,0,90)
        $path.AddArc(0,$h-$d,$d,$d,90,90)
        $path.CloseFigure()
        $newRegion = New-Object System.Drawing.Region($path)
        $oldRegion = $Control.Region
        $Control.Region = $newRegion
        if ($oldRegion) { $oldRegion.Dispose() }
    } finally {
        $path.Dispose()
    }
}

function Add-KDarkBorder {
    param([System.Windows.Forms.Control]$Control,[int]$Radius=14,[int]$Width=2)
    if (-not $Control) { return }
    $Control.Add_Paint({
        param($sender,$e)
        try {
            $r = [Math]::Max(1,$Radius)
            $d = $r * 2
            $w = $sender.ClientSize.Width - 1
            $h = $sender.ClientSize.Height - 1
            if ($w -lt 2 -or $h -lt 2) { return }
            $path = New-Object System.Drawing.Drawing2D.GraphicsPath
            try {
                $dd = [Math]::Min($d,[Math]::Min($w,$h))
                $path.AddArc(0,0,$dd,$dd,180,90)
                $path.AddArc($w-$dd,0,$dd,$dd,270,90)
                $path.AddArc($w-$dd,$h-$dd,$dd,$dd,0,90)
                $path.AddArc(0,$h-$dd,$dd,$dd,90,90)
                $path.CloseFigure()
                $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(0,0,0),$Width)
                try {
                    $e.Graphics.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
                    $e.Graphics.DrawPath($pen,$path)
                } finally { $pen.Dispose() }
            } finally { $path.Dispose() }
        } catch {}
    }.GetNewClosure())
}

function New-KCard {
    param([System.Windows.Forms.Control]$Parent,[int]$X,[int]$Y,[int]$W,[int]$H)
    $p = New-Object System.Windows.Forms.Panel
    $p.Location = New-Object System.Drawing.Point($X,$Y)
    $p.Size = New-Object System.Drawing.Size($W,$H)
    $p.BackColor = [System.Drawing.Color]::FromArgb(22,11,37)
    $p.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    [void]$Parent.Controls.Add($p)
    Set-KRoundedRegion -Control $p -Radius 14
    Add-KDarkBorder -Control $p -Radius 14 -Width 2
    return $p
}

function New-KTitle {
    param([System.Windows.Forms.Control]$Parent,[string]$Text,[int]$X,[int]$Y,[int]$W,[int]$H=32,[float]$Size=14)
    $l = New-KLabel $Parent $Text $X $Y $W $H
    $l.Font = New-Object System.Drawing.Font('Segoe UI Semibold',$Size)
    $l.ForeColor = [System.Drawing.Color]::FromArgb(244,238,255)
    return $l
}

function New-KNavButton {
    param([System.Windows.Forms.Control]$Parent,[string]$Text,[int]$Y)
    $b = New-KButton $Text 14 $Y 238 46
    $b.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $b.Padding = New-Object System.Windows.Forms.Padding(18,0,0,0)
    $b.FlatAppearance.BorderSize = 1
    $b.FlatAppearance.BorderColor = [System.Drawing.Color]::Black
    $b.BackColor = [System.Drawing.Color]::FromArgb(19,10,33)
    $b.ForeColor = [System.Drawing.Color]::FromArgb(211,195,235)
    [void]$Parent.Controls.Add($b)
    return $b
}

function Set-KNavSelected {
    param([System.Windows.Forms.Button[]]$Buttons,[System.Windows.Forms.Button]$Selected)
    foreach ($b in $Buttons) { $b.BackColor=[System.Drawing.Color]::FromArgb(19,10,33); $b.ForeColor=[System.Drawing.Color]::FromArgb(211,195,235) }
    $Selected.BackColor=[System.Drawing.Color]::FromArgb(61,30,105)
    $Selected.ForeColor=[System.Drawing.Color]::White
}

function Get-PrimaryNetworkSummary {
    try {
        $a = Get-NetAdapter -Physical -ErrorAction Stop | Where-Object Status -eq 'Up' | Sort-Object LinkSpeed -Descending | Select-Object -First 1
        if ($a) { return "$($a.Name) | $($a.InterfaceDescription)`r`nLink: $($a.LinkSpeed)" }
    } catch {}
    return 'No active physical adapter detected.'
}

function Get-PowerSchemeName {
    try {
        $s = (& powercfg.exe /getactivescheme 2>$null | Out-String).Trim()
        if ($s) { return $s }
    } catch {}
    return 'Unknown power plan'
}


function Get-FocsMedian {
    param([double[]]$Values)
    $v=@($Values|Sort-Object)
    if($v.Count -eq 0){return 0.0}
    $mid=[int][math]::Floor($v.Count/2)
    if(($v.Count % 2) -eq 1){return [double]$v[$mid]}
    return ([double]$v[$mid-1]+[double]$v[$mid])/2.0
}

function Get-FocsPercentile {
    param([double[]]$Values,[double]$Percentile=0.95)
    $v=@($Values|Sort-Object)
    if($v.Count -eq 0){return 0.0}
    $p=[math]::Max(0.0,[math]::Min(1.0,$Percentile))
    $idx=[int][math]::Ceiling($p*$v.Count)-1
    if($idx -lt 0){$idx=0};if($idx -ge $v.Count){$idx=$v.Count-1}
    return [double]$v[$idx]
}

function Get-FocsPowerSchemes {
    $items=[System.Collections.Generic.List[object]]::new()
    try{
        foreach($line in @(& powercfg.exe /list 2>$null)){
            $m=[regex]::Match([string]$line,'(?i)([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\s+\(([^)]*)\)\s*(\*)?')
            if($m.Success){
                $items.Add([pscustomobject]@{Guid=$m.Groups[1].Value;Name=$m.Groups[2].Value.Trim();Active=($m.Groups[3].Value -eq '*')})
            }
        }
    }catch{}
    return $items.ToArray()
}

function Copy-FocsPowerScheme {
    param([string]$SourceGuid,[string]$Name)
    $text=(& powercfg.exe /duplicatescheme $SourceGuid 2>&1 | Out-String)
    if($LASTEXITCODE -ne 0){throw "Could not duplicate power plan $SourceGuid. $text"}
    $m=[regex]::Match($text,'(?i)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
    if(-not $m.Success){throw 'Windows did not return a GUID for the duplicated power plan.'}
    $guid=$m.Value
    & powercfg.exe /changename $guid $Name 1>$null 2>$null
    return $guid
}

function Set-FocsPowerAcValueSafe {
    param([string]$SchemeGuid,[string]$SubGroup,[string]$Setting,[int]$Value)
    try{
        & powercfg.exe /setacvalueindex $SchemeGuid $SubGroup $Setting $Value 1>$null 2>$null
        return ($LASTEXITCODE -eq 0)
    }catch{return $false}
}

function New-FocsMeasuredPowerCandidate {
    param([string]$BaseGuid,[ValidateSet('Responsive','MaxLatency')][string]$Mode,[bool]$AllowAggressive)
    $cpu=(Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue|Select-Object -First 1)
    $short=if($cpu.Name){(($cpu.Name -replace '[^A-Za-z0-9 ]','') -replace '\s+',' ').Trim()}else{'CPU'}
    if($short.Length -gt 32){$short=$short.Substring(0,32)}
    $name=if($Mode -eq 'MaxLatency'){"FOCS Max Latency - $short"}else{"FOCS Responsive - $short"}
    $guid=Copy-FocsPowerScheme -SourceGuid $BaseGuid -Name $name
    $changes=[System.Collections.Generic.List[string]]::new()
    if(Set-FocsPowerAcValueSafe $guid 'SUB_PROCESSOR' 'PROCTHROTTLEMAX' 100){$changes.Add('CPU max state=100%')}
    if(Set-FocsPowerAcValueSafe $guid 'SUB_PROCESSOR' 'PERFEPP' 0){$changes.Add('EPP=0 (favor performance)')}
    if(Set-FocsPowerAcValueSafe $guid 'SUB_PROCESSOR' 'LATENCYHINTEPP' 0){$changes.Add('Latency hint EPP=0')}
    if(Set-FocsPowerAcValueSafe $guid 'SUB_PCIEXPRESS' 'ASPM' 0){$changes.Add('PCIe Link State Power Management=Off')}
    if($Mode -eq 'Responsive'){
        if(Set-FocsPowerAcValueSafe $guid 'SUB_PROCESSOR' 'PROCTHROTTLEMIN' 5){$changes.Add('CPU min state=5%')}
    } elseif($AllowAggressive) {
        if(Set-FocsPowerAcValueSafe $guid 'SUB_PROCESSOR' 'PROCTHROTTLEMIN' 100){$changes.Add('CPU min state=100%')}
        if(Set-FocsPowerAcValueSafe $guid 'SUB_PROCESSOR' 'CPMINCORES' 100){$changes.Add('Core parking min cores=100%')}
    }
    [pscustomobject]@{Guid=$guid;Name=$name;CreatedByFocs=$true;Changes=$changes.ToArray();Mode=$Mode}
}

function Invoke-FocsPowerProbe {
    param([string]$SchemeGuid,[int]$Rounds=3)
    & powercfg.exe /setactive $SchemeGuid 1>$null 2>$null
    if($LASTEXITCODE -ne 0){throw "Could not activate power plan $SchemeGuid"}
    Start-Sleep -Milliseconds 1400
    $hashRounds=[System.Collections.Generic.List[double]]::new()
    $wakeRounds=[System.Collections.Generic.List[double]]::new()
    $data=New-Object byte[] (4MB)
    for($r=1;$r -le $Rounds;$r++){
        [GC]::Collect();[GC]::WaitForPendingFinalizers()
        $sha=[System.Security.Cryptography.SHA256]::Create()
        try{[void]$sha.ComputeHash($data);$sw=[System.Diagnostics.Stopwatch]::StartNew();for($i=0;$i -lt 28;$i++){[void]$sha.ComputeHash($data)};$sw.Stop();$hashRounds.Add([double]$sw.Elapsed.TotalMilliseconds)}finally{$sha.Dispose()}
        $wake=[System.Collections.Generic.List[double]]::new()
        for($i=0;$i -lt 36;$i++){
            $s=[System.Diagnostics.Stopwatch]::StartNew();[System.Threading.Thread]::Sleep(2);$s.Stop();$over=[math]::Max(0.0,$s.Elapsed.TotalMilliseconds-2.0);$wake.Add([double]$over)
        }
        $wakeRounds.Add((Get-FocsPercentile -Values $wake.ToArray() -Percentile 0.95))
    }
    [pscustomobject]@{HashMs=(Get-FocsMedian $hashRounds.ToArray());WakeP95Ms=(Get-FocsMedian $wakeRounds.ToArray());HashRuns=$hashRounds.ToArray();WakeRuns=$wakeRounds.ToArray()}
}

function Invoke-FocsPowerPlanLab {
    param([System.Windows.Forms.Label]$PowerLabel=$null)
    $original=Get-ActivePowerSchemeGuid
    if(-not $original){throw 'FOCS could not determine the active Windows power plan.'}
    $backup=New-KBackup
    $cpu=Get-CimInstance Win32_Processor -ErrorAction Stop|Select-Object -First 1
    $battery=@(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue).Count -gt 0
    $cpuName=[string]$cpu.Name
    $intelHybrid=($cpu.Manufacturer -match 'Intel') -and ($cpuName -match '12th Gen|13th Gen|14th Gen|Core\s+Ultra|Ultra\s+[3579]')
    $allowAggressive=(-not $battery) -and (-not $intelHybrid)
    $schemes=@(Get-FocsPowerSchemes)
    $balancedGuid='381b4222-f694-41f0-9685-ff5bb260df2e'
    $highGuid='8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
    $candidates=[System.Collections.Generic.List[object]]::new()
    $created=[System.Collections.Generic.List[string]]::new()
    $seen=@{}
    $addCandidate={param($g,$n,$createdBy,$changes,$mode)if($g -and -not $seen.ContainsKey($g.ToLowerInvariant())){$seen[$g.ToLowerInvariant()]=$true;$candidates.Add([pscustomobject]@{Guid=$g;Name=$n;CreatedByFocs=[bool]$createdBy;Changes=@($changes);Mode=$mode})}}
    try{
        $currentName=($schemes|Where-Object Guid -eq $original|Select-Object -First 1).Name;if(-not $currentName){$currentName='Current plan'}
        & $addCandidate $original $currentName $false @() 'Current'
        $bal=$schemes|Where-Object Guid -eq $balancedGuid|Select-Object -First 1;if($bal){& $addCandidate $balancedGuid $bal.Name $false @() 'Balanced'}
        $high=$schemes|Where-Object Guid -eq $highGuid|Select-Object -First 1
        if(-not $high){
            try{$newHigh=Copy-FocsPowerScheme -SourceGuid $highGuid -Name 'FOCS High Performance Test';$created.Add($newHigh);$high=[pscustomobject]@{Guid=$newHigh;Name='FOCS High Performance Test'}}catch{}
        }
        if($high){& $addCandidate ([string]$high.Guid) ([string]$high.Name) ($created -contains [string]$high.Guid) @() 'High'}
        $baseGuid=if($high){[string]$high.Guid}else{$original}
        $resp=New-FocsMeasuredPowerCandidate -BaseGuid $baseGuid -Mode Responsive -AllowAggressive $allowAggressive;$created.Add($resp.Guid);& $addCandidate $resp.Guid $resp.Name $true $resp.Changes $resp.Mode
        if($allowAggressive){$max=New-FocsMeasuredPowerCandidate -BaseGuid $baseGuid -Mode MaxLatency -AllowAggressive $true;$created.Add($max.Guid);& $addCandidate $max.Guid $max.Name $true $max.Changes $max.Mode}

        $results=[System.Collections.Generic.List[object]]::new()
        foreach($c in $candidates){
            $m=Invoke-FocsPowerProbe -SchemeGuid $c.Guid -Rounds 3
            $results.Add([pscustomobject]@{Guid=$c.Guid;Name=$c.Name;Mode=$c.Mode;CreatedByFocs=$c.CreatedByFocs;Changes=$c.Changes;HashMs=[double]$m.HashMs;WakeP95Ms=[double]$m.WakeP95Ms})
        }
        $minHash=[double](($results|Measure-Object HashMs -Minimum).Minimum)
        $minWake=[double](($results|Measure-Object WakeP95Ms -Minimum).Minimum);if($minWake -lt 0.05){$minWake=0.05}
        foreach($r in $results){$r|Add-Member -NotePropertyName Score -NotePropertyValue ([math]::Round((70.0*($r.HashMs/$minHash))+(30.0*([math]::Max(0.05,$r.WakeP95Ms)/$minWake)),3))}
        $best=$results|Sort-Object Score,WakeP95Ms,HashMs|Select-Object -First 1
        & powercfg.exe /setactive $best.Guid 1>$null 2>$null
        Start-Sleep -Milliseconds 600
        foreach($g in $created.ToArray()){
            if($g -and $g -ne $best.Guid){try{& powercfg.exe /delete $g 1>$null 2>$null}catch{}}
        }
        $root=Join-Path $script:DataRoot 'PowerLab';New-Item -ItemType Directory -Path $root -Force|Out-Null
        $record=[pscustomobject]@{Version='9.1.2';Created=(Get-Date).ToString('o');CPU=$cpuName;BatteryPresent=$battery;IntelHybridDetected=$intelHybrid;OriginalGuid=$original;Winner=$best;Results=$results.ToArray();Backup=$backup}
        $record|ConvertTo-Json -Depth 10|Set-Content -LiteralPath (Join-Path $root 'best_power_plan.json') -Encoding UTF8
        if($PowerLabel){$PowerLabel.Text=Get-PowerSchemeName}
        $lines=[System.Collections.Generic.List[string]]::new();$lines.Add("Best measured plan: $($best.Name)");$lines.Add(('Score: {0:N2} | CPU burst: {1:N1} ms | wake P95: {2:N3} ms' -f $best.Score,$best.HashMs,$best.WakeP95Ms));$lines.Add('');$lines.Add('Tested:')
        foreach($r in ($results|Sort-Object Score)){$lines.Add(('  {0}: score {1:N2}, burst {2:N1} ms, wake P95 {3:N3} ms' -f $r.Name,$r.Score,$r.HashMs,$r.WakeP95Ms))}
        $lines.Add('');$lines.Add("Backup: $backup");if($battery){$lines.Add('Laptop/battery detected: FOCS skipped the locked-100% CPU candidate.')}elseif($intelHybrid){$lines.Add('Hybrid Intel CPU detected: FOCS skipped the locked-100%/all-cores-unparked candidate.')}
        Write-KLog "Power Plan Lab winner=$($best.Name) score=$($best.Score) CPU=$cpuName"
        return ($lines -join "`r`n")
    }catch{
        try{& powercfg.exe /setactive $original 1>$null 2>$null}catch{}
        foreach($g in $created.ToArray()){try{if($g -and $g -ne $original){& powercfg.exe /delete $g 1>$null 2>$null}}catch{}}
        throw
    }
}


function New-KButton {
    param([string]$Text,[int]$X,[int]$Y,[int]$Width,[int]$Height=40)
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Location = New-Object System.Drawing.Point($X,$Y)
    $b.Size = New-Object System.Drawing.Size($Width,$Height)
    $b.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $b.UseVisualStyleBackColor = $false
    $b.BackColor = [System.Drawing.Color]::FromArgb(30,15,48)
    $b.ForeColor = [System.Drawing.Color]::White
    $b.FlatAppearance.BorderSize = 1
    $b.FlatAppearance.BorderColor = [System.Drawing.Color]::Black
    $b.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(55,27,86)
    $b.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(72,34,112)
    Set-KRoundedRegion -Control $b -Radius 11
    Add-KDarkBorder -Control $b -Radius 11 -Width 1
    return $b
}

function Set-FocsTip {
    param([System.Windows.Forms.Control]$Control,[string]$Text)
    if ($script:FocsToolTip -and $Control -and -not [string]::IsNullOrWhiteSpace($Text)) {
        $script:FocsToolTip.SetToolTip($Control,$Text)
    }
}

function New-KTab {
    param([System.Windows.Forms.TabControl]$Tabs,[string]$Name)
    $p = New-Object System.Windows.Forms.TabPage
    $p.Text = $Name
    $p.BackColor = [System.Drawing.Color]::FromArgb(24,24,30)
    $p.ForeColor = [System.Drawing.Color]::White
    [void]$Tabs.TabPages.Add($p)
    return $p
}

function New-KCheck {
    param([System.Windows.Forms.Control]$Parent,[string]$Text,[int]$X,[int]$Y,[bool]$Checked)
    $c = New-Object System.Windows.Forms.CheckBox
    $c.Text = $Text
    $c.Location = New-Object System.Drawing.Point($X,$Y)
    $c.Size = New-Object System.Drawing.Size(520,32)
    $c.Checked = $Checked
    $c.ForeColor = [System.Drawing.Color]::White
    [void]$Parent.Controls.Add($c)
    return $c
}

function New-KLabel {
    param([System.Windows.Forms.Control]$Parent,[string]$Text,[int]$X,[int]$Y,[int]$W,[int]$H)
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Text
    $l.Location = New-Object System.Drawing.Point($X,$Y)
    $l.Size = New-Object System.Drawing.Size($W,$H)
    $l.ForeColor = [System.Drawing.Color]::Gainsboro
    [void]$Parent.Controls.Add($l)
    return $l
}


# ---------------- FOCS v9.5.0 research features ----------------
function Get-FocsXperf {
    $paths=@(
        (Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\Windows Performance Toolkit\xperf.exe'),
        (Join-Path $env:ProgramFiles 'Windows Kits\10\Windows Performance Toolkit\xperf.exe')
    )
    foreach($p in $paths){if($p -and (Test-Path -LiteralPath $p)){return $p}}
    $c=Get-Command xperf.exe -ErrorAction SilentlyContinue;if($c){return $c.Source}
    return $null
}

function Get-FocsWpa {
    $x=Get-FocsXperf
    if($x){$p=Join-Path (Split-Path -Parent $x) 'wpa.exe';if(Test-Path -LiteralPath $p){return $p}}
    return $null
}

function Install-FocsWpt {
    $winget=Get-KWinget
    if(-not $winget){throw 'winget is required for the optional Windows Performance Toolkit installer.'}
    $argLine='install --id Microsoft.WindowsADK --exact --source winget --accept-source-agreements --accept-package-agreements --disable-interactivity --override "/quiet /norestart /features OptionId.WindowsPerformanceToolkit"'
    $p=Start-Process -FilePath $winget -ArgumentList $argLine -PassThru -Wait
    if($p.ExitCode -ne 0 -and -not(Get-FocsXperf)){throw "Windows ADK/WPT installer returned exit code $($p.ExitCode)."}
    $x=Get-FocsXperf
    if(-not $x){throw 'Installation finished but xperf.exe was not found. Install the Windows Performance Toolkit feature from Windows ADK.'}
    Write-KLog "Windows Performance Toolkit ready: $x"
    return $x
}

function Get-FocsPerfSample {
    try{
        $p=Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction Stop | Select-Object -First 1
        $m=Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory -ErrorAction SilentlyContinue | Select-Object -First 1
        [pscustomobject]@{
            Time=(Get-Date).ToString('o')
            DpcPct=[double]$p.PercentDPCTime
            InterruptPct=[double]$p.PercentInterruptTime
            DpcPerSec=[double]$p.DPCsQueuedPersec
            InterruptsPerSec=[double]$p.InterruptsPersec
            PageReadsPerSec=if($m){[double]$m.PageReadsPersec}else{0}
            PagesInputPerSec=if($m){[double]$m.PagesInputPersec}else{0}
        }
    }catch{return $null}
}

function Invoke-FocsLatencyDoctor {
    param([int]$Seconds=60,[System.Windows.Forms.TextBox]$OutputBox)
    if($Seconds -lt 10){$Seconds=10};if($Seconds -gt 300){$Seconds=300}
    $wpr=Get-Command wpr.exe -ErrorAction SilentlyContinue
    if(-not $wpr){throw 'wpr.exe is not available on this Windows installation.'}
    $status=(& $wpr.Source -status 2>&1 | Out-String)
    if($status -match 'recording is in progress|WPR recording'){throw 'Another WPR trace is already running. FOCS will not stop a trace it did not start.'}
    $run=Join-Path $script:LatencyRoot (Get-Date -Format 'yyyyMMdd_HHmmss');New-Item -ItemType Directory -Path $run -Force|Out-Null
    $etl=Join-Path $run 'FOCS_LatencyDoctor.etl';$samples=[System.Collections.Generic.List[object]]::new()
    if($OutputBox){$OutputBox.Clear();$OutputBox.AppendText("Starting Windows Performance Recorder...`r`nUse the PC normally or reproduce the stutter for $Seconds seconds.`r`n")}
    $started=$false
    try{
        $sp=Start-Process -FilePath $wpr.Source -ArgumentList @('-start','GeneralProfile.Light') -PassThru -Wait -WindowStyle Hidden
        if($sp.ExitCode -ne 0){throw "WPR start returned exit code $($sp.ExitCode)."};$started=$true
        $end=(Get-Date).AddSeconds($Seconds)
        while((Get-Date) -lt $end){
            $s=Get-FocsPerfSample;if($s){$samples.Add($s)}
            if($OutputBox){$left=[Math]::Max(0,[int][Math]::Ceiling(($end-(Get-Date)).TotalSeconds));$OutputBox.Text="Latency Doctor recording... $left s remaining`r`nDPC/interrupt counters are sampled once per second.`r`nDo the action that causes the problem now.";[System.Windows.Forms.Application]::DoEvents()}
            Start-Sleep -Seconds 1
        }
        $stopArgs='-stop "'+$etl+'" "FOCS Latency Doctor" -compress'
        $st=Start-Process -FilePath $wpr.Source -ArgumentList $stopArgs -PassThru -Wait -WindowStyle Hidden
        $started=$false
        if($st.ExitCode -ne 0 -or -not(Test-Path -LiteralPath $etl)){throw "WPR stop/save failed with exit code $($st.ExitCode)."}
    }finally{
        if($started){try{Start-Process -FilePath $wpr.Source -ArgumentList '-cancel' -Wait -WindowStyle Hidden|Out-Null}catch{}}
    }
    $sampleCsv=Join-Path $run 'perf_counters.csv';if($samples.Count){$samples.ToArray()|Export-Csv -LiteralPath $sampleCsv -NoTypeInformation -Encoding UTF8}
    $traceSummary=Join-Path $run 'tracerpt_summary.txt';try{& tracerpt.exe $etl -summary $traceSummary -lr -y 1>$null 2>$null}catch{}
    $dpcReport=$null;$hardFaultReport=$null;$cswitchReport=$null;$driverDelayReport=$null;$xperf=Get-FocsXperf
    if($xperf){
        $dpcReport=Join-Path $run 'dpcisr_report.txt'
        $hardFaultReport=Join-Path $run 'hardfault_report.txt'
        $cswitchReport=Join-Path $run 'cswitch_process_report.txt'
        $driverDelayReport=Join-Path $run 'driver_delay_report.txt'
        try{$xargs='-quiet -i "'+$etl+'" -o "'+$dpcReport+'" -a dpcisr';Start-Process -FilePath $xperf -ArgumentList $xargs -PassThru -Wait -WindowStyle Hidden|Out-Null}catch{$dpcReport=$null}
        try{$xargs='-quiet -i "'+$etl+'" -o "'+$hardFaultReport+'" -a hardfault';Start-Process -FilePath $xperf -ArgumentList $xargs -PassThru -Wait -WindowStyle Hidden|Out-Null}catch{$hardFaultReport=$null}
        try{$xargs='-quiet -i "'+$etl+'" -o "'+$cswitchReport+'" -a cswitch -process -exc_dpcisr';Start-Process -FilePath $xperf -ArgumentList $xargs -PassThru -Wait -WindowStyle Hidden|Out-Null}catch{$cswitchReport=$null}
        try{$xargs='-quiet -i "'+$etl+'" -o "'+$driverDelayReport+'" -a drvdelay -min 100';Start-Process -FilePath $xperf -ArgumentList $xargs -PassThru -Wait -WindowStyle Hidden|Out-Null}catch{$driverDelayReport=$null}
    }
    $script:LatestLatencyTrace=$etl;$script:LatestLatencyReport=$dpcReport
    $lines=[System.Collections.Generic.List[string]]::new();$lines.Add('LATENCY DOCTOR COMPLETE');$lines.Add("Trace: $etl")
    if($samples.Count){
        $d=@($samples|ForEach-Object{$_.DpcPct});$i=@($samples|ForEach-Object{$_.InterruptPct});$dr=@($samples|ForEach-Object{$_.DpcPerSec});$ir=@($samples|ForEach-Object{$_.InterruptsPerSec});$pg=@($samples|ForEach-Object{$_.PagesInputPerSec})
        $lines.Add(('DPC time avg/max: {0:N2}% / {1:N2}%' -f (($d|Measure-Object -Average).Average),(($d|Measure-Object -Maximum).Maximum)))
        $lines.Add(('Interrupt time avg/max: {0:N2}% / {1:N2}%' -f (($i|Measure-Object -Average).Average),(($i|Measure-Object -Maximum).Maximum)))
        $lines.Add(('DPCs/sec avg/max: {0:N0} / {1:N0}' -f (($dr|Measure-Object -Average).Average),(($dr|Measure-Object -Maximum).Maximum)))
        $lines.Add(('Interrupts/sec avg/max: {0:N0} / {1:N0}' -f (($ir|Measure-Object -Average).Average),(($ir|Measure-Object -Maximum).Maximum)))
        $lines.Add(('Pages input/sec avg/max: {0:N1} / {1:N1}' -f (($pg|Measure-Object -Average).Average),(($pg|Measure-Object -Maximum).Maximum)))
    }
    if($dpcReport -and (Test-Path -LiteralPath $dpcReport)){
        $lines.Add("xperf DPC/ISR report: $dpcReport")
        if($hardFaultReport -and (Test-Path -LiteralPath $hardFaultReport)){$lines.Add("xperf hard-fault report: $hardFaultReport")}
        if($cswitchReport -and (Test-Path -LiteralPath $cswitchReport)){$lines.Add("xperf scheduling/context-switch report: $cswitchReport")}
        if($driverDelayReport -and (Test-Path -LiteralPath $driverDelayReport)){$lines.Add("xperf driver-delay report (>100 us): $driverDelayReport")}
        $lines.Add('Use the reports together: DPC/ISR identifies interrupt-side drivers, hard faults show process/file paging, and context-switch data shows CPU scheduling pressure.')
    } else {$lines.Add('xperf not installed: the ETL was still saved. Install optional Windows Performance Toolkit for per-driver DPC/ISR, hard-fault and scheduling text reports.')}
    Write-KLog "Latency Doctor completed: $etl"
    return ($lines -join "`r`n")
}

function Update-LibreHardwareMonitorTool {
    param([switch]$Force)
    $release=Get-GitHubLatestStableRelease -Repository 'LibreHardwareMonitor/LibreHardwareMonitor';$tag=[string]$release.tag_name
    if(-not $tag){throw 'GitHub did not return a LibreHardwareMonitor release tag.'}
    $asset=@($release.assets)|Where-Object{$_.name -ieq 'LibreHardwareMonitor.zip'}|Select-Object -First 1
    if(-not $asset){$asset=@($release.assets)|Where-Object{$_.name -match '(?i)^LibreHardwareMonitor(?!.*NET).*\.zip$'}|Select-Object -First 1}
    if(-not $asset){throw 'Latest LibreHardwareMonitor release has no standard ZIP asset.'}
    $dll=Get-ChildItem -LiteralPath $script:LhmRoot -Filter 'LibreHardwareMonitorLib.dll' -Recurse -File -ErrorAction SilentlyContinue|Select-Object -First 1
    $current=Get-ManagedVersion $script:LhmRoot
    if(-not $Force -and $current -match [regex]::Escape($tag) -and $dll){return "LibreHardwareMonitor $tag is current"}
    # This DLL is loaded straight into the FOCS process, so it is the download that most needs
    # checking. Verify the publisher digest first, extract to staging, and only then swap it in.
    $work=Join-Path $env:TEMP ('FOCS_LHM_'+[guid]::NewGuid().ToString('N'))
    $zip="$work.zip"
    $stage=Join-Path $work 'extracted'
    try{
        New-Item -ItemType Directory -Path $stage -Force|Out-Null
        [void](Get-KVerifiedDownload -Uri ([string]$asset.browser_download_url) -Destination $zip -Asset $asset)
        Expand-Archive -LiteralPath $zip -DestinationPath $stage -Force
        $staged=Get-ChildItem -LiteralPath $stage -Filter 'LibreHardwareMonitorLib.dll' -Recurse -File -ErrorAction SilentlyContinue|Select-Object -First 1
        if(-not $staged){throw 'LibreHardwareMonitorLib.dll was not found after extraction, so the existing copy was left untouched.'}
        $sig=Test-FocsSignature -Path $staged.FullName
        Write-KLog "LibreHardwareMonitorLib.dll signature: $($sig.Reason)"
        if(-not $sig.Trusted -and $sig.Status -notin @('NotSigned','CheckFailed')){throw "LibreHardwareMonitorLib.dll failed Authenticode verification and was discarded. $($sig.Reason)"}
        [void](Install-FocsStagedDirectory -Root $script:LhmRoot -Source $stage -RequiredFileName 'LibreHardwareMonitorLib.dll')
        $dll=Get-ChildItem -LiteralPath $script:LhmRoot -Filter 'LibreHardwareMonitorLib.dll' -Recurse -File -ErrorAction SilentlyContinue|Select-Object -First 1
        if(-not $dll){throw 'LibreHardwareMonitorLib.dll was not found after the staged copy.'}
        Set-ManagedVersion -Root $script:LhmRoot -Version ($tag+' official')
        Write-KLog "LibreHardwareMonitor updated to $tag"
        return "LibreHardwareMonitor $tag official"
    }finally{
        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Get-FocsLhmDll {
    $d=Get-ChildItem -LiteralPath $script:LhmRoot -Filter 'LibreHardwareMonitorLib.dll' -Recurse -File -ErrorAction SilentlyContinue|Select-Object -First 1
    if($d){return $d.FullName};return $null
}

function Open-FocsTelemetryComputer {
    $dll=Get-FocsLhmDll
    if(-not $dll){return $null}
    try{
        if(-not ('LibreHardwareMonitor.Hardware.Computer' -as [type])){[void][Reflection.Assembly]::LoadFrom($dll)}
        $c=New-Object LibreHardwareMonitor.Hardware.Computer
        foreach($p in @('IsCpuEnabled','IsGpuEnabled','IsMemoryEnabled','IsMotherboardEnabled')){if($c.PSObject.Properties[$p]){$c.$p=$true}}
        $c.Open();return $c
    }catch{Write-KLog "LibreHardwareMonitor init failed: $($_.Exception.Message)";return $null}
}

function Update-FocsHardwareRecursive {
    param([object]$Hardware,[System.Collections.Generic.List[object]]$Rows)
    try{$Hardware.Update()}catch{}
    foreach($s in @($Hardware.Sensors)){
        if($null -ne $s.Value){$Rows.Add([pscustomobject]@{Hardware=[string]$Hardware.HardwareType;HardwareName=[string]$Hardware.Name;SensorType=[string]$s.SensorType;Name=[string]$s.Name;Value=[double]$s.Value})}
    }
    foreach($sub in @($Hardware.SubHardware)){Update-FocsHardwareRecursive -Hardware $sub -Rows $Rows}
}

function Get-FocsTelemetrySample {
    param([object]$Computer)
    $rows=[System.Collections.Generic.List[object]]::new()
    if($Computer){foreach($h in @($Computer.Hardware)){Update-FocsHardwareRecursive -Hardware $h -Rows $rows}}
    function pick($hw,$st,$rx,[string]$mode='avg'){
        $v=@($rows|Where-Object{$_.Hardware -match $hw -and $_.SensorType -eq $st -and $_.Name -match $rx}|ForEach-Object{[double]$_.Value})
        if(-not $v -or $v.Count -eq 0){return $null}
        if($mode -eq 'max'){return [double](($v|Measure-Object -Maximum).Maximum)}
        return [double](($v|Measure-Object -Average).Average)
    }
    $cpuTemp=pick 'Cpu' 'Temperature' 'Package|Tctl|Tdie|CPU' 'max';$gpuTemp=pick 'Gpu' 'Temperature' 'Core|GPU' 'max'
    $cpuLoad=pick 'Cpu' 'Load' 'Total|CPU Total' 'avg';$gpuLoad=pick 'Gpu' 'Load' 'Core|GPU Core|D3D' 'max'
    $cpuClock=pick 'Cpu' 'Clock' 'Core' 'avg';$gpuClock=pick 'Gpu' 'Clock' 'Core|GPU Core' 'max';$cpuPower=pick 'Cpu' 'Power' 'Package|CPU Package|Total' 'max';$gpuPower=pick 'Gpu' 'Power' 'Package|GPU|Total' 'max'
    if($null -eq $gpuTemp -or $null -eq $gpuLoad){
        try{$smi=Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue;if($smi){$raw=& $smi.Source --query-gpu=temperature.gpu,utilization.gpu,clocks.current.graphics,power.draw --format=csv,noheader,nounits 2>$null|Select-Object -First 1;if($raw){$a=$raw -split ',';if($null -eq $gpuTemp){$gpuTemp=[double]$a[0]};if($null -eq $gpuLoad){$gpuLoad=[double]$a[1]};if($null -eq $gpuClock){$gpuClock=[double]$a[2]};if($null -eq $gpuPower){$gpuPower=[double]$a[3]}}}}catch{}
    }
    [pscustomobject]@{Time=(Get-Date).ToString('o');CpuTempC=$cpuTemp;GpuTempC=$gpuTemp;CpuLoadPct=$cpuLoad;GpuLoadPct=$gpuLoad;CpuClockMHz=$cpuClock;GpuClockMHz=$gpuClock;CpuPowerW=$cpuPower;GpuPowerW=$gpuPower}
}

function Start-FocsBenchmarkSet {
    param([string]$ProcessName,[int]$Seconds,[string]$Label,[int]$Runs=3,[System.Windows.Forms.TextBox]$OutputBox)
    if($Runs -lt 2){$Runs=2};if($Runs -gt 7){$Runs=7}
    $set=[System.Collections.Generic.List[object]]::new()
    for($i=1;$i -le $Runs;$i++){
        if($OutputBox){$OutputBox.Text="${Label}: capturing run $i/$Runs...`r`nKeep the game scene/workload as similar as possible between runs.";[System.Windows.Forms.Application]::DoEvents()}
        $csv=Start-PresentMonCapture -ProcessName $ProcessName -Seconds $Seconds -Label ("{0}_R{1}" -f $Label,$i)
        $st=Analyze-PresentMonCsv -Path $csv;$set.Add($st)
        if($i -lt $Runs){Start-Sleep -Seconds 2}
    }
    # Emit benchmark result objects individually so callers that wrap the function in @() receive a flat object array.
    return $set.ToArray()
}

function Get-FocsBenchmarkSetSummary {
    param([object[]]$Set,[string]$Label)
    # Defensive one-level flattening also accepts benchmark sets created by older FOCS builds.
    $Set=@($Set | ForEach-Object { $_ })
    if(-not $Set -or $Set.Count -eq 0){return $null}
    $fps=@($Set|ForEach-Object{[double]$_.AvgFPS});$low=@($Set|ForEach-Object{[double]$_.OnePercentLowFPS});$p99=@($Set|ForEach-Object{[double]$_.P99FrameMs});$cv=@($Set|ForEach-Object{[double]$_.FrameCvPct})
    [pscustomobject]@{Label=$Label;Runs=$Set.Count;AvgFPS=Get-FocsMedianNumber $fps;OneLow=Get-FocsMedianNumber $low;P99=Get-FocsMedianNumber $p99;FrameCv=Get-FocsMedianNumber $cv;FpsNoise=Get-FocsRelativeMadPct $fps;LowNoise=Get-FocsRelativeMadPct $low;P99Noise=Get-FocsRelativeMadPct $p99}
}

function Format-FocsBenchmarkSet {
    param([object[]]$Set,[string]$Label)
    $Set=@($Set | ForEach-Object { $_ })
    $s=Get-FocsBenchmarkSetSummary -Set $Set -Label $Label
    $lines=[System.Collections.Generic.List[string]]::new();$lines.Add("$Label - $($s.Runs) runs")
    for($i=0;$i -lt $Set.Count;$i++){$r=$Set[$i];$lines.Add(('Run {0}: {1:N2} FPS | 1% low {2:N2} | P99 {3:N3} ms | CV {4:N2}%' -f ($i+1),$r.AvgFPS,$r.OnePercentLowFPS,$r.P99FrameMs,$r.FrameCvPct))}
    $lines.Add(('MEDIAN: {0:N2} FPS | 1% low {1:N2} | P99 {2:N3} ms | CV {3:N2}%' -f $s.AvgFPS,$s.OneLow,$s.P99,$s.FrameCv))
    $lines.Add(('Run-to-run MAD noise: FPS {0:N2}% | 1% low {1:N2}% | P99 {2:N2}%' -f $s.FpsNoise,$s.LowNoise,$s.P99Noise))
    return ($lines -join "`r`n")
}

function Compare-FocsBenchmarkSets {
    param([object[]]$Baseline,[object[]]$After)
    $Baseline=@($Baseline | ForEach-Object { $_ });$After=@($After | ForEach-Object { $_ })
    $b=Get-FocsBenchmarkSetSummary $Baseline 'BASELINE';$a=Get-FocsBenchmarkSetSummary $After 'AFTER'
    if(-not $b -or -not $a){throw 'Both benchmark sets are required.'}
    $fpsPct=if($b.AvgFPS){100.0*($a.AvgFPS-$b.AvgFPS)/$b.AvgFPS}else{0};$lowPct=if($b.OneLow){100.0*($a.OneLow-$b.OneLow)/$b.OneLow}else{0};$p99Pct=if($b.P99){100.0*($a.P99-$b.P99)/$b.P99}else{0}
    $noise=[Math]::Max(1.0,[Math]::Max([double]$b.FpsNoise,[double]$a.FpsNoise));$noise=[Math]::Max($noise,[Math]::Max([double]$b.P99Noise,[double]$a.P99Noise))
    if($fpsPct -gt $noise -and $lowPct -gt 0 -and $p99Pct -lt (-0.5*$noise)){$verdict='LIKELY IMPROVEMENT beyond measured run-to-run noise.'}
    elseif($fpsPct -lt (-1*$noise) -and $lowPct -lt 0 -and $p99Pct -gt (0.5*$noise)){$verdict='LIKELY REGRESSION beyond measured run-to-run noise.'}
    else{$verdict='MIXED / WITHIN NOISE. Repeat with a more controlled scene or longer captures.'}
    return ("BASELINE`r`n"+(Format-FocsBenchmarkSet $Baseline 'BASELINE')+"`r`n`r`nAFTER`r`n"+(Format-FocsBenchmarkSet $After 'AFTER')+"`r`n`r`nDELTA (median-to-median)`r`nAverage FPS: $([Math]::Round($fpsPct,2))%`r`n1% low: $([Math]::Round($lowPct,2))%`r`nP99 frametime: $([Math]::Round($p99Pct,2))%`r`nNoise threshold: ~$([Math]::Round($noise,2))%`r`nResult: $verdict")
}

# ===========================================================================
# Network load generation and loaded-latency measurement
#
# Two defects in the previous build are fixed here.
#
# 1. Transfer failures were swallowed by bare catch blocks. If the test
#    endpoint changed, a proxy blocked it, or TLS failed, the worker jobs spun
#    doing nothing, latency stayed flat, and FOCS reported an "A+" grade for a
#    connection it had never actually loaded. Every stream now reports the
#    bytes it really moved, and a run that cannot prove the line was busy is
#    refused instead of graded.
#
# 2. The load ran for a fixed number of seconds while the ping probe took as
#    long as it took. On a badly bloated line the probe outlived the load, so
#    the worst samples were collected on an idle connection - under-reporting
#    bloat on exactly the machines that have it. Loads now run until the caller
#    stops them, and every probe carries a deadline inside the load window.
# ===========================================================================

$script:FocsLoadDownUrl = 'https://speed.cloudflare.com/__down?bytes=100000000'
$script:FocsLoadUpUrl   = 'https://speed.cloudflare.com/__up'

function Get-FocsLoadStatusDir {
    $dir = Join-Path $script:DataRoot 'NetworkLab\LoadStatus'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    return $dir
}

function Start-FocsNetworkLoad {
    param(
        [ValidateSet('Download','Upload')][string]$Direction,
        [int]$MaxSeconds=60,
        [int]$Streams=4
    )
    if ($Streams -lt 1) { $Streams = 1 }
    if ($MaxSeconds -lt 5) { $MaxSeconds = 5 }
    $statusDir = Get-FocsLoadStatusDir
    $token = [guid]::NewGuid().ToString('N')
    $url = if ($Direction -eq 'Download') { $script:FocsLoadDownUrl } else { $script:FocsLoadUpUrl }

    $downBody = {
        param($sec,$url,$statusFile)
        $ErrorActionPreference = 'Continue'
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
        try { [Net.ServicePointManager]::DefaultConnectionLimit = 64 } catch {}
        try { [Net.ServicePointManager]::Expect100Continue = $false } catch {}
        $total = [int64]0
        $lastError = ''
        $end = (Get-Date).AddSeconds($sec)
        $buf = New-Object byte[] 262144
        $lastWrite = [datetime]::MinValue
        while ((Get-Date) -lt $end) {
            $resp = $null
            $stream = $null
            try {
                $req = [Net.HttpWebRequest]::Create($url)
                $req.Method = 'GET'
                $req.Timeout = 10000
                $req.ReadWriteTimeout = 10000
                $req.UserAgent = 'FOCS-Utility'
                $resp = $req.GetResponse()
                $stream = $resp.GetResponseStream()
                while ((Get-Date) -lt $end) {
                    $n = $stream.Read($buf,0,$buf.Length)
                    if ($n -le 0) { break }
                    $total += $n
                    if (((Get-Date) - $lastWrite).TotalMilliseconds -ge 300) {
                        $lastWrite = Get-Date
                        try { [IO.File]::WriteAllText($statusFile,("{0}|{1}" -f $total,$lastError)) } catch {}
                    }
                }
            } catch {
                $lastError = $_.Exception.Message
                Start-Sleep -Milliseconds 250
            } finally {
                if ($stream) { try { $stream.Dispose() } catch {} }
                if ($resp) { try { $resp.Close() } catch {} }
            }
        }
        try { [IO.File]::WriteAllText($statusFile,("{0}|{1}" -f $total,$lastError)) } catch {}
    }

    $upBody = {
        param($sec,$url,$statusFile)
        $ErrorActionPreference = 'Continue'
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
        try { [Net.ServicePointManager]::DefaultConnectionLimit = 64 } catch {}
        try { [Net.ServicePointManager]::Expect100Continue = $false } catch {}
        $total = [int64]0
        $lastError = ''
        $end = (Get-Date).AddSeconds($sec)
        $chunk = New-Object byte[] 262144
        # Random bytes, so nothing in the path can compress the load away.
        (New-Object System.Random).NextBytes($chunk)
        $perRequest = [int64]268435456
        $lastWrite = [datetime]::MinValue
        while ((Get-Date) -lt $end) {
            $req = $null
            $rs = $null
            $sent = [int64]0
            try {
                $req = [Net.HttpWebRequest]::Create($url)
                $req.Method = 'POST'
                $req.ContentType = 'application/octet-stream'
                $req.AllowWriteStreamBuffering = $false
                $req.ContentLength = $perRequest
                $req.Timeout = 15000
                $req.ReadWriteTimeout = 15000
                $req.UserAgent = 'FOCS-Utility'
                # One long streaming request per attempt keeps the uplink continuously busy.
                # Repeated small POSTs left idle gaps between requests and under-loaded the line.
                $rs = $req.GetRequestStream()
                while ((Get-Date) -lt $end -and $sent -lt $perRequest) {
                    $rs.Write($chunk,0,$chunk.Length)
                    $sent += $chunk.Length
                    $total += $chunk.Length
                    if (((Get-Date) - $lastWrite).TotalMilliseconds -ge 300) {
                        $lastWrite = Get-Date
                        try { [IO.File]::WriteAllText($statusFile,("{0}|{1}" -f $total,$lastError)) } catch {}
                    }
                }
            } catch {
                $lastError = $_.Exception.Message
            }
            if ($sent -ge $perRequest) {
                if ($rs) { try { $rs.Dispose() } catch {} }
                try { $req.GetResponse().Close() } catch {}
            } elseif ($req) {
                # The declared body was deliberately left incomplete, so abort rather than
                # closing the stream: closing early throws and leaks the connection.
                try { $req.Abort() } catch {}
            }
            if ($lastError) { Start-Sleep -Milliseconds 250 }
        }
        try { [IO.File]::WriteAllText($statusFile,("{0}|{1}" -f $total,$lastError)) } catch {}
    }

    $body = if ($Direction -eq 'Download') { $downBody } else { $upBody }
    $jobs = [System.Collections.Generic.List[object]]::new()
    $files = [System.Collections.Generic.List[string]]::new()
    for ($i=0; $i -lt $Streams; $i++) {
        $statusFile = Join-Path $statusDir ("{0}_{1}_{2}.status" -f $Direction,$token,$i)
        try { [IO.File]::WriteAllText($statusFile,'0|') } catch {}
        $files.Add($statusFile)
        $jobs.Add((Start-Job -ScriptBlock $body -ArgumentList $MaxSeconds,$url,$statusFile))
    }
    Write-KLog "Network load started: $Direction, $Streams stream(s), budget ${MaxSeconds}s"
    return [pscustomobject]@{ Direction=$Direction; Jobs=$jobs.ToArray(); StatusFiles=$files.ToArray(); Started=(Get-Date); MaxSeconds=$MaxSeconds; Streams=$Streams }
}

function Get-FocsNetworkLoadStatus {
    param([object]$Load)
    $bytes = [int64]0
    $errors = [System.Collections.Generic.List[string]]::new()
    foreach ($f in @($Load.StatusFiles)) {
        try {
            $raw = [IO.File]::ReadAllText($f)
            $parts = $raw -split '\|',2
            if ($parts.Count -ge 1 -and $parts[0]) { $bytes += [int64]$parts[0] }
            if ($parts.Count -ge 2) {
                $err = [string]$parts[1]
                if ($err -and -not $errors.Contains($err)) { $errors.Add($err) }
            }
        } catch {}
    }
    $elapsed = [Math]::Max(0.25,((Get-Date) - $Load.Started).TotalSeconds)
    return [pscustomobject]@{ Bytes=$bytes; Seconds=$elapsed; Mbps=(($bytes*8.0)/1000000.0/$elapsed); Errors=$errors.ToArray() }
}

function Wait-FocsNetworkLoadReady {
    param([object]$Load,[int]$TimeoutSec=12,[int64]$MinBytes=1500000)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        $s = Get-FocsNetworkLoadStatus -Load $Load
        if ($s.Bytes -ge $MinBytes) { return [pscustomobject]@{ Ready=$true; Status=$s } }
        Start-Sleep -Milliseconds 300
        [System.Windows.Forms.Application]::DoEvents()
    }
    return [pscustomobject]@{ Ready=$false; Status=(Get-FocsNetworkLoadStatus -Load $Load) }
}

function Stop-FocsNetworkLoad {
    param([object]$Load)
    if (-not $Load) { return $null }
    # Read the counters before the workers are killed; Stop-Job discards job output.
    $status = Get-FocsNetworkLoadStatus -Load $Load
    foreach ($j in @($Load.Jobs)) {
        try { Stop-Job -Job $j -ErrorAction SilentlyContinue } catch {}
        try { Remove-Job -Job $j -Force -ErrorAction SilentlyContinue } catch {}
    }
    foreach ($f in @($Load.StatusFiles)) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
    Write-KLog ("Network load stopped: {0}, {1:N1} MB in {2:N1}s ({3:N1} Mbps)" -f $Load.Direction,($status.Bytes/1MB),$status.Seconds,$status.Mbps)
    return $status
}

function Test-FocsLoadUsable {
    param([object]$Status,[double]$ExpectedMbps=0,[string]$Direction='Upload')
    if (-not $Status) { return [pscustomobject]@{ Ok=$false; Reason='No load statistics were produced.' } }
    if ([int64]$Status.Bytes -lt 2000000) {
        $detail = ''
        if (@($Status.Errors).Count -gt 0) { $detail = ' Last transfer error: ' + [string](@($Status.Errors)[0]) }
        return [pscustomobject]@{ Ok=$false; Reason=("The {0} load moved only {1:N2} MB, so the connection was never actually busy and any latency reading would be meaningless.{2}" -f $Direction,($Status.Bytes/1MB),$detail) }
    }
    $floor = 1.0
    if ($ExpectedMbps -gt 0) { $floor = [Math]::Max(1.0,$ExpectedMbps*0.25) }
    if ([double]$Status.Mbps -lt $floor) {
        return [pscustomobject]@{ Ok=$false; Reason=("The {0} load only reached {1:N1} Mbps against an expected floor of {2:N1} Mbps, so the line was not saturated and the result would understate bufferbloat." -f $Direction,$Status.Mbps,$floor) }
    }
    return [pscustomobject]@{ Ok=$true; Reason=("{0} load verified: {1:N1} Mbps, {2:N1} MB moved." -f $Direction,$Status.Mbps,($Status.Bytes/1MB)) }
}

function Invoke-FocsLoadedLatencyPhase {
    param(
        [ValidateSet('Download','Upload')][string]$Direction,
        [string]$Target,
        [string]$Gateway,
        [double]$QuietMedianMs,
        [int]$Count=35,
        [int]$GatewayCount=15,
        [double]$ExpectedMbps=0,
        [string]$Stage='Load phase',
        [System.Windows.Forms.TextBox]$OutputBox
    )
    # Size the load so it comfortably outlasts both ping probes even if the line bloats badly.
    $assumedRtt = [Math]::Min(800.0,[Math]::Max(80.0,[double]$QuietMedianMs*8.0))
    $probeSeconds = (Get-FocsProbeSeconds -Count $Count -ExpectedRttMs $assumedRtt) + (Get-FocsProbeSeconds -Count $GatewayCount -ExpectedRttMs $assumedRtt)
    $maxSeconds = [int]($probeSeconds + 15)

    Set-FocsOutputText $OutputBox ("{0}`r`nStarting {1} load..." -f $Stage,$Direction.ToLower())
    $load = Start-FocsNetworkLoad -Direction $Direction -MaxSeconds $maxSeconds
    $status = $null; $loaded = $null; $loadedGw = $null; $ready = $null
    try {
        $ready = Wait-FocsNetworkLoadReady -Load $load -TimeoutSec 12
        Set-FocsOutputText $OutputBox ("{0}`r`nMeasuring latency under {1} load..." -f $Stage,$Direction.ToLower())
        # Hard deadline keeps every ping sample inside the live load window.
        $deadline = $load.Started.AddSeconds($maxSeconds - 4)
        $loaded = Test-NetworkLatency -HostName $Target -Count $Count -TimeoutMs 1800 -Deadline $deadline
        if ($Gateway) {
            try { $loadedGw = Test-NetworkLatency -HostName $Gateway -Count $GatewayCount -TimeoutMs 1000 -Deadline $deadline }
            catch { Write-KLog "Gateway probe under load failed: $($_.Exception.Message)"; $loadedGw = $null }
        }
    } finally {
        $status = Stop-FocsNetworkLoad -Load $load
    }
    $usable = Test-FocsLoadUsable -Status $status -ExpectedMbps $ExpectedMbps -Direction $Direction
    if (-not $usable.Ok) { Write-KLog "Load verification failed: $($usable.Reason)" }
    return [pscustomobject]@{
        Direction=$Direction
        Loaded=$loaded
        LoadedGateway=$loadedGw
        LoadStatus=$status
        LoadOk=[bool]$usable.Ok
        LoadReason=[string]$usable.Reason
        Ready=[bool]$ready.Ready
        Truncated=[bool]$loaded.Truncated
    }
}

function Invoke-FocsBufferbloatTest {
    param(
        [string]$AdapterName,
        [System.Windows.Forms.TextBox]$OutputBox,
        [double]$ExpectedUploadMbps=0,
        [double]$ExpectedDownloadMbps=0,
        [switch]$PassThru
    )
    $target='1.1.1.1';$gw=Get-FocsDefaultGateway
    Set-FocsOutputText $OutputBox 'Loaded-latency test: measuring the quiet line...'
    $quiet=Test-NetworkLatency -HostName $target -Count 30 -TimeoutMs 1500
    $quietGw=if($gw){Test-NetworkLatency -HostName $gw -Count 20 -TimeoutMs 1000}else{$null}
    $downPhase=Invoke-FocsLoadedLatencyPhase -Direction Download -Target $target -Gateway $gw -QuietMedianMs ([double]$quiet.Median) -Count 35 -GatewayCount 15 -ExpectedMbps $ExpectedDownloadMbps -Stage 'Loaded-latency test: DOWNLOAD phase' -OutputBox $OutputBox
    $upPhase=Invoke-FocsLoadedLatencyPhase -Direction Upload -Target $target -Gateway $gw -QuietMedianMs ([double]$quiet.Median) -Count 35 -GatewayCount 15 -ExpectedMbps $ExpectedUploadMbps -Stage 'Loaded-latency test: UPLOAD phase' -OutputBox $OutputBox
    $down=$downPhase.Loaded;$up=$upPhase.Loaded;$downGw=$downPhase.LoadedGateway;$upGw=$upPhase.LoadedGateway
    $downAdd=[double]$down.Median-[double]$quiet.Median;$upAdd=[double]$up.Median-[double]$quiet.Median
    $downSpread=[double]$down.P95-[double]$down.Median;$upSpread=[double]$up.P95-[double]$up.Median
    $bothOk=[bool]($downPhase.LoadOk -and $upPhase.LoadOk)
    $gamingWorstP95=[Math]::Max([double]$quiet.P95,[Math]::Max([double]$down.P95,[double]$up.P95))
    $gamingLoss=[Math]::Max([double]$quiet.LossPct,[Math]::Max([double]$down.LossPct,[double]$up.LossPct))
    $gamingState=if($bothOk){Get-FocsGamingLatencyState -P95 $gamingWorstP95 -LossPct $gamingLoss}else{'UNKNOWN'}
    $r=[pscustomobject]@{
        Measured=(Get-Date).ToString('o');Adapter=$AdapterName;Target=$target
        QuietMedian=[double]$quiet.Median;QuietP95=[double]$quiet.P95;QuietLoss=[double]$quiet.LossPct
        DownloadMedian=[double]$down.Median;DownloadP95=[double]$down.P95;DownloadLoss=[double]$down.LossPct;DownloadAdded=$downAdd;DownloadSpread=$downSpread
        DownloadLoadMbps=[double]$downPhase.LoadStatus.Mbps;DownloadLoadMB=($downPhase.LoadStatus.Bytes/1MB);DownloadLoadOk=$downPhase.LoadOk;DownloadLoadReason=$downPhase.LoadReason
        UploadMedian=[double]$up.Median;UploadP95=[double]$up.P95;UploadLoss=[double]$up.LossPct;UploadAdded=$upAdd;UploadSpread=$upSpread
        UploadLoadMbps=[double]$upPhase.LoadStatus.Mbps;UploadLoadMB=($upPhase.LoadStatus.Bytes/1MB);UploadLoadOk=$upPhase.LoadOk;UploadLoadReason=$upPhase.LoadReason
        Graded=$bothOk;GamingWorstP95=[double]$gamingWorstP95;GamingLoss=[double]$gamingLoss;GamingState=$gamingState
        GatewayQuiet=if($quietGw){[double]$quietGw.Median}else{$null};GatewayQuietP95=if($quietGw){[double]$quietGw.P95}else{$null}
        GatewayDownload=if($downGw){[double]$downGw.Median}else{$null};GatewayDownloadP95=if($downGw){[double]$downGw.P95}else{$null}
        GatewayUpload=if($upGw){[double]$upGw.Median}else{$null};GatewayUploadP95=if($upGw){[double]$upGw.P95}else{$null}
    }
    $worstAdded=[Math]::Max([double]$downAdd,[double]$upAdd)
    $grade=if(-not $bothOk){'NOT GRADED'}elseif($worstAdded -lt 5){'A+'}elseif($worstAdded -lt 30){'A'}elseif($worstAdded -lt 60){'B'}elseif($worstAdded -lt 200){'C'}elseif($worstAdded -lt 400){'D'}else{'F'}
    $txt=[System.Collections.Generic.List[string]]::new();$txt.Add('LOADED LATENCY / GAMING TAIL-LATENCY DIAGNOSTIC')
    $txt.Add(('Idle: median {0:N1} ms | P95 {1:N1} ms | loss {2:N1}%' -f $quiet.Median,$quiet.P95,$quiet.LossPct))
    $txt.Add(('Download active: median {0:N1} ms | P95 {1:N1} ms | added median {2:+0.0;-0.0;0.0} ms | loss {3:N1}%' -f $down.Median,$down.P95,$downAdd,$down.LossPct));$txt.Add(('  '+$downPhase.LoadReason))
    $txt.Add(('Upload active: median {0:N1} ms | P95 {1:N1} ms | added median {2:+0.0;-0.0;0.0} ms | loss {3:N1}%' -f $up.Median,$up.P95,$upAdd,$up.LossPct));$txt.Add(('  '+$upPhase.LoadReason))
    if($downPhase.Truncated -or $upPhase.Truncated){$txt.Add('Note: a probe hit its live-load deadline and used fewer samples than requested.')}
    if($bothOk){
        $txt.Add("Bufferbloat grade: $grade (added-median view)")
        $txt.Add(('LOW LATENCY GAMING: {0} | worst P95 {1:N1} ms | target is < 40 ms.' -f $gamingState,$gamingWorstP95))
        if($gamingState -ne 'PASS'){$txt.Add('Gaming warning means tail latency is still too high even if the average/median looks good. P95 spikes matter more than a pretty average for fast games.')}
    }else{$txt.Add('LOW LATENCY GAMING: UNKNOWN - load saturation could not be verified.')}
    if($quietGw -and $downGw -and $upGw){$gwWorst=[Math]::Max([double]$quietGw.P95,[Math]::Max([double]$downGw.P95,[double]$upGw.P95));$txt.Add(('Gateway P95 idle/down/up: {0:N1} / {1:N1} / {2:N1} ms | worst {3:N1} ms' -f $quietGw.P95,$downGw.P95,$upGw.P95,$gwWorst))}
    $txt.Add('Diagnosis: if gateway P95 is high, investigate the PC/LAN/router first hop. If gateway is clean but public loaded P95 is high, the bottleneck is farther upstream or in WAN queueing.')
    $txt.Add('Router-side SQM with CAKE/FQ-CoDel is the preferred whole-network bufferbloat fix. Windows QoS is only an outbound single-PC experiment.')
    $dir=Join-Path $script:DataRoot 'NetworkLab';New-Item -ItemType Directory -Path $dir -Force|Out-Null;$path=Join-Path $dir ('loaded_latency_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.json')
    $r|Add-Member -NotePropertyName BufferbloatGrade -NotePropertyValue $grade -Force;$r|Add-Member -NotePropertyName Text -NotePropertyValue ($txt -join "`r`n") -Force
    $r|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $path -Encoding UTF8
    $r.Text += "`r`nSaved: $path"
    if($PassThru){return $r};return $r.Text
}

function Get-FocsBufferbloatPolicyName { return 'FOCS Bufferbloat Upload Guard' }

function Get-FocsBufferbloatProfilePath {
    $dir=Join-Path $script:DataRoot 'NetworkLab';New-Item -ItemType Directory -Path $dir -Force|Out-Null
    return (Join-Path $dir 'bufferbloat_upload_guard.json')
}

function Get-FocsBufferbloatMarkerPath {
    $dir=Join-Path $script:DataRoot 'NetworkLab';New-Item -ItemType Directory -Path $dir -Force|Out-Null
    return (Join-Path $dir 'active_guard.json')
}

function Set-FocsBufferbloatMarker {
    param([object]$Guard,[bool]$Trial)
    try {
        [pscustomobject]@{ Applied=(Get-Date).ToString('o'); Trial=$Trial; CapMbps=$Guard.CapMbps; Percent=$Guard.Percent; UploadMbps=$Guard.UploadMbps } |
            ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Get-FocsBufferbloatMarkerPath) -Encoding UTF8
    } catch { Write-KLog "Could not write the QoS guard marker: $($_.Exception.Message)" }
}

function Clear-FocsBufferbloatMarker {
    try { Remove-Item -LiteralPath (Get-FocsBufferbloatMarkerPath) -Force -ErrorAction SilentlyContinue } catch {}
}

function Get-FocsBufferbloatGuardStatus {
    $name=Get-FocsBufferbloatPolicyName
    if(-not(Get-Command Get-NetQosPolicy -ErrorAction SilentlyContinue)){return [pscustomobject]@{Supported=$false;Active=$false;RateBits=0;Text='Windows NetQos cmdlets are not available.'}}
    $p=$null
    try{$p=Get-NetQosPolicy -PolicyStore ActiveStore -Name $name -ErrorAction Stop|Select-Object -First 1}catch{
        try{$p=Get-NetQosPolicy -Name $name -ErrorAction SilentlyContinue|Select-Object -First 1}catch{}
    }
    $rate=0L
    if($p){
        foreach($prop in @('ThrottleRateAction','ThrottleRateActionBitsPerSecond')){try{if($p.PSObject.Properties[$prop] -and $p.$prop){$rate=[int64]$p.$prop;break}}catch{}}
    }
    $txt=if($p){if($rate -gt 0){'Active at '+([Math]::Round($rate/1000000.0,1))+' Mbps outbound'}else{'Active (rate exposed by Windows as formatted text)'}}else{'Not active'}
    return [pscustomobject]@{Supported=$true;Active=[bool]$p;RateBits=$rate;Text=$txt}
}

function Remove-FocsBufferbloatUploadGuard {
    $name=Get-FocsBufferbloatPolicyName
    if(-not(Get-Command Remove-NetQosPolicy -ErrorAction SilentlyContinue)){throw 'Windows NetQos cmdlets are not available on this installation.'}
    try{
        $local=@(Get-NetQosPolicy -Name $name -ErrorAction SilentlyContinue)
        foreach($p in $local){try{$p|Remove-NetQosPolicy -Confirm:$false -ErrorAction Stop}catch{Write-KLog "QoS policy removal attempt failed: $($_.Exception.Message)"}}
        try{Remove-NetQosPolicy -Name $name -Confirm:$false -ErrorAction SilentlyContinue}catch{}
    }catch{throw "Could not remove the FOCS QoS policy: $($_.Exception.Message)"}
    Clear-FocsBufferbloatMarker
    Write-KLog 'FOCS Bufferbloat Upload Guard removed.'
    return 'FOCS upload guard removed. Windows is no longer applying the FOCS outbound bandwidth cap.'
}

function Invoke-FocsNetworkFullRevert {
    param([string]$AdapterName,[System.Windows.Forms.TextBox]$OutputBox)
    # Combines the two undo paths that matter most after a bad tuning result: the FOCS outbound
    # QoS cap (which can itself become the bottleneck if set too low) and any NIC advanced
    # properties the Network Performance Lab accepted (including buffer/flow-control changes, which
    # are now the strict-latency candidates above). One button, one backup, one report.
    if ([string]::IsNullOrWhiteSpace($AdapterName)) { throw 'Choose a network adapter first.' }
    $lines=[System.Collections.Generic.List[string]]::new()
    $lines.Add('FULL NETWORK REVERT')
    Set-FocsOutputText $OutputBox ($lines -join "`r`n")

    $guardBefore=Get-FocsBufferbloatGuardStatus
    $lines.Add("Upload guard before: $($guardBefore.Text)")
    if($guardBefore.Active){
        try{ $lines.Add((Remove-FocsBufferbloatUploadGuard)) }
        catch{ $lines.Add("Upload guard removal failed: $($_.Exception.Message)") }
    } else {
        $lines.Add('No FOCS upload guard was active.')
    }

    $lines.Add('')
    Set-FocsOutputText $OutputBox (($lines -join "`r`n") + "`r`nResetting $AdapterName to driver defaults (the adapter will briefly disconnect)...")
    try{
        $nicMsg=Reset-KNicDriverDefaults -AdapterName $AdapterName
        $lines.Add($nicMsg)
    } catch {
        $lines.Add("NIC reset failed: $($_.Exception.Message)")
    }

    $lines.Add('')
    $lines.Add('Both undo paths ran. Re-run LOADED LATENCY / BUFFERBLOAT to see whether this alone accounts for the bad grade. If it does not, the bottleneck is most likely upstream of this PC - look at router-side SQM/CAKE/FQ-CoDel.')
    Write-KLog 'Full network revert (upload guard + NIC driver defaults) completed.'
    return ($lines -join "`r`n")
}

function Set-FocsBufferbloatUploadGuard {
    param([double]$UploadMbps,[double]$Percent,[switch]$Trial)
    if($UploadMbps -lt 2 -or $UploadMbps -gt 10000){throw 'Enter a realistic measured upload speed between 2 and 10000 Mbps.'}
    if($Percent -lt 50 -or $Percent -gt 99){throw 'Guard percentage must be between 50% and 99%.'}
    if(-not(Get-Command New-NetQosPolicy -ErrorAction SilentlyContinue)){try{Import-Module NetQos -ErrorAction Stop}catch{throw 'Windows NetQos is not available, so FOCS cannot create a local upload shaper.'}}
    $name=Get-FocsBufferbloatPolicyName
    try{Remove-NetQosPolicy -Name $name -PolicyStore ActiveStore -Confirm:$false -ErrorAction SilentlyContinue}catch{};try{Remove-NetQosPolicy -Name $name -Confirm:$false -ErrorAction SilentlyContinue}catch{}
    $capMbps=$UploadMbps*($Percent/100.0);$bits=[UInt64][Math]::Max(1000000,[Math]::Round($capMbps*1000000.0))
    try{New-NetQosPolicy -Name $name -Default -NetworkProfile All -PolicyStore ActiveStore -ThrottleRateActionBitsPerSecond $bits -ErrorAction Stop|Out-Null}catch{throw "Windows could not create the temporary FOCS QoS upload guard: $($_.Exception.Message)"}
    Start-Sleep -Milliseconds 450;$guard=[pscustomobject]@{UploadMbps=$UploadMbps;Percent=$Percent;CapMbps=$capMbps;RateBits=$bits;Temporary=$true}
    Set-FocsBufferbloatMarker -Guard $guard -Trial ([bool]$Trial)
    Write-KLog ("Temporary FOCS Bufferbloat Upload Guard: measured={0:N1} Mbps cap={1:N1} Mbps ({2:N0}%) trial={3}. ActiveStore only." -f $UploadMbps,$capMbps,$Percent,[bool]$Trial)
    return $guard
}

function Resolve-FocsOrphanedBufferbloatGuard {
    $path=Get-FocsBufferbloatMarkerPath
    if(-not(Test-Path -LiteralPath $path)){return $null}
    $marker=$null
    try{$marker=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json}catch{Write-KLog "QoS guard marker unreadable: $($_.Exception.Message)"}
    if(-not $marker){Clear-FocsBufferbloatMarker;return $null}
    if(-not $marker.Trial){return $null}
    $status=Get-FocsBufferbloatGuardStatus
    if(-not $status.Active){Clear-FocsBufferbloatMarker;return $null}
    try{
        [void](Remove-FocsBufferbloatUploadGuard)
        $msg=("FOCS found a leftover trial upload cap of {0:N1} Mbps from a Bufferbloat Reducer run that did not finish, and removed it. Your outbound traffic is uncapped again." -f [double]$marker.CapMbps)
        Write-KLog $msg
        return $msg
    }catch{
        Write-KLog "Could not remove the orphaned QoS guard: $($_.Exception.Message)"
        return $null
    }
}

function Invoke-FocsUploadLoadedLatencyProbe {
    param([string]$AdapterName,[string]$Stage='Probe',[System.Windows.Forms.TextBox]$OutputBox,[double]$ExpectedUploadMbps=0,[double]$ExpectedCapMbps=0)
    $target='1.1.1.1';$gw=Get-FocsDefaultGateway
    Set-FocsOutputText $OutputBox ("{0}`r`nMeasuring quiet latency..." -f $Stage)
    $quiet=Test-NetworkLatency -HostName $target -Count 20 -TimeoutMs 1500;$quietGw=if($gw){Test-NetworkLatency -HostName $gw -Count 10 -TimeoutMs 1000}else{$null}
    $phase=Invoke-FocsLoadedLatencyPhase -Direction Upload -Target $target -Gateway $gw -QuietMedianMs ([double]$quiet.Median) -Count 32 -GatewayCount 12 -ExpectedMbps $ExpectedUploadMbps -Stage $Stage -OutputBox $OutputBox
    $up=$phase.Loaded;$upGw=$phase.LoadedGateway;$added=[double]$up.Median-[double]$quiet.Median;$spread=[double]$up.P95-[double]$up.Median;$gwAdded=if($quietGw -and $upGw){[double]$upGw.Median-[double]$quietGw.Median}else{0.0}
    $loadOk=[bool]$phase.LoadOk;$capRatio=$null;$capReason=''
    if($ExpectedCapMbps -gt 0){
        $capRatio=[double]$phase.LoadStatus.Mbps/$ExpectedCapMbps
        if($capRatio -gt 1.35){$loadOk=$false;$capReason=("Generated upload reached {0:N0}% of the requested cap, so Windows QoS did not behave like an aggregate shaper." -f ($capRatio*100.0))}
        elseif($capRatio -lt 0.45){$loadOk=$false;$capReason=("Generated upload reached only {0:N0}% of the requested cap, so the shaped path was not loaded hard enough." -f ($capRatio*100.0))}
        else{$capReason=("Cap enforcement plausible: {0:N1} Mbps generated for {1:N1} Mbps cap." -f $phase.LoadStatus.Mbps,$ExpectedCapMbps)}
    }
    [pscustomobject]@{Stage=$Stage;Adapter=$AdapterName;QuietMedian=[double]$quiet.Median;QuietP95=[double]$quiet.P95;QuietLoss=[double]$quiet.LossPct;UploadMedian=[double]$up.Median;UploadP95=[double]$up.P95;UploadLoss=[double]$up.LossPct;AddedMs=$added;SpreadMs=$spread;GatewayAddedMs=$gwAdded;GatewayP95=if($upGw){[double]$upGw.P95}else{$null};LoadMbps=[double]$phase.LoadStatus.Mbps;LoadBytes=[int64]$phase.LoadStatus.Bytes;LoadOk=$loadOk;LoadReason=([string]$phase.LoadReason+' '+$capReason);CapRatio=$capRatio;Truncated=[bool]$phase.Truncated}
}

function Invoke-FocsProbeSet {
    param([string]$AdapterName,[string]$Stage,[int]$Repeats=2,[double]$ExpectedUploadMbps=0,[double]$ExpectedCapMbps=0,[System.Windows.Forms.TextBox]$OutputBox)
    if($Repeats -lt 1){$Repeats=1};if($Repeats -gt 4){$Repeats=4}
    $probes=[System.Collections.Generic.List[object]]::new()
    for($r=1;$r -le $Repeats;$r++){
        $label=if($Repeats -gt 1){("{0} (run {1}/{2})" -f $Stage,$r,$Repeats)}else{$Stage}
        $p=Invoke-FocsUploadLoadedLatencyProbe -AdapterName $AdapterName -Stage $label -OutputBox $OutputBox -ExpectedUploadMbps $ExpectedUploadMbps -ExpectedCapMbps $ExpectedCapMbps
        if(-not $p.LoadOk){throw ("FOCS stopped because the load/cap validation failed during '{0}'.`r`n{1}" -f $label,$p.LoadReason)}
        $probes.Add($p);if($r -lt $Repeats){Start-Sleep -Milliseconds 1100}
    }
    $arr=$probes.ToArray();$added=@($arr|ForEach-Object{[double]$_.AddedMs});$loss=@($arr|ForEach-Object{[double]$_.UploadLoss});$spread=@($arr|ForEach-Object{[double]$_.SpreadMs});$p95=@($arr|ForEach-Object{[double]$_.UploadP95});$quietP95=@($arr|ForEach-Object{[double]$_.QuietP95});$mbps=@($arr|ForEach-Object{[double]$_.LoadMbps})
    $addedRange=if($added.Count -gt 1){[double](($added|Measure-Object -Maximum).Maximum)-[double](($added|Measure-Object -Minimum).Minimum)}else{0.0};$p95Range=if($p95.Count -gt 1){[double](($p95|Measure-Object -Maximum).Maximum)-[double](($p95|Measure-Object -Minimum).Minimum)}else{0.0}
    [pscustomobject]@{Stage=$Stage;Runs=$arr.Count;Probes=$arr;AddedMs=(Get-FocsMedianNumber -Values $added);UploadLoss=(Get-FocsMedianNumber -Values $loss);SpreadMs=(Get-FocsMedianNumber -Values $spread);QuietP95=(Get-FocsMedianNumber -Values $quietP95);UploadP95=(Get-FocsMedianNumber -Values $p95);LoadMbps=(Get-FocsMedianNumber -Values $mbps);AddedRange=$addedRange;P95Range=$p95Range;GamingState=(Get-FocsGamingLatencyState -P95 (Get-FocsMedianNumber -Values $p95) -LossPct (Get-FocsMedianNumber -Values $loss))}
}

function Get-FocsBufferbloatCandidateScore {
    param([object]$Measurement,[double]$Percent)
    if(-not $Measurement){return [double]::PositiveInfinity}
    $lossPenalty=[Math]::Max(0.0,[double]$Measurement.UploadLoss)*2000.0
    $absoluteTail=[Math]::Max(0.0,[double]$Measurement.UploadP95)*3.0
    $overGamingGate=[Math]::Max(0.0,[double]$Measurement.UploadP95-40.0)*100.0
    $medianPenalty=[Math]::Max(0.0,[double]$Measurement.AddedMs)
    $headroomPenalty=(100.0-$Percent)*0.45
    return ($lossPenalty+$absoluteTail+$overGamingGate+$medianPenalty+$headroomPenalty)
}

function Invoke-FocsBufferbloatReducer {
    param([string]$AdapterName,[double]$UploadMbps,[System.Windows.Forms.TextBox]$OutputBox,[int]$Repeats=2)
    if(-not $AdapterName){throw 'Choose a network adapter first.'};if($UploadMbps -lt 2){throw 'Enter your measured upload speed first.'}
    if(-not(Get-Command New-NetQosPolicy -ErrorAction SilentlyContinue)){try{Import-Module NetQos -ErrorAction Stop}catch{throw 'Windows NetQos is not available on this system.'}}
    if($Repeats -lt 2){$Repeats=2};if($Repeats -gt 3){$Repeats=3}
    $profilePath=Get-FocsBufferbloatProfilePath;$keep=$false;$results=[System.Collections.Generic.List[object]]::new();$best=$null;$committed=$false
    try{
        [void](Remove-FocsBufferbloatUploadGuard);Start-Sleep -Milliseconds 700
        Set-FocsOutputText $OutputBox "BUFFERBLOAT / GAMING P95 REDUCER`r`nStep 1/4: uncapped baseline..."
        $baselineStart=Invoke-FocsProbeSet -AdapterName $AdapterName -Stage 'UNCAPPED BASELINE' -Repeats $Repeats -ExpectedUploadMbps $UploadMbps -OutputBox $OutputBox
        $percents=[System.Collections.Generic.List[double]]::new();foreach($p in @(97,95,92,90,87,85,82,80)){[void]$percents.Add([double]$p)}
        if([double]$baselineStart.UploadP95 -ge 120){[void]$percents.Add(75.0)}
        $order=@($percents.ToArray()|Sort-Object{Get-Random});$bestScore=[double]::PositiveInfinity
        Set-FocsOutputText $OutputBox "BUFFERBLOAT / GAMING P95 REDUCER`r`nStep 2/4: temporary cap screening..."
        foreach($pct in $order){
            $guard=Set-FocsBufferbloatUploadGuard -UploadMbps $UploadMbps -Percent $pct -Trial;Start-Sleep -Milliseconds 600
            $m=Invoke-FocsProbeSet -AdapterName $AdapterName -Stage ("TEMP CAP {0:N0}%" -f $pct) -Repeats 2 -ExpectedUploadMbps $guard.CapMbps -ExpectedCapMbps $guard.CapMbps -OutputBox $OutputBox
            $score=Get-FocsBufferbloatCandidateScore -Measurement $m -Percent $pct;$p95Regression=[double]$m.UploadP95 -gt ([double]$baselineStart.UploadP95+3.0)
            $row=[pscustomobject]@{Percent=$pct;CapMbps=$guard.CapMbps;Score=$score;Measurement=$m;P95Regression=$p95Regression};$results.Add($row)
            if(-not $p95Regression -and [double]$m.UploadLoss -le ([double]$baselineStart.UploadLoss+0.5) -and $score -lt $bestScore){$best=$row;$bestScore=$score}
            [void](Remove-FocsBufferbloatUploadGuard);Start-Sleep -Milliseconds 600
        }
        $baselineEnd=Invoke-FocsProbeSet -AdapterName $AdapterName -Stage 'UNCAPPED RECHECK' -Repeats 2 -ExpectedUploadMbps $UploadMbps -OutputBox $OutputBox
        $baselineP95=Get-FocsMedianNumber -Values @([double]$baselineStart.UploadP95,[double]$baselineEnd.UploadP95);$baselineAdded=Get-FocsMedianNumber -Values @([double]$baselineStart.AddedMs,[double]$baselineEnd.AddedMs)
        $p95Noise=[Math]::Max(3.0,[Math]::Max([double]$baselineStart.P95Range,[Math]::Max([double]$baselineEnd.P95Range,[Math]::Abs([double]$baselineStart.UploadP95-[double]$baselineEnd.UploadP95))))
        $requiredP95Gain=[Math]::Max($p95Noise,[Math]::Max(4.0,$baselineP95*0.10));$p95Gain=if($best){$baselineP95-[double]$best.Measurement.UploadP95}else{0.0}
        if(-not $best -or $p95Gain -lt $requiredP95Gain){[void](Remove-FocsBufferbloatUploadGuard);return ("BUFFERBLOAT / GAMING P95 REDUCER`r`nNo Windows cap produced a repeatable gaming-tail improvement.`r`nBaseline upload P95: {0:N1} ms | best gain: {1:N1} ms | required: {2:N1} ms.`r`nFOCS left the PC uncapped. Router SQM/CAKE/FQ-CoDel is the preferred fix." -f $baselineP95,$p95Gain,$requiredP95Gain)}
        # Full A/B regression gate. The same complete test is run uncapped and capped; median-only wins are not enough.
        Set-FocsOutputText $OutputBox "BUFFERBLOAT / GAMING P95 REDUCER`r`nStep 3/4: full uncapped validation...";[void](Remove-FocsBufferbloatUploadGuard)
        $fullBase=Invoke-FocsBufferbloatTest -AdapterName $AdapterName -OutputBox $OutputBox -ExpectedUploadMbps $UploadMbps -PassThru
        $g=Set-FocsBufferbloatUploadGuard -UploadMbps $UploadMbps -Percent ([double]$best.Percent) -Trial
        Set-FocsOutputText $OutputBox "BUFFERBLOAT / GAMING P95 REDUCER`r`nStep 4/4: full capped validation..."
        $fullCap=Invoke-FocsBufferbloatTest -AdapterName $AdapterName -OutputBox $OutputBox -ExpectedUploadMbps $g.CapMbps -PassThru
        [void](Remove-FocsBufferbloatUploadGuard)
        $fullP95Gain=[double]$fullBase.GamingWorstP95-[double]$fullCap.GamingWorstP95;$fullReq=[Math]::Max(4.0,[double]$fullBase.GamingWorstP95*0.08)
        $downloadRegression=[double]$fullCap.DownloadP95 -gt ([double]$fullBase.DownloadP95+5.0);$idleRegression=[double]$fullCap.QuietP95 -gt ([double]$fullBase.QuietP95+5.0);$lossRegression=[double]$fullCap.GamingLoss -gt ([double]$fullBase.GamingLoss+0.5)
        $pass=[bool]($fullCap.Graded -and $fullP95Gain -ge $fullReq -and -not $downloadRegression -and -not $idleRegression -and -not $lossRegression)
        if(-not $pass){return ("BUFFERBLOAT / GAMING P95 REDUCER`r`nFINAL ROLLBACK - Windows shaping did not survive the gaming P95 gate.`r`nWorst P95 uncapped: {0:N1} ms -> capped: {1:N1} ms (gain {2:N1}, required {3:N1}).`r`nDownload P95: {4:N1} -> {5:N1} ms.`r`nFOCS left the PC uncapped." -f $fullBase.GamingWorstP95,$fullCap.GamingWorstP95,$fullP95Gain,$fullReq,$fullBase.DownloadP95,$fullCap.DownloadP95)}
        $finalGuard=Set-FocsBufferbloatUploadGuard -UploadMbps $UploadMbps -Percent ([double]$best.Percent);$keep=$true;$committed=$true
        $save=[pscustomobject]@{Measured=(Get-Date).ToString('o');Adapter=$AdapterName;EnteredUploadMbps=$UploadMbps;Baseline=$baselineStart;BaselineRecheck=$baselineEnd;Candidates=$results.ToArray();SelectedPercent=$best.Percent;SelectedCapMbps=$finalGuard.CapMbps;FullBaseline=$fullBase;FullCapped=$fullCap;TemporaryUntilReboot=$true}
        $save|ConvertTo-Json -Depth 14|Set-Content -LiteralPath $profilePath -Encoding UTF8
        $lines=[System.Collections.Generic.List[string]]::new();$lines.Add('BUFFERBLOAT / GAMING P95 REDUCER COMPLETE');$lines.Add(('Upload P95 screening baseline: {0:N1} ms' -f $baselineP95));foreach($r in $results.ToArray()|Sort-Object Percent -Descending){$lines.Add(('Cap {0:N0}% ({1:N1} Mbps): upload P95 {2:N1} ms | state {3} | loss {4:N1}% | generated {5:N1} Mbps' -f $r.Percent,$r.CapMbps,$r.Measurement.UploadP95,$r.Measurement.GamingState,$r.Measurement.UploadLoss,$r.Measurement.LoadMbps))};$lines.Add(('FULL A/B worst P95: {0:N1} -> {1:N1} ms | gain {2:N1} ms' -f $fullBase.GamingWorstP95,$fullCap.GamingWorstP95,$fullP95Gain));$lines.Add(('TEMPORARILY KEPT: {0:N1} Mbps ({1:N0}%). ActiveStore only; reboot removes it.' -f $finalGuard.CapMbps,$best.Percent));$lines.Add('If an external Waveform test still flags Low Latency Gaming, use RESTORE UNCAPPED NOW. That means the remaining tail latency is not being fixed by Windows outbound shaping and router-side SQM is the next step.');return ($lines -join "`r`n")
    }catch{if(-not $committed){try{[void](Remove-FocsBufferbloatUploadGuard)}catch{}};throw}
}

function Invoke-FocsLowLatencyGamingTest {
    param([string]$AdapterName,[string]$CustomTarget,[double]$ExpectedUploadMbps=0,[System.Windows.Forms.TextBox]$OutputBox)
    if(-not $AdapterName){throw 'Choose a network adapter first.'}
    $gw=Get-FocsDefaultGateway;Set-FocsOutputText $OutputBox 'LOW LATENCY GAMING HEALTH`r`nMeasuring idle P95 to multiple paths...'
    $cf=Test-NetworkLatency -HostName '1.1.1.1' -Count 30 -TimeoutMs 1500;$gg=Test-NetworkLatency -HostName '8.8.8.8' -Count 24 -TimeoutMs 1500;$gwi=if($gw){Test-NetworkLatency -HostName $gw -Count 24 -TimeoutMs 1000}else{$null};$custom=$null
    if(-not [string]::IsNullOrWhiteSpace($CustomTarget)){try{$custom=Test-NetworkLatency -HostName $CustomTarget.Trim() -Count 24 -TimeoutMs 1800}catch{Write-KLog "Custom gaming target failed: $($_.Exception.Message)"}}
    $down=Invoke-FocsLoadedLatencyPhase -Direction Download -Target '1.1.1.1' -Gateway $gw -QuietMedianMs ([double]$cf.Median) -Count 35 -GatewayCount 15 -ExpectedMbps 0 -Stage 'Gaming health: download-loaded P95' -OutputBox $OutputBox
    $up=Invoke-FocsLoadedLatencyPhase -Direction Upload -Target '1.1.1.1' -Gateway $gw -QuietMedianMs ([double]$cf.Median) -Count 35 -GatewayCount 15 -ExpectedMbps $ExpectedUploadMbps -Stage 'Gaming health: upload-loaded P95' -OutputBox $OutputBox
    $idleVals=[System.Collections.Generic.List[double]]::new();$idleVals.Add([double]$cf.P95);$idleVals.Add([double]$gg.P95);if($custom){$idleVals.Add([double]$custom.P95)};$idleWorst=[double](($idleVals.ToArray()|Measure-Object -Maximum).Maximum)
    $worst=[Math]::Max($idleWorst,[Math]::Max([double]$down.Loaded.P95,[double]$up.Loaded.P95));$loss=[Math]::Max([double]$cf.LossPct,[Math]::Max([double]$down.Loaded.LossPct,[double]$up.Loaded.LossPct));$state=if($down.LoadOk -and $up.LoadOk){Get-FocsGamingLatencyState -P95 $worst -LossPct $loss}else{'UNKNOWN'}
    $gwWorst=if($gwi -and $down.LoadedGateway -and $up.LoadedGateway){[Math]::Max([double]$gwi.P95,[Math]::Max([double]$down.LoadedGateway.P95,[double]$up.LoadedGateway.P95))}else{$null}
    $diag='No obvious tail-latency problem detected.'
    if($null -ne $gwWorst -and $gwWorst -ge 40){$diag='First-hop P95 is high: focus on the PC/NIC/cable/Wi-Fi/router LAN side before changing WAN settings.'}
    elseif($idleWorst -ge 40){$diag='Idle public/game-path P95 is already high while the gateway is cleaner: likely WAN/ISP/routing distance or a route-specific issue.'}
    elseif([double]$down.Loaded.P95 -ge 40 -or [double]$up.Loaded.P95 -ge 40){$dir=if([double]$up.Loaded.P95 -gt [double]$down.Loaded.P95){'upload'}else{'download'};$diag=("Loaded P95 crosses 40 ms mainly on {0}: queueing/bufferbloat is the likely cause. Router SQM is the preferred fix." -f $dir)}
    if($custom -and [double]$custom.P95 -ge 40 -and [double]$cf.P95 -lt 40 -and [double]$gg.P95 -lt 40){$diag='Public paths look clean but the custom game target P95 is high: this points more toward game-route/peering/server-path latency than the NIC.'}
    $lines=[System.Collections.Generic.List[string]]::new();$lines.Add('LOW LATENCY GAMING HEALTH');$lines.Add(('Overall: {0} | worst measured P95 {1:N1} ms | target < 40 ms' -f $state,$worst));$lines.Add(('Idle P95: Cloudflare {0:N1} ms | Google {1:N1} ms{2}' -f $cf.P95,$gg.P95,$(if($custom){(' | custom '+$custom.P95.ToString('N1')+' ms')}else{''})));$lines.Add(('Loaded P95: download {0:N1} ms | upload {1:N1} ms' -f $down.Loaded.P95,$up.Loaded.P95));if($null -ne $gwWorst){$lines.Add(('Gateway worst P95 across idle/load: {0:N1} ms' -f $gwWorst))};$lines.Add(('Packet loss worst: {0:N1}%' -f $loss));$lines.Add('PASS means all measured P95 values stayed below 40 ms. WARN is 40-60 ms; FAIL is 60+ ms or meaningful loss. WARN is a FOCS diagnostic band, not a Waveform category.');$lines.Add('Diagnosis: '+$diag);$lines.Add('ICMP can be deprioritised by some networks, so use this together with the game itself and an external loaded-latency test.');$result=[pscustomobject]@{Measured=(Get-Date).ToString('o');Adapter=$AdapterName;State=$state;WorstP95=$worst;IdleCloudflareP95=$cf.P95;IdleGoogleP95=$gg.P95;CustomP95=if($custom){$custom.P95}else{$null};DownloadP95=$down.Loaded.P95;UploadP95=$up.Loaded.P95;GatewayWorstP95=$gwWorst;Loss=$loss;Diagnosis=$diag};$dir=Join-Path $script:DataRoot 'NetworkLab';New-Item -ItemType Directory -Path $dir -Force|Out-Null;$result|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $dir ('gaming_latency_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.json')) -Encoding UTF8;return ($lines -join "`r`n")
}

function Ensure-FocsDisplayType {
    if('FocsDisplayNative' -as [type]){return}
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class FocsDisplayNative {
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct DEVMODE {
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string dmDeviceName; public short dmSpecVersion,dmDriverVersion,dmSize,dmDriverExtra; public int dmFields,dmPositionX,dmPositionY,dmDisplayOrientation,dmDisplayFixedOutput; public short dmColor,dmDuplex,dmYResolution,dmTTOption,dmCollate; [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string dmFormName; public short dmLogPixels; public int dmBitsPerPel,dmPelsWidth,dmPelsHeight,dmDisplayFlags,dmDisplayFrequency,dmICMMethod,dmICMIntent,dmMediaType,dmDitherType,dmReserved1,dmReserved2,dmPanningWidth,dmPanningHeight;
  }
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern bool EnumDisplaySettings(string deviceName,int modeNum,ref DEVMODE devMode);
  public static string Describe(string deviceName){var d=new DEVMODE();d.dmSize=(short)Marshal.SizeOf(typeof(DEVMODE));if(EnumDisplaySettings(deviceName,-1,ref d))return d.dmDisplayFrequency>1 ? String.Format("{0} x {1} @ {2} Hz",d.dmPelsWidth,d.dmPelsHeight,d.dmDisplayFrequency) : String.Format("{0} x {1} @ driver-default refresh",d.dmPelsWidth,d.dmPelsHeight);return "unknown";}
}
'@
}

function Get-FocsDisplayGraphicsReport {
    Ensure-FocsDisplayType
    $lines=[System.Collections.Generic.List[string]]::new();$lines.Add('DISPLAY & GRAPHICS INSPECTOR')
    foreach($s in [System.Windows.Forms.Screen]::AllScreens){$lines.Add(("{0}: {1} | Primary={2}" -f $s.DeviceName,[FocsDisplayNative]::Describe($s.DeviceName),$s.Primary))}
    $sys=Get-SystemSummary;$lines.Add("HAGS: $($sys.HAGS)")
    $gm='Unknown';try{$gm=(Get-ItemProperty 'HKCU:\Software\Microsoft\GameBar' -Name AutoGameModeEnabled -ErrorAction Stop).AutoGameModeEnabled}catch{};$lines.Add("Game Mode registry state: $gm")
    $dx='';try{$dx=[string](Get-ItemProperty 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' -Name DirectXUserGlobalSettings -ErrorAction Stop).DirectXUserGlobalSettings}catch{}
    function kv([string]$k){$m=[regex]::Match($dx,'(?:^|;)'+[regex]::Escape($k)+'=([^;]+)');if($m.Success){return $m.Groups[1].Value};return 'Default/not explicitly set'}
    $lines.Add("Windows VRR optimization registry hint: $(kv 'VRROptimizeEnable')")
    $lines.Add("Windowed-game swap-effect optimization registry hint: $(kv 'SwapEffectUpgradeEnable')")
    $lines.Add("Auto HDR setting: $(kv 'AutoHDREnable')")
    $lines.Add('VRR setting does not prove G-SYNC/FreeSync is actively engaged in a specific game; driver, monitor and presentation mode also matter.')
    return ($lines -join "`r`n")
}

function Ensure-FocsRawMouseType {
    if('FocsRawMouse' -as [type]){return}
    Add-Type -ReferencedAssemblies @('System.Windows.Forms.dll','System.Drawing.dll') -TypeDefinition @'
using System; using System.Collections.Generic; using System.Diagnostics; using System.Runtime.InteropServices; using System.Windows.Forms;
public class FocsRawMouse : Form {
 [StructLayout(LayoutKind.Sequential)] struct RAWINPUTDEVICE { public ushort usUsagePage,usUsage; public uint dwFlags; public IntPtr hwndTarget; }
 [StructLayout(LayoutKind.Sequential)] struct RAWINPUTHEADER { public uint dwType,dwSize; public IntPtr hDevice,wParam; }
 [DllImport("user32.dll",SetLastError=true)] static extern bool RegisterRawInputDevices(RAWINPUTDEVICE[] d,uint n,uint size);
 [DllImport("user32.dll")] static extern uint GetRawInputData(IntPtr h,uint cmd,IntPtr data,ref uint size,uint hdr);
 const int WM_INPUT=0x00FF; const uint RID_HEADER=0x10000005; const uint RIDEV_INPUTSINK=0x00000100;
 List<long> ticks=new List<long>(); Timer timer=new Timer();
 public FocsRawMouse(int ms){ShowInTaskbar=false;Opacity=0.01;Width=1;Height=1;Left=-32000;Top=-32000;var r=new RAWINPUTDEVICE[]{new RAWINPUTDEVICE{usUsagePage=1,usUsage=2,dwFlags=RIDEV_INPUTSINK,hwndTarget=this.Handle}};RegisterRawInputDevices(r,1,(uint)Marshal.SizeOf(typeof(RAWINPUTDEVICE)));timer.Interval=ms;timer.Tick+=(s,e)=>{timer.Stop();Close();};timer.Start();}
 protected override void WndProc(ref Message m){if(m.Msg==WM_INPUT){uint sz=(uint)Marshal.SizeOf(typeof(RAWINPUTHEADER));IntPtr p=Marshal.AllocHGlobal((int)sz);try{uint got=GetRawInputData(m.LParam,RID_HEADER,p,ref sz,(uint)Marshal.SizeOf(typeof(RAWINPUTHEADER)));if(got>0){var h=(RAWINPUTHEADER)Marshal.PtrToStructure(p,typeof(RAWINPUTHEADER));if(h.dwType==0)ticks.Add(Stopwatch.GetTimestamp());}}finally{Marshal.FreeHGlobal(p);}}base.WndProc(ref m);}
 public static double[] Measure(int ms){using(var f=new FocsRawMouse(ms)){Application.Run(f);if(f.ticks.Count<2)return new double[0];var a=new double[f.ticks.Count-1];double freq=Stopwatch.Frequency;for(int i=1;i<f.ticks.Count;i++)a[i-1]=(f.ticks[i]-f.ticks[i-1])*1000.0/freq;return a;}}
}
'@
}

function Invoke-FocsMousePollingTest {
    param([int]$Seconds=5)
    Ensure-FocsRawMouseType
    $intervals=[FocsRawMouse]::Measure($Seconds*1000)
    if(-not $intervals -or $intervals.Count -lt 10){return 'Too few raw mouse events. Move the mouse continuously and quickly during the measurement.'}
    $median=Get-FocsMedianNumber $intervals;$p95=Get-Percentile $intervals 95;$hz=if($median -gt 0){1000.0/$median}else{0};$meanHz=if((($intervals|Measure-Object -Sum).Sum) -gt 0){1000.0*$intervals.Count/(($intervals|Measure-Object -Sum).Sum)}else{0}
    return ('RAW INPUT MOUSE POLLING`r`nEvents: {0}`r`nEstimated rate from median interval: {1:N0} Hz`r`nAverage event rate: {2:N0} Hz`r`nMedian interval: {3:N3} ms`r`nP95 interval: {4:N3} ms`r`nMove the mouse continuously during the test. This measures WM_INPUT arrival cadence, not click-to-photon latency.' -f ($intervals.Count+1),$hz,$meanHz,$median,$p95)
}

function Get-FocsCompatibilityReport {
    param([hashtable]$Controls,[string]$AdapterName)
    $s=Get-SystemSummary;$lines=[System.Collections.Generic.List[string]]::new();$lines.Add('FOCS COMPATIBILITY / CHANGE PREVIEW');$lines.Add("Windows build: $($s.Build) | GPU: $($s.GPU) | Driver: $($s.Driver)")
    $lines.Add("PresentMon: $(if(Find-PresentMon){'ready'}else{'not ready'}) | LibreHardwareMonitor: $(if(Get-FocsLhmDll){'ready'}else{'not ready'}) | WPT/xperf: $(if(Get-FocsXperf){'ready'}else{'optional / not installed'})")
    if($AdapterName){$p=@(Get-NetAdapterAdvancedProperty -Name $AdapterName -ErrorAction SilentlyContinue);$rss=Get-NetAdapterRss -Name $AdapterName -ErrorAction SilentlyContinue;$rsc=Get-NetAdapterRsc -Name $AdapterName -ErrorAction SilentlyContinue;$lines.Add("NIC: $AdapterName | advanced properties: $($p.Count) | RSS supported: $([bool]$rss) | RSC exposed: $([bool]$rsc)")}
    $lines.Add('');$lines.Add('SELECTED WINDOWS CHANGES (current -> proposed)')
    if($Controls){
        if($Controls.GameMode.Checked){$cur='not set';try{$cur=(Get-ItemProperty 'HKCU:\Software\Microsoft\GameBar' -Name AutoGameModeEnabled -ErrorAction Stop).AutoGameModeEnabled}catch{};$lines.Add("Game Mode: $cur -> 1; Game DVR capture -> Off")}
        if($Controls.Mouse.Checked){$cur='not set';try{$cur=(Get-ItemProperty 'HKCU:\Control Panel\Mouse' -Name MouseSpeed -ErrorAction Stop).MouseSpeed}catch{};$lines.Add("Pointer acceleration MouseSpeed: $cur -> 0")}
        if($Controls.Delivery.Checked){$cur='default';try{$cur=(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config' -Name DODownloadMode -ErrorAction Stop).DODownloadMode}catch{};$lines.Add("Delivery Optimization P2P mode: $cur -> 0")}
        if($Controls.Hags.Checked){$lines.Add("HAGS: $($s.HAGS) -> On request (reboot + benchmark required)")}
    }
    $lines.Add('');$lines.Add('Rules: unsupported NIC values are never invented; experimental graphics/network changes require measurement; security services remain untouched.')
    return ($lines -join "`r`n")
}

function Get-FocsGameExeCandidatesFromFolder {
    param([string]$Folder,[string]$GameName,[string]$Source='Folder scan',[int]$Max=3)
    if([string]::IsNullOrWhiteSpace($Folder) -or -not(Test-Path -LiteralPath $Folder)){return @()}
    $excludeName='(?i)(unins|uninstall|crash|report|launcher|bootstrap|easyanticheat|anticheat|battleye|cef|webview|redist|setup|updater|helper|overlay|prereq|vc_redist|dxsetup)'
    $excludePath='(?i)(\\_CommonRedist\\|\\Redistribut|\\EasyAntiCheat\\|\\BattlEye\\|\\Installer\\|\\Prereq|\\Engine\\Binaries\\ThirdParty\\)'
    $normGame=([regex]::Replace(([string]$GameName).ToLowerInvariant(),'[^a-z0-9]',''))
    $rows=[System.Collections.Generic.List[object]]::new()
    try{
        foreach($f in @(Get-ChildItem -LiteralPath $Folder -Filter '*.exe' -File -Recurse -ErrorAction SilentlyContinue)){
            if($f.Name -match $excludeName -or $f.FullName -match $excludePath){continue}
            $base=[IO.Path]::GetFileNameWithoutExtension($f.Name)
            $normExe=[regex]::Replace($base.ToLowerInvariant(),'[^a-z0-9]','')
            $score=0
            if($normGame -and ($normExe -eq $normGame -or $normGame.Contains($normExe) -or $normExe.Contains($normGame))){$score+=180}
            if($f.FullName -match '(?i)\\(win64|x64|binaries|game\\bin)\\'){$score+=45}
            if($f.Length -ge 50000000){$score+=35}elseif($f.Length -ge 5000000){$score+=20}elseif($f.Length -ge 1000000){$score+=8}
            if($base -match '(?i)^(game|client|shipping|win64|x64)$'){$score+=10}
            $rows.Add([pscustomobject]@{Name=if($GameName){$GameName}else{$base};Exe=$f.Name;Path=$f.FullName;Source=$Source;Score=$score})
        }
    }catch{}
    return @($rows | Sort-Object @{Expression={$_.Score};Descending=$true},@{Expression={$_.Path.Length};Descending=$false} | Select-Object -First $Max)
}

function Get-FocsInstalledGames {
    $list=[System.Collections.Generic.List[object]]::new()
    $seen=@{}
    $add={
        param([string]$Name,[string]$Path,[string]$Source)
        if([string]::IsNullOrWhiteSpace($Path)){return}
        try{$Path=[Environment]::ExpandEnvironmentVariables($Path.Trim().Trim('"'))}catch{}
        if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return}
        if([IO.Path]::GetExtension($Path) -ine '.exe'){return}
        $key=$Path.ToLowerInvariant()
        if($seen.ContainsKey($key)){return}
        $seen[$key]=$true
        if([string]::IsNullOrWhiteSpace($Name)){
            try{$vi=[Diagnostics.FileVersionInfo]::GetVersionInfo($Path);$Name=if($vi.ProductName){$vi.ProductName}else{[IO.Path]::GetFileNameWithoutExtension($Path)}}catch{$Name=[IO.Path]::GetFileNameWithoutExtension($Path)}
        }
        $list.Add([pscustomobject]@{Name=$Name;Exe=[IO.Path]::GetFileName($Path);Path=$Path;Source=$Source})
    }

    # 1) Windows' own game-detection database. Stale entries are ignored unless the EXE still exists.
    try{
        $gc='HKCU:\System\GameConfigStore\Children'
        if(Test-Path $gc){
            foreach($k in @(Get-ChildItem $gc -ErrorAction SilentlyContinue)){
                try{
                    $p=Get-ItemProperty $k.PSPath -ErrorAction Stop
                    $path=[string]$p.MatchedExeFullPath
                    if($path -and (Test-Path -LiteralPath $path -PathType Leaf)){
                        $nm=$null
                        try{$vi=[Diagnostics.FileVersionInfo]::GetVersionInfo($path);$nm=[string]$vi.ProductName}catch{}
                        if(-not $nm){$nm=[IO.Path]::GetFileNameWithoutExtension($path)}
                        & $add $nm $path 'Windows GameConfigStore'
                    }
                }catch{}
            }
        }
    }catch{}

    # 2) Steam libraries + appmanifest files. This finds CS2 even before Windows has a fresh GameConfigStore entry.
    $steamRoots=[System.Collections.Generic.List[string]]::new()
    foreach($rk in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')){
        try{$r=Get-ItemProperty $rk -ErrorAction Stop;$sp=[string]$(if($r.SteamPath){$r.SteamPath}elseif($r.InstallPath){$r.InstallPath}else{$null});if($sp -and (Test-Path $sp) -and -not $steamRoots.Contains($sp)){$steamRoots.Add($sp)}}catch{}
    }
    foreach($steam in @($steamRoots.ToArray())){
        $libs=[System.Collections.Generic.List[string]]::new();$libs.Add($steam)
        foreach($vdf in @((Join-Path $steam 'steamapps\libraryfolders.vdf'),(Join-Path $steam 'config\libraryfolders.vdf'))){
            if(Test-Path -LiteralPath $vdf){
                try{
                    $raw=Get-Content -LiteralPath $vdf -Raw -ErrorAction Stop
                    foreach($m in [regex]::Matches($raw,'(?im)^\s*"path"\s+"([^"]+)"')){$p=$m.Groups[1].Value -replace '\\\\','\';if($p -and (Test-Path $p) -and -not $libs.Contains($p)){$libs.Add($p)}}
                    foreach($m in [regex]::Matches($raw,'(?im)^\s*"\d+"\s+"([A-Za-z]:\\[^"]+)"')){$p=$m.Groups[1].Value -replace '\\\\','\';if($p -and (Test-Path $p) -and -not $libs.Contains($p)){$libs.Add($p)}}
                }catch{}
            }
        }
        foreach($lib in @($libs.ToArray())){
            $apps=Join-Path $lib 'steamapps'
            foreach($mf in @(Get-ChildItem -LiteralPath $apps -Filter 'appmanifest_*.acf' -File -ErrorAction SilentlyContinue)){
                try{
                    $raw=Get-Content -LiteralPath $mf.FullName -Raw -ErrorAction Stop
                    $mn=[regex]::Match($raw,'(?im)^\s*"name"\s+"([^"]+)"');$mi=[regex]::Match($raw,'(?im)^\s*"installdir"\s+"([^"]+)"')
                    if(-not $mi.Success){continue}
                    $name=if($mn.Success){$mn.Groups[1].Value}else{$mi.Groups[1].Value}
                    $folder=Join-Path (Join-Path $apps 'common') $mi.Groups[1].Value
                    foreach($c in @(Get-FocsGameExeCandidatesFromFolder -Folder $folder -GameName $name -Source 'Steam' -Max 3)){& $add $c.Name $c.Path $c.Source}
                }catch{}
            }
        }
    }

    # 3) Epic Games Launcher manifest files expose the install path and launch executable directly.
    $epicMan=Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
    if(Test-Path -LiteralPath $epicMan){
        foreach($mf in @(Get-ChildItem -LiteralPath $epicMan -Filter '*.item' -File -ErrorAction SilentlyContinue)){
            try{
                $j=Get-Content -LiteralPath $mf.FullName -Raw -ErrorAction Stop|ConvertFrom-Json
                $name=[string]$j.DisplayName;$root=[string]$j.InstallLocation;$rel=[string]$j.LaunchExecutable
                if($root -and $rel){$p=Join-Path $root ($rel -replace '/','\');& $add $name $p 'Epic Games'}
                elseif($root){foreach($c in @(Get-FocsGameExeCandidatesFromFolder -Folder $root -GameName $name -Source 'Epic Games' -Max 2)){& $add $c.Name $c.Path $c.Source}}
            }catch{}
        }
    }

    # 4) GOG registry metadata.
    foreach($root in @('HKLM:\SOFTWARE\GOG.com\Games','HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games')){
        if(Test-Path $root){
            foreach($k in @(Get-ChildItem $root -ErrorAction SilentlyContinue)){
                try{
                    $p=Get-ItemProperty $k.PSPath -ErrorAction Stop;$folder=[string]$p.PATH;$name=[string]$p.gameName
                    if(-not $name){$name=[string]$p.GAMENAME};if(-not $name){$name=$k.PSChildName}
                    $exe=[string]$p.EXE;if($exe -and $folder){$candidate=if([IO.Path]::IsPathRooted($exe)){$exe}else{Join-Path $folder $exe};& $add $name $candidate 'GOG'}
                    if($folder){foreach($c in @(Get-FocsGameExeCandidatesFromFolder -Folder $folder -GameName $name -Source 'GOG' -Max 2)){& $add $c.Name $c.Path $c.Source}}
                }catch{}
            }
        }
    }

    # 5) Ubisoft Connect install registry.
    foreach($root in @('HKLM:\SOFTWARE\WOW6432Node\Ubisoft\Launcher\Installs','HKLM:\SOFTWARE\Ubisoft\Launcher\Installs')){
        if(Test-Path $root){
            foreach($k in @(Get-ChildItem $root -ErrorAction SilentlyContinue)){
                try{$p=Get-ItemProperty $k.PSPath -ErrorAction Stop;$folder=[string]$p.InstallDir;if($folder){foreach($c in @(Get-FocsGameExeCandidatesFromFolder -Folder $folder -GameName $k.PSChildName -Source 'Ubisoft Connect' -Max 2)){& $add $c.Name $c.Path $c.Source}}}catch{}
            }
        }
    }

    # 6) Common modern library roots on every local fixed drive (Xbox app, Riot, EA, GOG).
    try{
        foreach($d in @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue)){
            foreach($rel in @('XboxGames','Riot Games','EA Games','GOG Games')){
                $root=Join-Path ([string]$d.DeviceID+'\') $rel
                if(-not(Test-Path -LiteralPath $root)){continue}
                foreach($dir in @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue)){
                    foreach($c in @(Get-FocsGameExeCandidatesFromFolder -Folder $dir.FullName -GameName $dir.Name -Source $rel -Max 2)){& $add $c.Name $c.Path $c.Source}
                }
            }
        }
    }catch{}

    return @($list.ToArray() | Sort-Object Name,Exe,Source)
}

function Get-FocsRunningGameCandidates {
    $list=[System.Collections.Generic.List[object]]::new();$seen=@{}
    $exclude='(?i)^(explorer|dwm|taskmgr|powershell|pwsh|cmd|conhost|chrome|msedge|firefox|discord|spotify|steam|steamwebhelper|epicgameslauncher|riotclientservices|battle\.net|agent|obs64|nvcontainer|searchhost|startmenuexperiencehost)$'
    foreach($p in @(Get-Process -ErrorAction SilentlyContinue)){
        try{
            if([string]::IsNullOrWhiteSpace($p.MainWindowTitle)){continue}
            $path=[string]$p.Path;if(-not $path -or -not(Test-Path -LiteralPath $path)){continue}
            $base=[IO.Path]::GetFileNameWithoutExtension($path);if($base -match $exclude){continue}
            if($path -match '(?i)\\Windows\\(System32|SysWOW64)\\'){continue}
            $key=$path.ToLowerInvariant();if($seen.ContainsKey($key)){continue};$seen[$key]=$true
            $nm=$null;try{$vi=[Diagnostics.FileVersionInfo]::GetVersionInfo($path);$nm=[string]$vi.ProductName}catch{};if(-not $nm){$nm=$p.MainWindowTitle};if(-not $nm){$nm=$base}
            $list.Add([pscustomobject]@{Name=$nm;Exe=[IO.Path]::GetFileName($path);Path=$path;Source='Running process'})
        }catch{}
    }
    return @($list.ToArray()|Sort-Object Name)
}

function Resolve-FocsBenchmarkTarget {
    param([string]$ProcessText)
    if([string]::IsNullOrWhiteSpace($ProcessText)){throw 'Choose a detected game or enter a game executable first.'}
    $exe=[IO.Path]::GetFileName($ProcessText.Trim().Trim('"'));if(-not $exe.EndsWith('.exe',[StringComparison]::OrdinalIgnoreCase)){$exe+='.exe'}
    $base=[IO.Path]::GetFileNameWithoutExtension($exe);$procs=@(Get-Process -Name $base -ErrorAction SilentlyContinue)
    if($procs.Count -eq 0){throw "The selected game process '$exe' is not running. Start the game, enter a menu/match where it is rendering, then capture the benchmark."}
    $target=@($procs|Where-Object{$_.MainWindowHandle -ne 0}|Sort-Object StartTime -Descending|Select-Object -First 1)
    if(-not $target){$target=@($procs|Sort-Object CPU -Descending|Select-Object -First 1)}
    $p=$target[0];$path=$null;try{$path=[string]$p.Path}catch{}
    return [pscustomobject]@{Exe=$exe;BaseName=$base;Pid=[int]$p.Id;Path=$path;WindowTitle=[string]$p.MainWindowTitle}
}

function Resolve-FocsBenchmarkProcessName {
    param([string]$ProcessText)
    $t=Resolve-FocsBenchmarkTarget -ProcessText $ProcessText
    return [string]$t.Exe
}

function Start-KxttsGui {
    $system = Get-SystemSummary
    $script:Ui = @{}
    $script:FocsToolTip = New-Object System.Windows.Forms.ToolTip
    $script:FocsToolTip.InitialDelay = 250
    $script:FocsToolTip.ReshowDelay = 80
    $script:FocsToolTip.AutoPopDelay = 9000
    $script:FocsToolTip.ShowAlways = $true

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'FOCS Utility v9.5.0 - App Installer Build'
    $form.Size = New-Object System.Drawing.Size(1540,980)
    $form.MinimumSize = New-Object System.Drawing.Size(1320,850)
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.BackColor = [System.Drawing.Color]::FromArgb(10,5,18)
    $form.ForeColor = [System.Drawing.Color]::White
    $form.Font = New-Object System.Drawing.Font('Segoe UI',10)
    $form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
    $script:Ui.Form=$form
    Set-KRoundedRegion -Control $form -Radius 18
    Add-KDarkBorder -Control $form -Radius 18 -Width 3
    $form.Add_Resize({ param($sender,$e) try { Set-KRoundedRegion -Control $sender -Radius 18; $sender.Invalidate() } catch {} })

    if (-not ('KxttsNativeWindow' -as [type])) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class KxttsNativeWindow {
    [DllImport("user32.dll")] public static extern bool ReleaseCapture();
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hWnd, int Msg, IntPtr wParam, IntPtr lParam);
}
"@
    }

    $header = New-Object System.Windows.Forms.Panel
    $header.Location=New-Object System.Drawing.Point(0,0); $header.Size=New-Object System.Drawing.Size(1520,100)
    $header.Anchor='Top,Left,Right'; $header.BackColor=[System.Drawing.Color]::FromArgb(14,7,25)
    [void]$form.Controls.Add($header)
    Set-KRoundedRegion -Control $header -Radius 16
    $header.Add_Resize({ param($sender,$e) try { Set-KRoundedRegion -Control $sender -Radius 16 } catch {} })
    $brandBadge=New-Object System.Windows.Forms.Panel;$brandBadge.Location=New-Object System.Drawing.Point(28,24);$brandBadge.Size=New-Object System.Drawing.Size(82,48);$brandBadge.BackColor=[System.Drawing.Color]::FromArgb(79,38,133);[void]$header.Controls.Add($brandBadge);Set-KRoundedRegion -Control $brandBadge -Radius 11;Add-KDarkBorder -Control $brandBadge -Radius 11 -Width 1
    $badgeText=New-KLabel $brandBadge 'FOCS' 0 0 82 48;$badgeText.TextAlign='MiddleCenter';$badgeText.Font=New-Object System.Drawing.Font('Segoe UI Semibold',13,[System.Drawing.FontStyle]::Bold);$badgeText.ForeColor=[System.Drawing.Color]::White
    [void](New-KTitle $header 'FOCS Utility v9.5.0' 128 18 500 45 24)
    $sub=New-KLabel $header 'Gaming optimization, network tuning, debloat and diagnostics' 131 60 660 25;$sub.ForeColor=[System.Drawing.Color]::FromArgb(196,178,224)
    $tag=New-KLabel $header 'FPS   |   LATENCY   |   NETWORK   |   CLEAN WINDOWS' 850 52 500 26;$tag.Anchor='Top,Right';$tag.TextAlign='MiddleRight';$tag.ForeColor=[System.Drawing.Color]::FromArgb(181,162,211)

    $minBtn=New-KButton '_' 1374 10 42 30; $minBtn.Anchor='Top,Right'; $minBtn.BackColor=[System.Drawing.Color]::FromArgb(14,7,25); $minBtn.FlatAppearance.BorderColor=[System.Drawing.Color]::Black; [void]$header.Controls.Add($minBtn)
    $maxBtn=New-KButton '[]' 1420 10 42 30; $maxBtn.Anchor='Top,Right'; $maxBtn.BackColor=[System.Drawing.Color]::FromArgb(14,7,25); $maxBtn.FlatAppearance.BorderColor=[System.Drawing.Color]::Black; [void]$header.Controls.Add($maxBtn)
    $closeBtn=New-KButton 'X' 1466 10 42 30; $closeBtn.Anchor='Top,Right'; $closeBtn.BackColor=[System.Drawing.Color]::FromArgb(28,10,14); $closeBtn.FlatAppearance.MouseOverBackColor=[System.Drawing.Color]::FromArgb(90,20,28); [void]$header.Controls.Add($closeBtn)
    $minBtn.Add_Click({$form.WindowState=[System.Windows.Forms.FormWindowState]::Minimized})
    $maxBtn.Add_Click({if($form.WindowState -eq [System.Windows.Forms.FormWindowState]::Maximized){$form.WindowState=[System.Windows.Forms.FormWindowState]::Normal}else{$form.WindowState=[System.Windows.Forms.FormWindowState]::Maximized}})
    $closeBtn.Add_Click({$form.Close()})
    $dragWindow={param($sender,$e) if($e.Button -eq [System.Windows.Forms.MouseButtons]::Left){[void][KxttsNativeWindow]::ReleaseCapture();[void][KxttsNativeWindow]::SendMessage($form.Handle,0xA1,[IntPtr]2,[IntPtr]::Zero)}}
    $header.Add_MouseDown($dragWindow); $brand=$header.Controls | Where-Object {$_.Text -eq 'FOCS Utility'} | Select-Object -First 1; if($brand){$brand.Add_MouseDown($dragWindow)}

    $side=New-Object System.Windows.Forms.Panel;$side.Location=New-Object System.Drawing.Point(0,100);$side.Size=New-Object System.Drawing.Size(275,830);$side.Anchor='Top,Bottom,Left';$side.BackColor=[System.Drawing.Color]::FromArgb(16,8,28);[void]$form.Controls.Add($side)
    Set-KRoundedRegion -Control $side -Radius 16
    $side.Add_Resize({ param($sender,$e) try { Set-KRoundedRegion -Control $sender -Radius 16 } catch {} })
    $navHome=New-KNavButton $side 'HOME' 18
    $navTweaks=New-KNavButton $side 'WINDOWS TWEAKS' 70
    $navDebloat=New-KNavButton $side 'APP DEBLOAT' 122
    $navInstaller=New-KNavButton $side 'APP INSTALLER' 174
    $navNvidia=New-KNavButton $side 'NVIDIA / GAME PROFILE' 226
    $navNetwork=New-KNavButton $side 'NETWORK LAB' 278
    $navServices=New-KNavButton $side 'SERVICE MANAGER' 330
    $navRegistry=New-KNavButton $side 'REGISTRY / PRIVACY' 382
    $navBackup=New-KNavButton $side 'BACKUP & RESTORE' 434
    $navDiag=New-KNavButton $side 'DIAGNOSTICS' 486
    $navBench=New-KNavButton $side 'BENCHMARK 2.0' 538
    $navAbout=New-KNavButton $side 'ABOUT' 590
    $navButtons=@($navHome,$navTweaks,$navDebloat,$navInstaller,$navNvidia,$navNetwork,$navServices,$navRegistry,$navBackup,$navDiag,$navBench,$navAbout)
    Set-FocsTip $navHome 'Choose a preset and see the current system summary.'
    Set-FocsTip $navTweaks 'Core Windows gaming settings. These are the settings used by the Home presets.'
    Set-FocsTip $navDebloat 'Remove optional Microsoft apps and background software you do not use.'
    Set-FocsTip $navInstaller 'Install or update selected gaming and utility apps through exact WinGet package IDs.'
    Set-FocsTip $navNvidia 'Create per-game NVIDIA Profile Inspector settings instead of changing the global driver profile.'
    Set-FocsTip $navNetwork 'Measure packet loss, jitter and latency, then test NIC settings against your own connection.'
    Set-FocsTip $navServices 'Change only optional Windows services. Core networking, security and audio services are excluded.'
    Set-FocsTip $navRegistry 'Reversible privacy, UI and background-activity registry settings.'
    Set-FocsTip $navBackup 'Create or restore FOCS backups before/after tuning.'
    Set-FocsTip $navDiag 'Latency Doctor, display/graphics inspection, mouse raw-input polling and compatibility preview.'
    Set-FocsTip $navBench 'Multi-run PresentMon benchmark sets with noise-aware comparison and optional hardware telemetry.'
    Set-FocsTip $navAbout 'Shows what FOCS changes, what it avoids, and why.'

    $sysCard=New-KCard $side 14 650 238 150;$sysCard.Anchor='Left,Bottom';[void](New-KTitle $sysCard 'Your System' 14 10 205 30 11)
    $sysInfo=New-KLabel $sysCard ("Windows: $($system.OS)`r`nCPU: $($system.CPU)`r`nGPU: $($system.GPU)`r`nRAM: $($system.RAM) GB") 14 43 208 96;$sysInfo.ForeColor=[System.Drawing.Color]::FromArgb(213,197,236)

    $contentHost=New-Object System.Windows.Forms.Panel;$contentHost.Location=New-Object System.Drawing.Point(288,112);$contentHost.Size=New-Object System.Drawing.Size(890,795);$contentHost.Anchor='Top,Bottom,Left,Right';$contentHost.BackColor=[System.Drawing.Color]::FromArgb(10,5,18);[void]$form.Controls.Add($contentHost)
    Set-KRoundedRegion -Control $contentHost -Radius 16
    $contentHost.Add_Resize({ param($sender,$e) try { Set-KRoundedRegion -Control $sender -Radius 16 } catch {} })
    $right=New-Object System.Windows.Forms.Panel;$right.Location=New-Object System.Drawing.Point(1190,112);$right.Size=New-Object System.Drawing.Size(320,795);$right.Anchor='Top,Bottom,Right';$right.BackColor=[System.Drawing.Color]::FromArgb(10,5,18);[void]$form.Controls.Add($right)
    Set-KRoundedRegion -Control $right -Radius 16
    $right.Add_Resize({ param($sender,$e) try { Set-KRoundedRegion -Control $sender -Radius 16 } catch {} })

    $hwCard=New-KCard $right 0 0 318 200;[void](New-KTitle $hwCard 'Hardware & Driver' 14 10 280 30 12)
    $hwText=New-KLabel $hwCard ("$($system.GPU)`r`nDriver: $($system.Driver)`r`nHAGS: $($system.HAGS)`r`nBuild: $($system.Build)") 14 48 286 105;$hwText.ForeColor=[System.Drawing.Color]::FromArgb(222,207,243)
    $driverBtn=New-KButton 'OPEN NVIDIA DRIVER PAGE' 14 153 286 34;[void]$hwCard.Controls.Add($driverBtn);$driverBtn.Add_Click({try{Start-Process 'https://www.nvidia.com/Download/index.aspx'}catch{}})
    $powerCard=New-KCard $right 0 214 318 150;[void](New-KTitle $powerCard 'Windows Power Plan' 14 10 280 28 11);$powerText=New-KLabel $powerCard (Get-PowerSchemeName) 14 40 286 38;$powerText.ForeColor=[System.Drawing.Color]::FromArgb(111,235,185)
    $powerTuneBtn=New-KButton 'AUTO-TUNE POWER PLAN' 14 92 286 40;$powerTuneBtn.BackColor=[System.Drawing.Color]::FromArgb(104,56,184);[void]$powerCard.Controls.Add($powerTuneBtn);Set-FocsTip $powerTuneBtn 'Tests your current, Balanced/High Performance and FOCS CPU-aware candidates locally. It keeps the lowest measured CPU-burst + wake-latency result and saves a backup first.'
    $netCard=New-KCard $right 0 378 318 125;[void](New-KTitle $netCard 'Network Status' 14 10 280 28 11);$netSummary=New-KLabel $netCard (Get-PrimaryNetworkSummary) 14 43 286 68;$netSummary.ForeColor=[System.Drawing.Color]::FromArgb(214,185,255)
    $toolCard=New-KCard $right 0 517 318 260;[void](New-KTitle $toolCard 'Managed Tools' 14 10 280 28 11)
    $script:ToolStatusLabels.PresentMon=New-KLabel $toolCard 'PresentMon: checking...' 14 48 286 28
    $script:ToolStatusLabels.NPI=New-KLabel $toolCard 'NVIDIA Profile Inspector: checking...' 14 78 286 28
    $script:ToolStatusLabels.LatencyMon=New-KLabel $toolCard 'LatencyMon: checking...' 14 108 286 32
    $script:ToolStatusLabels.LHM=New-KLabel $toolCard 'Hardware telemetry: checking...' 14 140 286 32
    foreach($k in $script:ToolStatusLabels.Keys){$script:ToolStatusLabels[$k].ForeColor=[System.Drawing.Color]::FromArgb(205,188,230)}
    $updateMini=New-KButton 'CHECK / UPDATE TOOLS' 14 204 286 38;[void]$toolCard.Controls.Add($updateMini)

    $pages=@{}
    foreach($name in @('Home','Tweaks','Debloat','Installer','Nvidia','Network','Services','Registry','Backup','Diagnostics','Bench','About')){$p=New-Object System.Windows.Forms.Panel;$p.Dock='Fill';$p.AutoScroll=$true;$p.BackColor=[System.Drawing.Color]::FromArgb(10,5,18);$p.Visible=$false;[void]$contentHost.Controls.Add($p);$pages[$name]=$p}
    $script:Ui.Pages=$pages;$script:Ui.NavButtons=$navButtons

    # TWEAK OPTIONS first so profile handlers always have live controls.
    $tw=$pages.Tweaks;[void](New-KTitle $tw 'Windows Gaming Tweaks' 12 6 500 36 16);[void](New-KLabel $tw 'Each option is visible and reversible. Hover an option to see what it changes.' 12 43 820 28)
    $controls=@{};$script:Ui.Controls=$controls
    $safeCard=New-KCard $tw 10 80 860 340;[void](New-KTitle $safeCard 'Gaming baseline' 14 10 400 28 12)
    $controls.GameMode=New-KCheck $safeCard 'Enable Game Mode + disable Game DVR background capture' 18 52 $true
    $controls.Mouse=New-KCheck $safeCard 'Disable Windows pointer acceleration' 18 94 $true
    $controls.Delivery=New-KCheck $safeCard 'Disable Delivery Optimization peer-to-peer downloads' 18 136 $true
    $controls.Network=New-KCheck $safeCard 'Repair TCP baseline: Normal Auto-Tuning + RSS + DNS flush' 18 178 $false
    $controls.Hags=New-KCheck $safeCard 'Enable HAGS request (experimental; reboot + A/B test)' 18 220 $false
    $controls.PcLatency=New-KCheck $safeCard 'Enable PresentMon beta PC-latency instrumentation when supported' 18 262 $false
    Set-FocsTip $controls.GameMode 'Enables Windows Game Mode and disables Game DVR background capture to reduce unnecessary recording activity.'
    Set-FocsTip $controls.Mouse 'Disables Windows pointer acceleration so mouse movement follows the raw configured sensitivity more consistently.'
    Set-FocsTip $controls.Delivery 'Disables peer-to-peer Delivery Optimization downloads. Windows Update still works through Microsoft servers.'
    Set-FocsTip $controls.Network 'Restores a conservative Windows TCP baseline: Auto-Tuning Normal, RSS Enabled, then flushes DNS cache.'
    Set-FocsTip $controls.Hags 'Requests Hardware-Accelerated GPU Scheduling. Results vary by GPU/driver, so benchmark before keeping it.'
    Set-FocsTip $controls.PcLatency 'Enables PresentMon PC-latency metrics when the game/instrumentation supports them.'
    $applySelected=New-KButton 'APPLY WINDOWS BASELINE' 18 300 250 34;$applySelected.BackColor=[System.Drawing.Color]::FromArgb(104,56,184);[void]$safeCard.Controls.Add($applySelected)
    $infoCard=New-KCard $tw 10 435 860 225;[void](New-KTitle $infoCard 'What is deliberately not automatic' 14 10 500 28 12)
    $tinfo=New-KLabel $infoCard "FOCS does not disable Defender/VBS/firewall, force HPET, set Realtime priority, blanket-force MSI mode, or apply every NIC offload hack. Those changes are either security-sensitive, hardware-specific, or commonly regress performance. Use the NVIDIA, Network and Registry pages for targeted changes and benchmark them." 18 50 815 145;$tinfo.ForeColor=[System.Drawing.Color]::FromArgb(220,204,240)

    # HOME + robust profile event wiring through sender.Tag and script-scoped UI state.
    $homePage=$pages.Home;[void](New-KTitle $homePage 'Select a Tweak Profile' 12 6 500 38 16);[void](New-KLabel $homePage 'Profiles now change the actual tweak controls immediately.' 12 42 760 25)
    $profilePanel=New-Object System.Windows.Forms.Panel;$profilePanel.Location=New-Object System.Drawing.Point(10,78);$profilePanel.Size=New-Object System.Drawing.Size(860,155);$profilePanel.BackColor=$homePage.BackColor;[void]$homePage.Controls.Add($profilePanel)
    $profileButtons=@{};$script:Ui.ProfileButtons=$profileButtons
    $profiles=@(@{Name='Recommended';X=0;Text="RECOMMENDED`r`nBalanced baseline"},@{Name='Minimal';X=215;Text="MINIMAL`r`nOnly essentials"},@{Name='Competitive';X=430;Text="COMPETITIVE`r`nPerformance focus"},@{Name='Custom';X=645;Text="CUSTOM`r`nKeep your choices"})
    foreach($pr in $profiles){$b=New-KButton $pr.Text $pr.X 0 205 140;$b.Font=New-Object System.Drawing.Font('Segoe UI Semibold',11);$b.TextAlign='MiddleCenter';$b.Tag=$pr.Name;[void]$profilePanel.Controls.Add($b);$profileButtons[$pr.Name]=$b;$tipText=switch($pr.Name){'Recommended'{'Balanced Windows gaming baseline with reversible background-activity reductions.'};'Minimal'{'Only the lowest-risk core gaming changes.'};'Competitive'{'More aggressive Windows-side gaming choices; NVIDIA and network tuning remain explicit.'};default{'Keep your current manual selections and build your own configuration.'}};Set-FocsTip -Control $b -Text $tipText;$b.Add_Click({param($sender,$eventArgs)try{Set-KProfileSelection -Name ([string]$sender.Tag)}catch{Show-KMessage $_.Exception.Message 'Profile selection error' ([System.Windows.Forms.MessageBoxIcon]::Error)}})}
    $included=New-KCard $homePage 10 245 860 260;[void](New-KTitle $included 'Profile behavior' 14 10 820 30 13)
    $profileExplain=New-KLabel $included '' 18 50 820 175;$profileExplain.ForeColor=[System.Drawing.Color]::FromArgb(220,204,240);$script:Ui.ProfileExplain=$profileExplain
    $applyCard=New-KCard $homePage 10 520 860 82;$profileStatus=New-KLabel $applyCard 'Selected profile: Recommended' 14 14 520 25;$script:Ui.ProfileStatus=$profileStatus
    $applyProfile=New-KButton 'APPLY PROFILE' 610 16 230 48;$applyProfile.BackColor=[System.Drawing.Color]::FromArgb(104,56,184);$applyProfile.Font=New-Object System.Drawing.Font('Segoe UI Semibold',12);[void]$applyCard.Controls.Add($applyProfile)
    $logCard=New-KCard $homePage 10 617 860 160;[void](New-KTitle $logCard 'Recent Changes / Log' 14 8 400 28 11);$script:LogBox=New-Object System.Windows.Forms.TextBox;$script:LogBox.Multiline=$true;$script:LogBox.ReadOnly=$true;$script:LogBox.ScrollBars='Vertical';$script:LogBox.Location=New-Object System.Drawing.Point(14,40);$script:LogBox.Size=New-Object System.Drawing.Size(830,100);$script:LogBox.BackColor=[System.Drawing.Color]::FromArgb(13,7,23);$script:LogBox.BorderStyle=[System.Windows.Forms.BorderStyle]::FixedSingle;$script:LogBox.ForeColor=[System.Drawing.Color]::FromArgb(203,185,226);[void]$logCard.Controls.Add($script:LogBox)

    # APP DEBLOAT
    $dp=$pages.Debloat;[void](New-KTitle $dp 'App Debloat' 12 6 500 36 16);[void](New-KLabel $dp 'Remove only apps you do not use. Core Store/App Installer/WebView/Security components are intentionally not listed.' 12 43 840 40)
    $dcard=New-KCard $dp 10 95 860 560
    $debloatList=New-Object System.Windows.Forms.CheckedListBox;$debloatList.Location=New-Object System.Drawing.Point(18,20);$debloatList.Size=New-Object System.Drawing.Size(530,420);$debloatList.CheckOnClick=$true;$debloatList.BackColor=[System.Drawing.Color]::FromArgb(13,7,23);$debloatList.ForeColor=[System.Drawing.Color]::FromArgb(225,210,245);[void]$dcard.Controls.Add($debloatList)
    $debCatalog=Get-KDebloatCatalog;foreach($n in $debCatalog.Keys){[void]$debloatList.Items.Add($n,$false)};$script:Ui.DebloatList=$debloatList
    $debScope=New-Object System.Windows.Forms.ComboBox;$debScope.DropDownStyle='DropDownList';[void]$debScope.Items.Add('Current user');[void]$debScope.Items.Add('All users + deprovision');$debScope.SelectedIndex=0;$debScope.Location=New-Object System.Drawing.Point(575,20);$debScope.Size=New-Object System.Drawing.Size(250,28);[void]$dcard.Controls.Add($debScope)
    $removeApps=New-KButton 'REMOVE CHECKED APPS' 575 65 250 42;$removeApps.BackColor=[System.Drawing.Color]::FromArgb(104,56,184);[void]$dcard.Controls.Add($removeApps)
    $selectCommon=New-KButton 'SELECT COMMON BLOAT' 575 115 250 38;[void]$dcard.Controls.Add($selectCommon)
    $clearApps=New-KButton 'CLEAR SELECTION' 575 160 250 38;[void]$dcard.Controls.Add($clearApps)
    $odRemove=New-KButton 'UNINSTALL ONEDRIVE' 575 235 250 38;[void]$dcard.Controls.Add($odRemove)
    $odInstall=New-KButton 'REINSTALL ONEDRIVE' 575 280 250 38;[void]$dcard.Controls.Add($odInstall)
    $edgeRemove=New-KButton 'SUPPORTED EDGE UNINSTALL' 575 345 250 38;[void]$dcard.Controls.Add($edgeRemove)
    $dnote=New-KLabel $dcard "Edge: FOCS only calls the supported package-manager uninstall. It will not use force-delete tricks that can break WebView/system components.`r`n`r`nOneDrive: uninstall is separate because it is not just a normal AppX package. App removal inventory is written into the backup folder." 575 400 250 140;$dnote.ForeColor=[System.Drawing.Color]::FromArgb(237,194,120)
    Set-FocsTip $debloatList 'Check only apps you do not use. FOCS intentionally excludes Microsoft Store, App Installer, WebView2 and Windows Security.'
    Set-FocsTip $removeApps 'Removes the checked optional apps. An installed-app inventory is saved first.'
    Set-FocsTip $selectCommon 'Selects common optional consumer apps; review the list before removing anything.'
    Set-FocsTip $odRemove 'Runs the supported OneDrive uninstaller. Sync stops until OneDrive is reinstalled.'
    Set-FocsTip $edgeRemove 'Attempts only the supported package-manager Edge uninstall. FOCS does not force-delete Edge/WebView system files.'

    # APP INSTALLER
    $ip=$pages.Installer;[void](New-KTitle $ip 'Useful App Installer' 12 6 500 36 16);[void](New-KLabel $ip 'Install or update trusted catalog entries through exact WinGet package IDs. Review the selection before continuing.' 12 43 840 40)
    $icard=New-KCard $ip 10 95 860 560
    $appList=New-Object System.Windows.Forms.CheckedListBox;$appList.Location=New-Object System.Drawing.Point(18,20);$appList.Size=New-Object System.Drawing.Size(480,290);$appList.CheckOnClick=$true;$appList.BackColor=[System.Drawing.Color]::FromArgb(13,7,23);$appList.ForeColor=[System.Drawing.Color]::FromArgb(225,210,245);[void]$icard.Controls.Add($appList)
    $script:Ui.AppCatalog=@(Get-FocsAppCatalog)
    foreach($app in $script:Ui.AppCatalog){[void]$appList.Items.Add(("{0}  [{1}]" -f $app.Name,$app.PackageId),$false)}
    $appSelectAll=New-KButton 'SELECT ALL' 520 20 300 38;[void]$icard.Controls.Add($appSelectAll)
    $appClear=New-KButton 'CLEAR' 520 68 300 38;[void]$icard.Controls.Add($appClear)
    $appRefresh=New-KButton 'REFRESH STATUS' 520 116 300 38;[void]$icard.Controls.Add($appRefresh)
    $appInstall=New-KButton 'INSTALL / UPDATE SELECTED' 520 164 300 44;$appInstall.BackColor=[System.Drawing.Color]::FromArgb(104,56,184);[void]$icard.Controls.Add($appInstall)
    $appNote=New-KLabel $icard "Uses WinGet's community manifests and publisher-hosted installers. FOCS passes --exact, --silent, and non-interactive agreement flags. Chromium is the Hibbiki Chromium build; this is Chromium, not Google Chrome.`r`n`r`nThe installer continues to the next selected app if one package fails." 520 230 300 120;$appNote.ForeColor=[System.Drawing.Color]::FromArgb(237,194,120)
    $appOut=New-Object System.Windows.Forms.TextBox;$appOut.Multiline=$true;$appOut.ReadOnly=$true;$appOut.ScrollBars='Vertical';$appOut.Location=New-Object System.Drawing.Point(18,330);$appOut.Size=New-Object System.Drawing.Size(802,200);$appOut.BackColor=[System.Drawing.Color]::FromArgb(13,7,23);$appOut.BorderStyle=[System.Windows.Forms.BorderStyle]::FixedSingle;$appOut.ForeColor=[System.Drawing.Color]::FromArgb(203,185,226);$appOut.Text='Click REFRESH STATUS to query WinGet.';[void]$icard.Controls.Add($appOut)
    Set-FocsTip $appList 'Select one or more exact packages. Package IDs are fixed in the FOCS catalog and cannot be typed or injected.'
    Set-FocsTip $appRefresh 'Queries WinGet for installed and currently available versions without changing the system.'
    Set-FocsTip $appInstall 'Shows a final package list, then installs or upgrades each selected application through WinGet.'

    # NVIDIA
    $nv=$pages.Nvidia;[void](New-KTitle $nv 'NVIDIA Settings' 12 6 500 36 16);[void](New-KLabel $nv 'Per-game settings only. Reflex-capable games should use in-game Reflex instead of forcing driver Low Latency Mode.' 12 43 840 40)
    $nvTool=New-KCard $nv 10 95 860 120;[void](New-KTitle $nvTool 'NVIDIA Profile Inspector' 14 10 400 28 12);$nvStatus=New-KLabel $nvTool 'Tool status will update after the automatic check.' 14 48 600 28;$script:Ui.NvStatus=$nvStatus
    $openNpi=New-KButton 'OPEN NPI' 630 42 200 32;[void]$nvTool.Controls.Add($openNpi);$updateNpi=New-KButton 'INSTALL / UPDATE NPI' 630 78 200 32;[void]$nvTool.Controls.Add($updateNpi)
    $nvPreset=New-KCard $nv 10 230 860 425;[void](New-KTitle $nvPreset 'One-click + custom per-game profile' 14 10 500 28 12)
    [void](New-KLabel $nvPreset 'Target:' 18 55 75 25);$gameChoice=New-Object System.Windows.Forms.ComboBox;$gameChoice.DropDownStyle='DropDownList';foreach($g in @('Fortnite','CS2','Custom')){[void]$gameChoice.Items.Add($g)};$gameChoice.SelectedIndex=0;$gameChoice.Location=New-Object System.Drawing.Point(90,52);$gameChoice.Size=New-Object System.Drawing.Size(180,28);[void]$nvPreset.Controls.Add($gameChoice)
    $customExe=New-Object System.Windows.Forms.TextBox;$customExe.Text='game.exe';$customExe.Location=New-Object System.Drawing.Point(290,52);$customExe.Size=New-Object System.Drawing.Size(260,28);[void]$nvPreset.Controls.Add($customExe)
    $nvPower=New-KCheck $nvPreset 'Prefer Maximum Performance (per game)' 18 100 $true
    $nvRefresh=New-KCheck $nvPreset 'Preferred refresh rate: Highest available' 18 140 $true
    $nvTexture=New-KCheck $nvPreset 'Texture filtering: High Performance (image-quality tradeoff)' 18 180 $false
    $nvVsync=New-KCheck $nvPreset 'Force V-Sync Off (lowest latency; tearing possible)' 18 220 $false
    $nvPre=New-KCheck $nvPreset 'Maximum pre-rendered frames = 1 (non-Reflex games only)' 18 260 $false
    Set-FocsTip $nvPower 'Keeps the NVIDIA GPU in a higher performance state for this game profile. It can reduce clock-down latency but uses more power.'
    Set-FocsTip $nvRefresh 'Tells the NVIDIA profile to prefer the highest refresh rate available for the display/game.'
    Set-FocsTip $nvTexture 'Uses the driver High Performance texture-filtering quality preset. Small performance bias with an image-quality tradeoff.'
    Set-FocsTip $nvVsync 'Forces driver V-Sync off for this game profile. This can reduce latency but may allow tearing.'
    Set-FocsTip $nvPre 'Limits queued frames for older/non-Reflex games. Leave this off for games where NVIDIA Reflex controls the render queue.'
    $nvRec=New-KButton 'LOAD RECOMMENDED' 18 315 220 42;[void]$nvPreset.Controls.Add($nvRec)
    $nvComp=New-KButton 'LOAD COMPETITIVE' 255 315 220 42;$nvComp.BackColor=[System.Drawing.Color]::FromArgb(73,38,125);[void]$nvPreset.Controls.Add($nvComp)
    $nvApply=New-KButton 'APPLY SELECTED NPI SETTINGS' 492 315 330 42;$nvApply.BackColor=[System.Drawing.Color]::FromArgb(104,56,184);[void]$nvPreset.Controls.Add($nvApply)
    $nvInfo=New-KLabel $nvPreset 'Recommended = Max Performance + Highest Refresh. Competitive also selects High Performance texture filtering and V-Sync Off. Pre-rendered frames stays off for Fortnite/CS2 because Reflex is preferred when supported.' 18 370 805 45;$nvInfo.ForeColor=[System.Drawing.Color]::FromArgb(222,207,243)

    # NETWORK
    $np=$pages.Network;[void](New-KTitle $np 'Network Performance Lab' 12 6 500 36 16);[void](New-KLabel $np 'Gaming-first network diagnostics: absolute P95 tail latency, packet loss and reversibility come before tweak scores.' 12 43 840 40)
    $ncard=New-KCard $np 10 95 860 1600
    [void](New-KLabel $ncard 'Network adapter:' 18 25 110 25);$adapterCombo=New-Object System.Windows.Forms.ComboBox;$adapterCombo.DropDownStyle='DropDownList';$adapterCombo.Location=New-Object System.Drawing.Point(130,22);$adapterCombo.Size=New-Object System.Drawing.Size(365,28);[void]$ncard.Controls.Add($adapterCombo)
    foreach($a in Get-KPhysicalAdapters){[void]$adapterCombo.Items.Add($a.Name)};if($adapterCombo.Items.Count -gt 0){$adapterCombo.SelectedIndex=0}
    $refreshNic=New-KButton 'REFRESH ADAPTER' 515 18 145 36;[void]$ncard.Controls.Add($refreshNic);$scanNic=New-KButton 'VIEW NIC REPORT' 675 18 155 36;[void]$ncard.Controls.Add($scanNic)
    Set-FocsTip $adapterCombo 'Select the physical adapter used by the game. All automatic decisions are measured on this adapter.';Set-FocsTip $refreshNic 'Reload the values exposed by the NIC driver.';Set-FocsTip $scanNic 'Show the current adapter, driver and advanced-property inventory without changing anything.'

    $healthCard=New-KCard $ncard 18 75 812 215;[void](New-KTitle $healthCard '1. Low Latency Gaming Health' 14 10 460 28 12)
    $healthDesc=New-KLabel $healthCard 'This is the main network verdict. It measures absolute P95 tail latency, not just average ping. Target: P95 under 40 ms with no meaningful loss.' 14 42 775 42;$healthDesc.ForeColor=[System.Drawing.Color]::FromArgb(213,197,236)
    [void](New-KLabel $healthCard 'Game/server target:' 14 92 125 25);$labTarget=New-Object System.Windows.Forms.TextBox;$labTarget.Text='';$labTarget.Location=New-Object System.Drawing.Point(140,89);$labTarget.Size=New-Object System.Drawing.Size(210,28);[void]$healthCard.Controls.Add($labTarget);$targetHint=New-KLabel $healthCard 'Optional IP/hostname' 360 92 150 25;$targetHint.ForeColor=[System.Drawing.Color]::FromArgb(181,162,211)
    [void](New-KLabel $healthCard 'Upload Mbps:' 520 92 90 25);$bbUpload=New-Object System.Windows.Forms.NumericUpDown;$bbUpload.DecimalPlaces=1;$bbUpload.Minimum=2;$bbUpload.Maximum=10000;$bbUpload.Increment=1;$bbUpload.Value=$bbUpload.Minimum;$bbUpload.Location=New-Object System.Drawing.Point(610,89);$bbUpload.Size=New-Object System.Drawing.Size(105,28);[void]$healthCard.Controls.Add($bbUpload)
    $gamingTest=New-KButton 'RUN GAMING HEALTH' 14 140 205 42;$gamingTest.BackColor=[System.Drawing.Color]::FromArgb(104,56,184);[void]$healthCard.Controls.Add($gamingTest)
    $bufferTest=New-KButton 'FULL LOADED LATENCY' 230 140 200 42;[void]$healthCard.Controls.Add($bufferTest)
    $gatewayTest=New-KButton 'GATEWAY PING' 441 140 150 42;[void]$healthCard.Controls.Add($gatewayTest)
    $netHost=New-Object System.Windows.Forms.TextBox;$netHost.Text='1.1.1.1';$netHost.Location=New-Object System.Drawing.Point(602,145);$netHost.Size=New-Object System.Drawing.Size(105,28);[void]$healthCard.Controls.Add($netHost);$netTest=New-KButton 'PING' 716 140 72 38;[void]$healthCard.Controls.Add($netTest)
    Set-FocsTip $gamingTest 'Measures idle, download-loaded and upload-loaded P95 plus the gateway. PASS requires every measured gaming path to stay below 40 ms.';Set-FocsTip $bufferTest 'Detailed bufferbloat test. Shows both added latency and absolute P95 so a good average cannot hide gaming spikes.';Set-FocsTip $labTarget 'Optional game/server IP or hostname. A bad custom target with clean public paths usually points to routing/peering rather than NIC tuning.';Set-FocsTip $bbUpload 'Enter a recent real upload speed. It is used only to verify that upload-load tests actually stress the line.'

    $autoCard=New-KCard $ncard 18 305 812 205;[void](New-KTitle $autoCard '2. Automatic NIC Tuner - P95 gated' 14 10 500 28 12)
    $autoDesc=New-KLabel $autoCard 'Compares current settings, driver defaults and supported NIC values. A candidate is rejected if gaming P95 crosses 40 ms or tail latency meaningfully regresses.' 14 43 775 42;$autoDesc.ForeColor=[System.Drawing.Color]::FromArgb(213,197,236)
    [void](New-KLabel $autoCard 'Depth:' 14 97 55 25);$labDepth=New-Object System.Windows.Forms.ComboBox;$labDepth.DropDownStyle='DropDownList';foreach($d in @('Quick','Balanced','Deep')){[void]$labDepth.Items.Add($d)};$labDepth.SelectedIndex=1;$labDepth.Location=New-Object System.Drawing.Point(70,94);$labDepth.Size=New-Object System.Drawing.Size(135,28);[void]$autoCard.Controls.Add($labDepth)
    $autoTune=New-KButton 'RUN P95 AUTO TUNER' 220 88 190 40;$autoTune.BackColor=[System.Drawing.Color]::FromArgb(104,56,184);[void]$autoCard.Controls.Add($autoTune);$stabilityTune=New-KButton 'STABILITY FIRST' 420 88 155 40;$stabilityTune.BackColor=[System.Drawing.Color]::FromArgb(76,38,132);[void]$autoCard.Controls.Add($stabilityTune);$applyBest=New-KButton 'APPLY SAVED BEST' 585 88 200 40;$applyBest.BackColor=[System.Drawing.Color]::FromArgb(73,38,125);[void]$autoCard.Controls.Add($applyBest)
    $factoryNic=New-KButton 'DRIVER DEFAULTS' 14 145 170 38;[void]$autoCard.Controls.Add($factoryNic);$restoreNic=New-KButton 'RESTORE BACKUP' 194 145 170 38;[void]$autoCard.Controls.Add($restoreNic)
    $autoNote=New-KLabel $autoCard 'Packet loss and NIC errors remain hard vetoes. Tail latency now outranks tiny average-ping wins.' 385 151 400 30;$autoNote.ForeColor=[System.Drawing.Color]::FromArgb(181,162,211)
    Set-FocsTip $labDepth 'Balanced or Deep is preferred for network tuning because P95 is noisy on very short tests.';Set-FocsTip $autoTune 'Restarts the adapter while testing. It will not keep a setting that meaningfully worsens gaming P95, loss or NIC error counters.';Set-FocsTip $applyBest 'Reapply the last measured profile for this exact adapter.'

    $bbCard=New-KCard $ncard 18 525 812 220;[void](New-KTitle $bbCard '3. Bufferbloat / Queue Control' 14 10 460 28 12)
    $bbDesc=New-KLabel $bbCard 'Windows QoS is treated as an experiment, not a guaranteed fix. The reducer screens upload P95, validates cap enforcement, then runs a full uncapped-vs-capped gaming P95 gate.' 14 42 775 48;$bbDesc.ForeColor=[System.Drawing.Color]::FromArgb(213,197,236)
    $bufferReduce=New-KButton 'P95 BUFFERBLOAT REDUCER' 14 105 240 42;$bufferReduce.BackColor=[System.Drawing.Color]::FromArgb(104,56,184);[void]$bbCard.Controls.Add($bufferReduce);$bufferRemove=New-KButton 'RESTORE UNCAPPED NOW' 266 105 220 42;[void]$bbCard.Controls.Add($bufferRemove);$openRouter=New-KButton 'OPEN ROUTER' 498 105 140 42;[void]$bbCard.Controls.Add($openRouter);$bbStatus=New-KLabel $bbCard ((Get-FocsBufferbloatGuardStatus).Text) 650 108 145 38;$bbStatus.TextAlign='MiddleCenter';$bbStatus.ForeColor=[System.Drawing.Color]::FromArgb(111,235,185)
    $bbRevert=New-KButton 'FULL NETWORK REVERT' 14 162 240 38;$bbRevert.BackColor=[System.Drawing.Color]::FromArgb(90,40,40);[void]$bbCard.Controls.Add($bbRevert);$bbRevertHint=New-KLabel $bbCard 'Removes FOCS QoS + returns NIC advanced properties to driver defaults. Router SQM/CAKE/FQ-CoDel remains the preferred whole-network solution.' 270 162 515 42;$bbRevertHint.ForeColor=[System.Drawing.Color]::FromArgb(181,162,211)
    Set-FocsTip $bufferReduce 'Tests temporary ActiveStore caps only. A cap is kept only if absolute gaming P95 improves in the final full A/B test; reboot removes it.';Set-FocsTip $bufferRemove 'Immediately removes the FOCS-created outbound cap.';Set-FocsTip $openRouter 'Open your gateway. If upload/download loaded P95 remains high, configure router-side SQM if supported.';Set-FocsTip $bbRevert 'Emergency clean slate for FOCS network changes.'

    $manualCard=New-KCard $ncard 18 760 812 145;[void](New-KTitle $manualCard '4. Manual Driver Control' 14 10 400 28 12)
    [void](New-KLabel $manualCard 'Property:' 14 53 70 25);$propCombo=New-Object System.Windows.Forms.ComboBox;$propCombo.DropDownStyle='DropDownList';$propCombo.Location=New-Object System.Drawing.Point(82,50);$propCombo.Size=New-Object System.Drawing.Size(340,28);[void]$manualCard.Controls.Add($propCombo);[void](New-KLabel $manualCard 'Value:' 435 53 50 25);$valueCombo=New-Object System.Windows.Forms.ComboBox;$valueCombo.DropDownStyle='DropDownList';$valueCombo.Location=New-Object System.Drawing.Point(485,50);$valueCombo.Size=New-Object System.Drawing.Size(300,28);[void]$manualCard.Controls.Add($valueCombo)
    $applyNicValue=New-KButton 'APPLY ONE PROPERTY' 14 92 210 36;$applyNicValue.BackColor=[System.Drawing.Color]::FromArgb(73,38,125);[void]$manualCard.Controls.Add($applyNicValue);$currentNic=New-KLabel $manualCard 'Current value: -' 240 98 545 25;$currentNic.ForeColor=[System.Drawing.Color]::FromArgb(214,185,255)
    Set-FocsTip $propCombo 'Real properties reported by this NIC driver only.';Set-FocsTip $valueCombo 'Only values exposed as valid by the selected driver are listed.';Set-FocsTip $applyNicValue 'Backs up the NIC and changes exactly one property.'

    [void](New-KTitle $ncard '5. Manual A/B Experiments' 18 925 380 28 12);$experimentHint=New-KLabel $ncard 'No checkbox is assumed to be faster. Apply one idea, then re-run Gaming Health / Benchmark.' 18 955 805 25;$experimentHint.ForeColor=[System.Drawing.Color]::FromArgb(181,162,211)
    $imCard=New-KCard $ncard 18 990 390 108;$netIm=New-KCheck $imCard 'Interrupt Moderation' 14 10 $false;$netIm.Size=New-Object System.Drawing.Size(350,30);$imDesc=New-KLabel $imCard 'Changes interrupt batching. Lower moderation can reduce latency but increases CPU work.' 36 43 335 52;$imDesc.ForeColor=[System.Drawing.Color]::FromArgb(205,188,230)
    $eeeCard=New-KCard $ncard 422 990 390 108;$netEee=New-KCheck $eeeCard 'Disable Energy Efficient Ethernet' 14 10 $false;$netEee.Size=New-Object System.Drawing.Size(350,30);$eeeDesc=New-KLabel $eeeCard 'Prevents Ethernet low-power states. Useful only if measurement shows fewer spikes.' 36 43 335 52;$eeeDesc.ForeColor=[System.Drawing.Color]::FromArgb(205,188,230)
    $flowCard=New-KCard $ncard 18 1110 390 108;$netFlow=New-KCheck $flowCard 'Disable Flow Control' 14 10 $false;$netFlow.Size=New-Object System.Drawing.Size(350,30);$flowDesc=New-KLabel $flowCard 'Changes pause-frame behavior. Can reduce pauses or make congestion worse; always A/B test.' 36 43 335 52;$flowDesc.ForeColor=[System.Drawing.Color]::FromArgb(205,188,230)
    $lsoCard=New-KCard $ncard 422 1110 390 108;$netLso=New-KCheck $lsoCard 'Disable Large Send Offload' 14 10 $false;$netLso.Size=New-Object System.Drawing.Size(350,30);$lsoDesc=New-KLabel $lsoCard 'Moves segmentation work back to the CPU. Not a universal latency win.' 36 43 335 52;$lsoDesc.ForeColor=[System.Drawing.Color]::FromArgb(205,188,230)
    $rscCard=New-KCard $ncard 18 1230 390 108;$netRsc=New-KCheck $rscCard 'Disable Receive Segment Coalescing' 14 10 $false;$netRsc.Size=New-Object System.Drawing.Size(350,30);$rscDesc=New-KLabel $rscCard 'Reduces receive coalescing but raises CPU overhead. Keep only if P95 improves.' 36 43 335 52;$rscDesc.ForeColor=[System.Drawing.Color]::FromArgb(205,188,230)
    $rssCard=New-KCard $ncard 422 1230 390 108;$rssTitle=New-KLabel $rssCard 'RSS: kept enabled' 14 10 350 30;$rssTitle.Font=New-Object System.Drawing.Font('Segoe UI Semibold',10);$rssTitle.ForeColor=[System.Drawing.Color]::FromArgb(244,238,255);$rssDesc=New-KLabel $rssCard 'RSS spreads receive processing across CPU cores and remains the normal multi-core baseline.' 14 43 355 52;$rssDesc.ForeColor=[System.Drawing.Color]::FromArgb(205,188,230)
    Set-FocsTip $imCard 'A/B test interrupt moderation with Gaming Health; do not assume Off is better.';Set-FocsTip $eeeCard 'Power-saving link states can add variability on some adapters.';Set-FocsTip $flowCard 'Flow Control is congestion-dependent; disable only as an experiment.';Set-FocsTip $lsoCard 'Offload changes affect CPU and batching. Measure P95 and frametimes.';Set-FocsTip $rscCard 'RSC can change receive batching. P95 regression is a reject.';Set-FocsTip $rssCard 'FOCS keeps RSS as the default baseline on multi-core systems.'
    $applyLatencyNic=New-KButton 'APPLY CHECKED EXPERIMENTS' 18 1352 280 40;$applyLatencyNic.BackColor=[System.Drawing.Color]::FromArgb(73,38,125);[void]$ncard.Controls.Add($applyLatencyNic);Set-FocsTip $applyLatencyNic 'Backs up the adapter and applies only the checked experiments.'
    $netResult=New-Object System.Windows.Forms.TextBox;$netResult.Multiline=$true;$netResult.ReadOnly=$true;$netResult.ScrollBars='Vertical';$netResult.Location=New-Object System.Drawing.Point(18,1407);$netResult.Size=New-Object System.Drawing.Size(812,150);$netResult.BackColor=[System.Drawing.Color]::FromArgb(13,7,23);$netResult.BorderStyle=[System.Windows.Forms.BorderStyle]::FixedSingle;$netResult.ForeColor=[System.Drawing.Color]::FromArgb(213,197,236);[void]$ncard.Controls.Add($netResult);Set-FocsTip $netResult 'Live results. Focus on loss and absolute P95; average ping alone is not the gaming verdict.'
    $script:Ui.AdapterCombo=$adapterCombo;$script:Ui.PropCombo=$propCombo;$script:Ui.ValueCombo=$valueCombo;$script:Ui.CurrentNic=$currentNic

    # SERVICES
    $sp=$pages.Services;[void](New-KTitle $sp 'Service Manager' 12 6 500 36 16);[void](New-KLabel $sp 'Expanded optional-service list. Manual is safer; Disabled is advanced and should only be used for features you never use.' 12 43 840 40)
    $svcCard=New-KCard $sp 10 95 860 570;$svcList=New-Object System.Windows.Forms.CheckedListBox;$svcList.Location=New-Object System.Drawing.Point(18,20);$svcList.Size=New-Object System.Drawing.Size(560,455);$svcList.BackColor=[System.Drawing.Color]::FromArgb(13,7,23);$svcList.ForeColor=[System.Drawing.Color]::FromArgb(225,210,245);$svcList.CheckOnClick=$true;[void]$svcCard.Controls.Add($svcList)
    $svcMap=[ordered]@{
        'DiagTrack'='Connected User Experiences / telemetry';'dmwappushservice'='WAP Push / diagnostics';'MapsBroker'='Downloaded Maps Manager';'Fax'='Fax';'RemoteRegistry'='Remote Registry';'RetailDemo'='Retail Demo';'PhoneSvc'='Phone Service';'WalletService'='Wallet';'WMPNetworkSvc'='Windows Media sharing';'lfsvc'='Geolocation';'CscService'='Offline Files';'XblAuthManager'='Xbox Live Auth';'XblGameSave'='Xbox Live Game Save';'XboxNetApiSvc'='Xbox networking';'XboxGipSvc'='Xbox accessories';'Spooler'='Print Spooler (keep if you print)';'WSearch'='Windows Search indexing';'SysMain'='SysMain (A/B test only)';'BthAvctpSvc'='Bluetooth AVCTP';'bthserv'='Bluetooth Support'
    }
    foreach($sn in $svcMap.Keys){if(Get-Service -Name $sn -ErrorAction SilentlyContinue){[void]$svcList.Items.Add("$sn - $($svcMap[$sn])",$false)}}
    [void](New-KLabel $svcCard 'Action:' 600 25 70 25);$svcMode=New-Object System.Windows.Forms.ComboBox;$svcMode.DropDownStyle='DropDownList';[void]$svcMode.Items.Add('Manual');[void]$svcMode.Items.Add('Disabled');$svcMode.SelectedIndex=0;$svcMode.Location=New-Object System.Drawing.Point(665,22);$svcMode.Size=New-Object System.Drawing.Size(165,28);[void]$svcCard.Controls.Add($svcMode)
    $svcApply=New-KButton 'APPLY TO CHECKED' 600 70 230 42;$svcApply.BackColor=[System.Drawing.Color]::FromArgb(104,56,184);[void]$svcCard.Controls.Add($svcApply)
    $svcSafe=New-KButton 'SELECT LOW-IMPACT' 600 120 230 38;[void]$svcCard.Controls.Add($svcSafe)
    $svcClear=New-KButton 'CLEAR' 600 165 230 38;[void]$svcCard.Controls.Add($svcClear)
    $svcNote=New-KLabel $svcCard 'Do not disable networking, audio, RPC, Defender, Windows Update, Plug and Play or other core services. Xbox, printing, Bluetooth, indexing and ICS entries are optional only if you do not use those features.' 600 230 230 200;$svcNote.ForeColor=[System.Drawing.Color]::FromArgb(237,194,120)
    Set-FocsTip $svcList 'Optional services only. Hover the page controls and disable a service only when you do not use the related Windows feature.'
    Set-FocsTip $svcMode 'Manual lets Windows start the service when needed. Disabled prevents it from starting until you change it back.'
    Set-FocsTip $svcApply 'Applies the selected startup mode only to the checked services and creates a backup first.'

    # REGISTRY / PRIVACY
    $rp=$pages.Registry;[void](New-KTitle $rp 'Registry / Privacy / UI Background Activity' 12 6 650 36 16);[void](New-KLabel $rp 'These are explicit, reversible policies/preferences. Select only what matches your use case.' 12 43 840 28)
    $regCard=New-KCard $rp 10 80 860 590;$regList=New-Object System.Windows.Forms.CheckedListBox;$regList.Location=New-Object System.Drawing.Point(18,20);$regList.Size=New-Object System.Drawing.Size(560,420);$regList.BackColor=[System.Drawing.Color]::FromArgb(13,7,23);$regList.ForeColor=[System.Drawing.Color]::FromArgb(225,210,245);$regList.CheckOnClick=$true;[void]$regCard.Controls.Add($regList)
    $regCatalog=Get-KRegistryCatalog;foreach($n in $regCatalog.Keys){[void]$regList.Items.Add($n,$false)}
    $regRecommended=New-KButton 'SELECT RECOMMENDED' 600 20 230 38;[void]$regCard.Controls.Add($regRecommended)
    $regCompetitive=New-KButton 'SELECT COMPETITIVE' 600 65 230 38;[void]$regCard.Controls.Add($regCompetitive)
    $regClear=New-KButton 'CLEAR' 600 110 230 38;[void]$regCard.Controls.Add($regClear)
    $regApply=New-KButton 'APPLY CHECKED' 600 165 230 42;$regApply.BackColor=[System.Drawing.Color]::FromArgb(104,56,184);[void]$regCard.Controls.Add($regApply)
    $hagsEnable=New-KButton 'ENABLE HAGS' 600 235 110 34;[void]$regCard.Controls.Add($hagsEnable);$hagsDisable=New-KButton 'DISABLE HAGS' 720 235 110 34;[void]$regCard.Controls.Add($hagsDisable)
    $bcdScan=New-KButton 'SCAN BCD TIMERS' 600 285 230 34;[void]$regCard.Controls.Add($bcdScan);$msiScan=New-KButton 'SCAN MSI / MSI-X' 600 325 230 34;[void]$regCard.Controls.Add($msiScan)
    $regOut=New-Object System.Windows.Forms.TextBox;$regOut.Multiline=$true;$regOut.ReadOnly=$true;$regOut.ScrollBars='Vertical';$regOut.Location=New-Object System.Drawing.Point(18,455);$regOut.Size=New-Object System.Drawing.Size(812,110);$regOut.BackColor=[System.Drawing.Color]::FromArgb(13,7,23);$regOut.BorderStyle=[System.Windows.Forms.BorderStyle]::FixedSingle;$regOut.ForeColor=[System.Drawing.Color]::FromArgb(213,197,236);[void]$regCard.Controls.Add($regOut)
    $script:Ui.RegList=$regList
    Set-FocsTip $regList 'Reversible registry/privacy options. Check only the behavior you actually want to change.'
    Set-FocsTip $regRecommended 'Selects the lower-risk privacy/background-activity set.'
    Set-FocsTip $regCompetitive 'Selects the recommended set plus a few extra UI/search reductions.'
    Set-FocsTip $hagsEnable 'Requests HAGS on. Reboot and benchmark because the result depends on GPU, driver and game.'
    Set-FocsTip $hagsDisable 'Requests HAGS off. Reboot and compare against HAGS on using the same game workload.'
    Set-FocsTip $bcdScan 'Scans for forced timer/BCD overrides. It does not change them.'
    Set-FocsTip $msiScan 'Reports whether devices expose MSI/MSI-X interrupt mode. The scan does not force changes.'

    # BACKUP
    $bp=$pages.Backup;[void](New-KTitle $bp 'Backup & Restore' 12 6 500 36 16);[void](New-KLabel $bp 'Registry, services, power and NIC tuning are backed up before FOCS changes them.' 12 43 840 28)
    $bcard=New-KCard $bp 10 80 860 360;$createBackup=New-KButton 'CREATE BACKUP NOW' 18 25 230 44;[void]$bcard.Controls.Add($createBackup);$restoreLatest=New-KButton 'RESTORE LATEST BACKUP' 265 25 250 44;[void]$bcard.Controls.Add($restoreLatest);$openBackup=New-KButton 'OPEN BACKUP FOLDER' 532 25 230 44;[void]$bcard.Controls.Add($openBackup);$exportReport=New-KButton 'EXPORT DIAGNOSTIC REPORT' 18 90 270 44;[void]$bcard.Controls.Add($exportReport);$backupInfo=New-KLabel $bcard "Backup root:`r`n$script:BackupRoot`r`n`r`nLogs:`r`n$script:LogRoot`r`n`r`nManaged tools:`r`n$script:ToolRoot" 18 155 800 170;$backupInfo.ForeColor=[System.Drawing.Color]::FromArgb(213,197,236)

    # DIAGNOSTICS
    $dg=$pages.Diagnostics;[void](New-KTitle $dg 'Diagnostics' 12 6 500 36 16);[void](New-KLabel $dg 'Measure first: ETW/WPR latency tracing, graphics/display state, raw mouse polling and compatibility preview.' 12 43 840 38)
    $latCard=New-KCard $dg 10 92 860 280;[void](New-KTitle $latCard 'Latency Doctor (ETW / WPR)' 14 10 430 28 12)
    $latInfo=New-KLabel $latCard 'Captures Windows GeneralProfile plus DPC/interrupt/page-in counters. With Windows Performance Toolkit, FOCS also generates DPC/ISR, hard-fault, driver-delay and scheduling reports.' 14 42 815 55;$latInfo.ForeColor=[System.Drawing.Color]::FromArgb(213,197,236)
    [void](New-KLabel $latCard 'Seconds:' 14 105 65 25);$latSeconds=New-Object System.Windows.Forms.NumericUpDown;$latSeconds.Minimum=10;$latSeconds.Maximum=300;$latSeconds.Value=60;$latSeconds.Location=New-Object System.Drawing.Point(80,102);$latSeconds.Size=New-Object System.Drawing.Size(80,28);[void]$latCard.Controls.Add($latSeconds)
    $runLatency=New-KButton 'RUN LATENCY DOCTOR' 180 98 210 38;$runLatency.BackColor=[System.Drawing.Color]::FromArgb(104,56,184);[void]$latCard.Controls.Add($runLatency)
    $installWpt=New-KButton 'INSTALL WPT (OPTIONAL)' 405 98 210 38;[void]$latCard.Controls.Add($installWpt);$openTrace=New-KButton 'OPEN LAST TRACE' 630 98 190 38;[void]$latCard.Controls.Add($openTrace)
    $latOut=New-Object System.Windows.Forms.TextBox;$latOut.Multiline=$true;$latOut.ReadOnly=$true;$latOut.ScrollBars='Vertical';$latOut.Location=New-Object System.Drawing.Point(14,150);$latOut.Size=New-Object System.Drawing.Size(806,110);$latOut.BackColor=[System.Drawing.Color]::FromArgb(13,7,23);$latOut.ForeColor=[System.Drawing.Color]::FromArgb(213,197,236);[void]$latCard.Controls.Add($latOut)
    Set-FocsTip $runLatency 'Records a Windows ETW trace and samples DPC/interrupt counters while you reproduce the stutter. FOCS never stops an already-running WPR trace.';Set-FocsTip $installWpt 'Optional Microsoft Windows Performance Toolkit. Adds xperf/WPA for per-driver DPC/ISR analysis.';Set-FocsTip $openTrace 'Opens the most recent ETL in Windows Performance Analyzer when WPA is installed, otherwise opens its folder.'

    $gfxCard=New-KCard $dg 10 388 860 195;[void](New-KTitle $gfxCard 'Display & Graphics Inspector' 14 10 430 28 12);$gfxOut=New-Object System.Windows.Forms.TextBox;$gfxOut.Multiline=$true;$gfxOut.ReadOnly=$true;$gfxOut.ScrollBars='Vertical';$gfxOut.Location=New-Object System.Drawing.Point(14,45);$gfxOut.Size=New-Object System.Drawing.Size(600,130);$gfxOut.BackColor=[System.Drawing.Color]::FromArgb(13,7,23);$gfxOut.ForeColor=[System.Drawing.Color]::FromArgb(213,197,236);[void]$gfxCard.Controls.Add($gfxOut);$refreshGfx=New-KButton 'REFRESH INSPECTOR' 630 48 190 38;[void]$gfxCard.Controls.Add($refreshGfx);$openGraphics=New-KButton 'OPEN GRAPHICS SETTINGS' 630 98 190 38;[void]$gfxCard.Controls.Add($openGraphics)
    Set-FocsTip $refreshGfx 'Reads active display resolution/refresh rate plus HAGS, Game Mode and Windows VRR/windowed-game optimization state.'

    $inputCard=New-KCard $dg 10 600 860 150;[void](New-KTitle $inputCard 'Input Latency Inspector' 14 10 430 28 12);$mouseResult=New-KLabel $inputCard 'Raw mouse polling test has not been run.' 14 48 580 78;$mouseResult.ForeColor=[System.Drawing.Color]::FromArgb(213,197,236);$mousePoll=New-KButton 'MEASURE MOUSE POLLING (5s)' 610 52 210 42;[void]$inputCard.Controls.Add($mousePoll);Set-FocsTip $mousePoll 'Move the mouse continuously for five seconds. FOCS measures WM_INPUT event spacing and estimates the effective polling cadence.'

    $compCard=New-KCard $dg 10 768 860 250;[void](New-KTitle $compCard 'Compatibility Engine / Change Preview' 14 10 500 28 12);$compOut=New-Object System.Windows.Forms.TextBox;$compOut.Multiline=$true;$compOut.ReadOnly=$true;$compOut.ScrollBars='Vertical';$compOut.Location=New-Object System.Drawing.Point(14,48);$compOut.Size=New-Object System.Drawing.Size(806,135);$compOut.BackColor=[System.Drawing.Color]::FromArgb(13,7,23);$compOut.ForeColor=[System.Drawing.Color]::FromArgb(213,197,236);[void]$compCard.Controls.Add($compOut);$compRefresh=New-KButton 'ANALYZE + PREVIEW' 14 195 210 38;$compRefresh.BackColor=[System.Drawing.Color]::FromArgb(73,38,125);[void]$compCard.Controls.Add($compRefresh);$compNote=New-KLabel $compCard 'Shows support/state before changes. It does not apply tweaks.' 245 202 560 25;$compNote.ForeColor=[System.Drawing.Color]::FromArgb(181,162,211)

    # BENCHMARK / TOOLS
    $bt=$pages.Bench;[void](New-KTitle $bt 'Benchmark Engine 2.0' 12 6 500 36 16);[void](New-KLabel $bt 'Multi-run PresentMon A/B testing with noise-aware medians and optional CPU/GPU telemetry.' 12 43 840 28)
    $tm=New-KCard $bt 10 80 860 200;[void](New-KTitle $tm 'Automatic tool manager' 14 10 400 28 12);$toolText=New-KLabel $tm 'FOCS uses the official standalone PresentMon console binary for benchmarks; other managed tools use winget/Chocolatey where appropriate, then official vendor releases. Chocolatey itself is never silently installed.' 18 48 815 45;$toolText.ForeColor=[System.Drawing.Color]::FromArgb(213,197,236);$updateAll=New-KButton 'UPDATE ALL NOW' 18 110 190 40;$updateAll.BackColor=[System.Drawing.Color]::FromArgb(104,56,184);[void]$tm.Controls.Add($updateAll);$installLat=New-KButton 'INSTALL / UPDATE LATENCYMON' 225 110 260 40;[void]$tm.Controls.Add($installLat);$launchLat=New-KButton 'LAUNCH LATENCYMON' 502 110 200 40;[void]$tm.Controls.Add($launchLat);$toolsResult=New-KLabel $tm '' 18 158 815 28;$script:Ui.ToolsResult=$toolsResult
    $bm=New-KCard $bt 10 295 860 625;[void](New-KTitle $bm 'PresentMon multi-run A/B benchmark' 14 10 500 28 12)
    [void](New-KLabel $bm 'Detected game:' 18 53 100 25);$gameCombo=New-Object System.Windows.Forms.ComboBox;$gameCombo.DropDownStyle='DropDownList';$gameCombo.Location=New-Object System.Drawing.Point(118,50);$gameCombo.Size=New-Object System.Drawing.Size(390,28);[void]$bm.Controls.Add($gameCombo)
    $scanGames=New-KButton 'SCAN INSTALLED GAMES' 520 47 155 34;[void]$bm.Controls.Add($scanGames);$runningGames=New-KButton 'RUNNING GAMES' 686 47 140 34;[void]$bm.Controls.Add($runningGames)
    [void](New-KLabel $bm 'Process:' 18 94 70 25);$benchProc=New-Object System.Windows.Forms.TextBox;$benchProc.Text='';$benchProc.Location=New-Object System.Drawing.Point(90,91);$benchProc.Size=New-Object System.Drawing.Size(280,28);[void]$bm.Controls.Add($benchProc);$browseGameExe=New-KButton 'BROWSE EXE' 380 88 120 34;[void]$bm.Controls.Add($browseGameExe)
    $gamePathLabel=New-KLabel $bm 'Click SCAN INSTALLED GAMES. Windows GameConfigStore, Steam, Epic, GOG, Ubisoft and common Xbox/Riot/EA game folders are checked.' 18 126 805 38;$gamePathLabel.ForeColor=[System.Drawing.Color]::FromArgb(181,162,211)
    [void](New-KLabel $bm 'Seconds:' 18 174 70 25);$benchSeconds=New-Object System.Windows.Forms.NumericUpDown;$benchSeconds.Minimum=10;$benchSeconds.Maximum=300;$benchSeconds.Value=45;$benchSeconds.Location=New-Object System.Drawing.Point(88,171);$benchSeconds.Size=New-Object System.Drawing.Size(70,28);[void]$bm.Controls.Add($benchSeconds)
    [void](New-KLabel $bm 'Runs:' 175 174 45 25);$benchRuns=New-Object System.Windows.Forms.NumericUpDown;$benchRuns.Minimum=2;$benchRuns.Maximum=7;$benchRuns.Value=3;$benchRuns.Location=New-Object System.Drawing.Point(220,171);$benchRuns.Size=New-Object System.Drawing.Size(60,28);[void]$bm.Controls.Add($benchRuns)
    $telemetryCheck=New-Object System.Windows.Forms.CheckBox;$telemetryCheck.Text='Hardware telemetry';$telemetryCheck.Checked=$true;$telemetryCheck.Location=New-Object System.Drawing.Point(300,170);$telemetryCheck.Size=New-Object System.Drawing.Size(160,28);$telemetryCheck.ForeColor=[System.Drawing.Color]::White;[void]$bm.Controls.Add($telemetryCheck)
    $pcLatency=New-Object System.Windows.Forms.CheckBox;$pcLatency.Text='PC latency beta';$pcLatency.Location=New-Object System.Drawing.Point(470,170);$pcLatency.Size=New-Object System.Drawing.Size(145,28);$pcLatency.ForeColor=[System.Drawing.Color]::White;[void]$bm.Controls.Add($pcLatency)
    $pmQuickTest=New-KButton 'TEST PRESENTMON (5s)' 18 210 190 38;[void]$bm.Controls.Add($pmQuickTest);$baseline=New-KButton 'CAPTURE BASELINE SET' 218 210 220 38;[void]$bm.Controls.Add($baseline);$after=New-KButton 'CAPTURE AFTER SET + COMPARE' 448 210 300 38;$after.BackColor=[System.Drawing.Color]::FromArgb(104,56,184);[void]$bm.Controls.Add($after)
    $benchOut=New-Object System.Windows.Forms.TextBox;$benchOut.Multiline=$true;$benchOut.ReadOnly=$true;$benchOut.ScrollBars='Vertical';$benchOut.Location=New-Object System.Drawing.Point(18,263);$benchOut.Size=New-Object System.Drawing.Size(812,335);$benchOut.BackColor=[System.Drawing.Color]::FromArgb(13,7,23);$benchOut.BorderStyle=[System.Windows.Forms.BorderStyle]::FixedSingle;$benchOut.ForeColor=[System.Drawing.Color]::FromArgb(213,197,236);[void]$bm.Controls.Add($benchOut)
    Set-FocsTip $gameCombo 'Games found from Windows GameConfigStore and installed launcher/library metadata. Choose the executable that actually renders the game.';Set-FocsTip $pmQuickTest 'Runs a five-second capture against the exact running game PID and shows the real PresentMon error output if the console capture fails.';Set-FocsTip $scanGames 'Scans Windows game records plus Steam, Epic, GOG, Ubisoft and common Xbox/Riot/EA library folders. It verifies that each executable still exists.';Set-FocsTip $runningGames 'Shows currently running non-system windowed programs so a game can be selected even when its launcher metadata is unusual.';Set-FocsTip $browseGameExe 'Fallback for any game the automatic scanner misses. Choose the actual game EXE, not the launcher.';Set-FocsTip $benchProc 'Exact executable PresentMon will capture. For CS2 this should resolve to cs2.exe.';Set-FocsTip $benchSeconds 'Duration of each run. Use the same scene/workload for every run.';Set-FocsTip $benchRuns 'FOCS compares medians across multiple runs. Three runs is a useful default; five reduces noise further.';Set-FocsTip $telemetryCheck 'Samples CPU/GPU sensors during each capture when LibreHardwareMonitor is available, with NVIDIA-smi fallback for NVIDIA GPU telemetry.';Set-FocsTip $baseline 'Captures a baseline set of repeated runs. The selected game process must already be running.';Set-FocsTip $after 'Captures the same number of after-runs and compares median FPS, 1% low and P99 frametime against measured run-to-run noise.'

    # ABOUT
    $ap=$pages.About;[void](New-KTitle $ap 'About FOCS Utility v9.5.0' 12 6 600 36 16);$aboutCard=New-KCard $ap 10 80 860 620
    $aboutText=@"
FOCS v9.5.0 design rules

- Profiles are selectors, not mystery scripts. Every important change is visible on a page.
- App removal is explicit; Microsoft Store, App Installer, WebView2 and Windows Security are not offered for removal.
- Edge removal uses only the supported package-manager uninstall. No force-delete workaround.
- OneDrive has separate uninstall/reinstall controls.
- App Installer uses a fixed five-app WinGet catalog, exact package IDs, a review prompt and per-app results.
- NVIDIA profiles are per-game and backed up before import.
- Reflex games should use in-game Reflex. Maximum pre-rendered frames is exposed only as an optional non-Reflex experiment.
- NIC advanced values come from your driver. FOCS never assumes a Realtek/Intel property exists.
- Network Performance Lab makes absolute P95 tail latency the primary gaming gate. Candidates crossing 40 ms or regressing loss/NIC errors are rejected.

- Fortnite Stability Tune keeps RSS/offloads enabled, disables NIC sleep/EEE when supported, uses Auto Negotiation, normal TCP Auto-Tuning and rolls back if measured loss/errors get worse.
- Packet loss is weighted most heavily, followed by P95 latency, jitter and average latency. Manual NIC controls remain available.
- Network Lab 2.0 adds quiet-vs-loaded download/upload latency so bufferbloat can be separated from idle ping.
- P95 Bufferbloat Reducer uses temporary Windows outbound caps only, validates cap enforcement, and rolls back unless full uncapped-vs-capped gaming P95 improves. Router SQM remains the stronger whole-network solution.
- Benchmark Engine 2.0 uses repeated runs, median comparison and a run-to-run noise threshold instead of trusting one capture.
- Game Scanner finds benchmark targets from Windows GameConfigStore plus Steam/Epic/GOG/Ubisoft and common Xbox/Riot/EA library folders; manual EXE and running-process fallbacks remain available.
- Hardware telemetry is optional and uses LibreHardwareMonitor with NVIDIA-smi fallback.
- Latency Doctor records an ETW/WPR trace and uses xperf DPC/ISR analysis when Windows Performance Toolkit is installed.
- Display/Input diagnostics report active refresh rate, Windows graphics switches and raw mouse input cadence.
- Per-game power orchestration, startup/background analyzer and storage/game-drive health are intentionally not part of v9.5.0.
- Services are opt-in and core security/network/audio/update services are excluded.
- No Defender/VBS/firewall disabling, Realtime priority, forced HPET or blanket MSI forcing.
"@
    $aboutLabel=New-KLabel $aboutCard $aboutText 18 18 815 575;$aboutLabel.ForeColor=[System.Drawing.Color]::FromArgb(216,200,238)

    function Show-KPage([string]$Name,[System.Windows.Forms.Button]$Nav){foreach($p in $pages.Values){$p.Visible=$false};$pages[$Name].Visible=$true;$pages[$Name].BringToFront();Set-KNavSelected -Buttons $navButtons -Selected $Nav}
    $navHome.Add_Click({try{Show-KPage 'Home' $navHome}catch{}});$navTweaks.Add_Click({try{Show-KPage 'Tweaks' $navTweaks}catch{}});$navDebloat.Add_Click({try{Show-KPage 'Debloat' $navDebloat}catch{}});$navInstaller.Add_Click({try{Show-KPage 'Installer' $navInstaller}catch{}});$navNvidia.Add_Click({try{Show-KPage 'Nvidia' $navNvidia}catch{}});$navNetwork.Add_Click({try{Show-KPage 'Network' $navNetwork}catch{}});$navServices.Add_Click({try{Show-KPage 'Services' $navServices}catch{}});$navRegistry.Add_Click({try{Show-KPage 'Registry' $navRegistry}catch{}});$navBackup.Add_Click({try{Show-KPage 'Backup' $navBackup}catch{}});$navDiag.Add_Click({try{Show-KPage 'Diagnostics' $navDiag}catch{}});$navBench.Add_Click({try{Show-KPage 'Bench' $navBench}catch{}});$navAbout.Add_Click({try{Show-KPage 'About' $navAbout}catch{}})

    $powerTuneBtn.Add_Click({try{$ans=[System.Windows.Forms.MessageBox]::Show("FOCS will benchmark several Windows power plans on this PC, briefly switch between them, and keep the lowest measured CPU-burst + wake-latency result. This does not overclock the CPU. Close games/downloads for a cleaner result. Continue?",'FOCS Power Plan Lab',[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Information);if($ans -ne [System.Windows.Forms.DialogResult]::Yes){return};$form.UseWaitCursor=$true;$msg=Invoke-FocsPowerPlanLab -PowerLabel $powerText;Show-KMessage $msg 'FOCS Power Plan Lab'}catch{Show-KMessage $_.Exception.Message 'Power Plan Lab error' ([System.Windows.Forms.MessageBoxIcon]::Error)}finally{$form.UseWaitCursor=$false}})

    $applySelected.Add_Click({try{Apply-SafeTweaks -Controls $controls;if($controls.Hags.Checked){Apply-HagsChoice -Choice 'Enable HAGS'}}catch{Show-KMessage $_.Exception.Message 'Windows baseline error' ([System.Windows.Forms.MessageBoxIcon]::Error)}})
    $applyProfile.Add_Click({try{Apply-SafeTweaks -Controls $controls;if($controls.Hags.Checked){Apply-HagsChoice -Choice 'Enable HAGS'};[void](Apply-KProfileRegistryDefaults -Profile $script:SelectedProfile);Show-KMessage "Profile $script:SelectedProfile applied. App removal, NIC latency and NVIDIA settings stay explicit on their own pages." 'FOCS profile'}catch{$detail=$_.Exception.Message;if($_.ScriptStackTrace){$detail+="`r`n`r`n"+$_.ScriptStackTrace};Write-KLog "Profile apply failed: $detail";Show-KMessage $detail 'Profile apply error' ([System.Windows.Forms.MessageBoxIcon]::Error)}})

    $selectCommon.Add_Click({$common=@('Clipchamp','Microsoft News','Microsoft Weather','Solitaire Collection','Feedback Hub','Maps','Microsoft 365 / Office Hub');for($i=0;$i -lt $debloatList.Items.Count;$i++){$debloatList.SetItemChecked($i,($common -contains [string]$debloatList.Items[$i]))}})
    $clearApps.Add_Click({for($i=0;$i -lt $debloatList.Items.Count;$i++){$debloatList.SetItemChecked($i,$false)}})
    $removeApps.Add_Click({try{$ans=[System.Windows.Forms.MessageBox]::Show('Remove the checked apps? FOCS saves an inventory, but Store-app removal is not always automatically reversible.','FOCS App Debloat',[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Warning);if($ans -ne [System.Windows.Forms.DialogResult]::Yes){return};$scope=if($debScope.SelectedIndex -eq 1){'AllUsers'}else{'CurrentUser'};$msg=Remove-KSelectedBloat -List $debloatList -Scope $scope;Show-KMessage $msg 'Debloat complete'}catch{Show-KMessage $_.Exception.Message 'Debloat error' ([System.Windows.Forms.MessageBoxIcon]::Error)}})
    $odRemove.Add_Click({try{$ans=[System.Windows.Forms.MessageBox]::Show('Uninstall OneDrive from Windows? Local synced files are not deleted by the uninstaller, but sync stops until reinstalled.','OneDrive',[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Warning);if($ans -eq [System.Windows.Forms.DialogResult]::Yes){Show-KMessage (Uninstall-KOneDrive) 'OneDrive'}}catch{Show-KMessage $_.Exception.Message 'OneDrive error' ([System.Windows.Forms.MessageBoxIcon]::Error)}})
    $odInstall.Add_Click({try{Show-KMessage (Install-KOneDrive) 'OneDrive'}catch{Show-KMessage $_.Exception.Message 'OneDrive error' ([System.Windows.Forms.MessageBoxIcon]::Error)}})
    $edgeRemove.Add_Click({try{$ans=[System.Windows.Forms.MessageBox]::Show('Try the supported Microsoft Edge uninstall exposed by winget? If Windows does not permit it, FOCS will stop and will not force-delete system files.','Microsoft Edge',[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Warning);if($ans -eq [System.Windows.Forms.DialogResult]::Yes){Show-KMessage (Uninstall-KEdgeSupported) 'Microsoft Edge'}}catch{Show-KMessage $_.Exception.Message 'Edge uninstall' ([System.Windows.Forms.MessageBoxIcon]::Warning)}})

    $appSelectAll.Add_Click({for($i=0;$i -lt $appList.Items.Count;$i++){$appList.SetItemChecked($i,$true)}})
    $appClear.Add_Click({for($i=0;$i -lt $appList.Items.Count;$i++){$appList.SetItemChecked($i,$false)}})
    $appRefresh.Add_Click({try{$form.UseWaitCursor=$true;$appOut.Text='Querying WinGet package status...';[System.Windows.Forms.Application]::DoEvents();$appOut.Text=Format-FocsAppInstallerStatus -Status @(Get-FocsAppInstallerStatus)}catch{$appOut.Text="Status refresh failed: $($_.Exception.Message)";Write-KLog $appOut.Text}finally{$form.UseWaitCursor=$false}})
    $appInstall.Add_Click({
        try {
            $ids=New-Object System.Collections.Generic.List[string]
            $names=New-Object System.Collections.Generic.List[string]
            foreach($index in @($appList.CheckedIndices)){$app=$script:Ui.AppCatalog[[int]$index];$ids.Add([string]$app.PackageId);$names.Add([string]$app.Name)}
            if(-not $ids.Count){throw 'Select at least one application.'}
            $ans=[System.Windows.Forms.MessageBox]::Show(("Install or update these applications through WinGet?`r`n`r`n- " + ($names -join "`r`n- ")),'FOCS App Installer',[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Information)
            if($ans -ne [System.Windows.Forms.DialogResult]::Yes){return}
            $form.UseWaitCursor=$true
            $appOut.Text=Install-FocsSelectedApps -PackageIds @($ids) -OutputBox $appOut
        } catch {
            $appOut.Text="App installation failed: $($_.Exception.Message)"
            Write-KLog $appOut.Text
            Show-KMessage $_.Exception.Message 'App Installer error' ([System.Windows.Forms.MessageBoxIcon]::Error)
        } finally {$form.UseWaitCursor=$false}
    })

    $updateAction={try{$form.UseWaitCursor=$true;$r=Update-ManagedTools -Force;$toolsResult.Text=($r -replace "`r?`n",' | ');Update-ToolStatusLabels;$nvStatus.Text=if(Find-NvidiaProfileInspector){"Ready: $(Get-ManagedVersion $script:NpiRoot)"}else{'Not available'}}catch{Show-KMessage $_.Exception.Message 'Tool update error' ([System.Windows.Forms.MessageBoxIcon]::Error)}finally{$form.UseWaitCursor=$false}}
    $updateAll.Add_Click($updateAction);$updateMini.Add_Click($updateAction);$updateNpi.Add_Click({try{$form.UseWaitCursor=$true;$nvStatus.Text=Update-NpiTool -Force;Update-ToolStatusLabels}catch{Show-KMessage $_.Exception.Message 'NPI update error' ([System.Windows.Forms.MessageBoxIcon]::Error)}finally{$form.UseWaitCursor=$false}});$openNpi.Add_Click({try{if(-not(Find-NvidiaProfileInspector)){[void](Update-NpiTool -Force)};Start-Process (Find-NvidiaProfileInspector)}catch{Show-KMessage $_.Exception.Message 'NPI error' ([System.Windows.Forms.MessageBoxIcon]::Error)}})
    $nvRec.Add_Click({$nvPower.Checked=$true;$nvRefresh.Checked=$true;$nvTexture.Checked=$false;$nvVsync.Checked=$false;$nvPre.Checked=$false})
    $nvComp.Add_Click({$nvPower.Checked=$true;$nvRefresh.Checked=$true;$nvTexture.Checked=$true;$nvVsync.Checked=$true;$nvPre.Checked=$false})
    $nvApply.Add_Click({try{$g=[string]$gameChoice.SelectedItem;$msg=Apply-NpiCustomPreset -Game $g -CustomExe $customExe.Text -PowerMax $nvPower.Checked -HighestRefresh $nvRefresh.Checked -TextureHighPerf $nvTexture.Checked -VSyncOff $nvVsync.Checked -PreRendered1 $nvPre.Checked;Show-KMessage $msg 'NVIDIA profile applied'}catch{Show-KMessage $_.Exception.Message 'NVIDIA profile error' ([System.Windows.Forms.MessageBoxIcon]::Error)}})

    $populateNic={try{$propCombo.Items.Clear();$valueCombo.Items.Clear();$currentNic.Text='Current: -';$an=[string]$adapterCombo.SelectedItem;if(-not $an){return};foreach($p in Get-KNicTunableProperties -AdapterName $an){[void]$propCombo.Items.Add($p.DisplayName)};if($propCombo.Items.Count -gt 0){$propCombo.SelectedIndex=0}}catch{$netResult.Text="NIC property refresh failed: $($_.Exception.Message)"}}
    $populateNicValue={try{$valueCombo.Items.Clear();$an=[string]$adapterCombo.SelectedItem;$dn=[string]$propCombo.SelectedItem;if(-not $an -or -not $dn){return};$p=Get-NetAdapterAdvancedProperty -Name $an -DisplayName $dn -ErrorAction Stop|Select-Object -First 1;$currentNic.Text="Current: $($p.DisplayValue)";foreach($v in @($p.ValidDisplayValues)){if($v){[void]$valueCombo.Items.Add([string]$v)}};if($valueCombo.Items.Count -gt 0){$match=-1;for($i=0;$i -lt $valueCombo.Items.Count;$i++){if(([string]$valueCombo.Items[$i]) -eq [string]$p.DisplayValue){$match=$i;break}};$valueCombo.SelectedIndex=if($match -ge 0){$match}else{0}}}catch{$currentNic.Text="Current: error - $($_.Exception.Message)"}}
    $adapterCombo.Add_SelectedIndexChanged($populateNic);$propCombo.Add_SelectedIndexChanged($populateNicValue);$refreshNic.Add_Click($populateNic)
    $scanNic.Add_Click({try{$netResult.Text=Get-NicReport}catch{$netResult.Text=$_.Exception.Message}})
    $applyNicValue.Add_Click({try{$an=[string]$adapterCombo.SelectedItem;$dn=[string]$propCombo.SelectedItem;$dv=[string]$valueCombo.SelectedItem;if(-not $an -or -not $dn -or -not $dv){throw 'Choose an adapter, property and value.'};$b=Set-KNicAdvancedValue -AdapterName $an -DisplayName $dn -DisplayValue $dv;Show-KMessage "Applied $dn = $dv`r`nBackup: $b" 'NIC setting';Invoke-Command $populateNicValue}catch{Show-KMessage $_.Exception.Message 'NIC setting error' ([System.Windows.Forms.MessageBoxIcon]::Error)}})
    $applyLatencyNic.Add_Click({try{$an=[string]$adapterCombo.SelectedItem;$msg=Apply-KNicLatencyPreset -AdapterName $an -InterruptModeration $netIm.Checked -EnergyEfficient $netEee.Checked -FlowControl $netFlow.Checked -LargeSendOffload $netLso.Checked -DisableRsc $netRsc.Checked;Show-KMessage $msg 'NIC experiment';Invoke-Command $populateNicValue}catch{Show-KMessage $_.Exception.Message 'NIC experiment error' ([System.Windows.Forms.MessageBoxIcon]::Error)}})
    $restoreNic.Add_Click({try{$msg=Restore-KLatestNicBackup;Show-KMessage $msg 'NIC restore';Invoke-Command $populateNic}catch{Show-KMessage $_.Exception.Message 'NIC restore error' ([System.Windows.Forms.MessageBoxIcon]::Error)}})
    $factoryNic.Add_Click({try{$an=[string]$adapterCombo.SelectedItem;$msg=Reset-KNicDriverDefaults -AdapterName $an;Show-KMessage $msg 'NIC driver defaults';Invoke-Command $populateNic}catch{Show-KMessage $_.Exception.Message 'NIC defaults error' ([System.Windows.Forms.MessageBoxIcon]::Error)}})
    $stabilityTune.Add_Click({try{$an=[string]$adapterCombo.SelectedItem;if(-not $an){throw 'Choose a network adapter first.'};$ans=[System.Windows.Forms.MessageBox]::Show("FOCS will apply a stability-first Ethernet profile, restart the adapter, measure it, and automatically roll back if it performs worse. Discord/Fortnite may disconnect briefly. Continue?",'FOCS Fortnite Stability Tune',[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Information);if($ans -ne [System.Windows.Forms.DialogResult]::Yes){return};$form.UseWaitCursor=$true;$r=Invoke-FocsFortniteStabilityTune -AdapterName $an -Mode ([string]$labDepth.SelectedItem) -CustomTarget $labTarget.Text -OutputBox $netResult;$state=if($r.Kept){'KEPT'}else{'ROLLED BACK'};Show-KMessage ("Stability test finished: $state`r`nBefore loss: $([math]::Round([double]$r.Before.InternetLoss,2))% -> After: $([math]::Round([double]$r.After.InternetLoss,2))%`r`nBefore P95: $([math]::Round([double]$r.Before.InternetP95,1)) ms -> After: $([math]::Round([double]$r.After.InternetP95,1)) ms`r`nNIC errors/discards after: $([math]::Round([double]$r.After.LocalErrors,0)) / $([math]::Round([double]$r.After.LocalDiscards,0))") 'FOCS Fortnite Stability Tune'}catch{$detail=$_.Exception.Message;if($_.ScriptStackTrace){$detail+="`r`n`r`n"+$_.ScriptStackTrace};Write-KLog "Fortnite stability tune failed: $detail";Show-KMessage $detail 'Fortnite Stability Tune error' ([System.Windows.Forms.MessageBoxIcon]::Error)}finally{$form.UseWaitCursor=$false;Invoke-Command $populateNic}})
    $autoTune.Add_Click({
        if (-not (Enter-FocsBusy 'Network tuning lab')) {
            Show-KMessage 'FOCS is already running a network measurement. Wait for it to finish before starting another.' 'FOCS is busy' ([System.Windows.Forms.MessageBoxIcon]::Information)
            return
        }
        try {
            $an = [string]$adapterCombo.SelectedItem
            if (-not $an) { throw 'Choose a network adapter first.' }
            $ans = [System.Windows.Forms.MessageBox]::Show(
                "FOCS will restart the selected network adapter several times while it measures different settings. Discord and games may disconnect during the test. Continue?",
                'FOCS Network Performance Lab',
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Information)
            if ($ans -ne [System.Windows.Forms.DialogResult]::Yes) { return }
            $p = Start-FocsNetworkAutoTune -AdapterName $an -Mode ([string]$labDepth.SelectedItem) -CustomTarget $labTarget.Text -OutputBox $netResult
            Show-KMessage ("Best measured network profile saved.`r`nScore: $([math]::Round([double]$p.FinalScore,1))`r`nInternet loss: $([math]::Round([double]$p.FinalInternetLoss,2))%`r`nGaming P95: $([math]::Round([double]$p.FinalGamingP95,1)) ms ($($p.FinalGamingState))") 'FOCS Network Performance Lab'
        } catch {
            $detail = $_.Exception.Message
            if ($_.ScriptStackTrace) { $detail += "`r`n`r`n" + $_.ScriptStackTrace }
            Write-KLog "Network Performance Lab failed: $detail"
            if ($netResult) { $netResult.Text = "Network Performance Lab failed:`r`n$detail" }
            Show-KMessage $detail 'Network Performance Lab error' ([System.Windows.Forms.MessageBoxIcon]::Error)
        } finally {
            Exit-FocsBusy
            Invoke-Command $populateNic
        }
    })
    $applyBest.Add_Click({try{$an=[string]$adapterCombo.SelectedItem;Show-KMessage (Apply-FocsSavedNetworkProfile -AdapterName $an) 'FOCS saved network profile';Invoke-Command $populateNic}catch{Show-KMessage $_.Exception.Message 'Saved profile error' ([System.Windows.Forms.MessageBoxIcon]::Error)}})
    $netTest.Add_Click({try{$form.UseWaitCursor=$true;$netResult.Text=Format-NetworkLatency (Test-NetworkLatency -HostName $netHost.Text -Count 20)}catch{$netResult.Text="Network test failed: $($_.Exception.Message)"}finally{$form.UseWaitCursor=$false}})
    $gatewayTest.Add_Click({try{$form.UseWaitCursor=$true;$gw=Get-FocsDefaultGateway;if(-not $gw){throw 'Default gateway not found.'};$netResult.Text=Format-NetworkLatency (Test-NetworkLatency -HostName $gw -Count 20)}catch{$netResult.Text="Gateway test failed: $($_.Exception.Message)"}finally{$form.UseWaitCursor=$false}})
    Invoke-Command $populateNic

    $gamingTest.Add_Click({
        if (-not (Enter-FocsBusy 'Low latency gaming health')) { Show-KMessage 'FOCS is already running a network measurement.' 'FOCS is busy' ([System.Windows.Forms.MessageBoxIcon]::Information); return }
        try{
            $an=[string]$adapterCombo.SelectedItem;if(-not $an){throw 'Choose a network adapter first.'}
            $up=if($bbUpload.Value -gt $bbUpload.Minimum){[double]$bbUpload.Value}else{0.0}
            $ans=[System.Windows.Forms.MessageBox]::Show('Gaming Health intentionally creates download and upload load so it can measure P95 tail latency under pressure. Games/Discord may lag during the test. Continue?','FOCS Low Latency Gaming Health',[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Information)
            if($ans -ne [System.Windows.Forms.DialogResult]::Yes){return}
            $netResult.Text=Invoke-FocsLowLatencyGamingTest -AdapterName $an -CustomTarget $labTarget.Text -ExpectedUploadMbps $up -OutputBox $netResult
        }catch{$detail=$_.Exception.Message;if($_.ScriptStackTrace){$detail+="`r`n`r`n"+$_.ScriptStackTrace};$netResult.Text="Gaming health failed:`r`n$detail";Write-KLog $netResult.Text;Show-KMessage $detail 'Gaming Health error' ([System.Windows.Forms.MessageBoxIcon]::Error)}finally{Exit-FocsBusy}
    })
    $bufferTest.Add_Click({
        if (-not (Enter-FocsBusy 'Loaded-latency test')) {
            Show-KMessage 'FOCS is already running a network measurement. Wait for it to finish before starting another.' 'FOCS is busy' ([System.Windows.Forms.MessageBoxIcon]::Information)
            return
        }
        try {
            $an = [string]$adapterCombo.SelectedItem
            if ($bbUpload.Value -eq $bbUpload.Minimum) { throw 'Enter your real measured upload speed (from a recent internet speed test) in the box above first. FOCS uses it to judge whether the upload load actually saturated the line.' }
            $ans = [System.Windows.Forms.MessageBox]::Show(
                'This test intentionally saturates download and then upload, and may transfer a noticeable amount of data. Each phase now runs until its latency probe has finished rather than for a fixed ten seconds, so allow roughly 30 to 60 seconds per phase. Continue?',
                'FOCS Loaded Latency Test',
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Information)
            if ($ans -ne [System.Windows.Forms.DialogResult]::Yes) { return }
            $netResult.Text = Invoke-FocsBufferbloatTest -AdapterName $an -OutputBox $netResult -ExpectedUploadMbps ([double]$bbUpload.Value)
        } catch {
            $netResult.Text = "Loaded-latency test failed: $($_.Exception.Message)"
            Write-KLog $netResult.Text
        } finally {
            Exit-FocsBusy
        }
    })
    $bufferReduce.Add_Click({
        if (-not (Enter-FocsBusy 'Bufferbloat reducer')) {
            Show-KMessage 'FOCS is already running a network measurement. Wait for it to finish before starting another.' 'FOCS is busy' ([System.Windows.Forms.MessageBoxIcon]::Information)
            return
        }
        try {
            $an = [string]$adapterCombo.SelectedItem
            if (-not $an) { throw 'Choose a network adapter first.' }
            if ($bbUpload.Value -eq $bbUpload.Minimum) { throw 'Enter your real measured upload speed (from a recent internet speed test) in the box above first. Every candidate cap is calculated as a percentage of this number, so a wrong value tunes against a fictitious line rate.' }
            $mbps = [double]$bbUpload.Value
            $ans = [System.Windows.Forms.MessageBox]::Show(
                ("FOCS will create and remove its own Windows QoS policy while testing several outbound caps based on {0:N1} Mbps upload.`r`n`r`nEach cap is measured more than once and the order is randomised, so allow several minutes. Upload is intentionally saturated throughout.`r`n`r`nAll trial caps are temporary ActiveStore policies. FOCS keeps one only if the final full A/B test improves absolute gaming P95 without loss or download regression. Router-side SQM remains the stronger whole-network fix.`r`n`r`nContinue?" -f $mbps),
                'FOCS P95 Bufferbloat Reducer',
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Information)
            if ($ans -ne [System.Windows.Forms.DialogResult]::Yes) { return }
            $netResult.Text = Invoke-FocsBufferbloatReducer -AdapterName $an -UploadMbps $mbps -OutputBox $netResult -Repeats 2
        } catch {
            $detail = $_.Exception.Message
            if ($_.ScriptStackTrace) { $detail += "`r`n`r`n" + $_.ScriptStackTrace }
            $netResult.Text = "P95 bufferbloat reducer failed:`r`n$detail"
            Write-KLog $netResult.Text
            Show-KMessage $detail 'P95 Bufferbloat Reducer error' ([System.Windows.Forms.MessageBoxIcon]::Error)
        } finally {
            $bbStatus.Text = (Get-FocsBufferbloatGuardStatus).Text
            Exit-FocsBusy
        }
    })
    $bufferRemove.Add_Click({
        try {
            $netResult.Text = Remove-FocsBufferbloatUploadGuard
        } catch {
            $netResult.Text = "Remove upload guard failed: $($_.Exception.Message)"
            Write-KLog $netResult.Text
        } finally {
            $bbStatus.Text = (Get-FocsBufferbloatGuardStatus).Text
        }
    })
    $bbRevert.Add_Click({
        if (-not (Enter-FocsBusy 'Full network revert')) {
            Show-KMessage 'FOCS is already running a network measurement. Wait for it to finish before starting another.' 'FOCS is busy' ([System.Windows.Forms.MessageBoxIcon]::Information)
            return
        }
        try {
            $an = [string]$adapterCombo.SelectedItem
            if (-not $an) { throw 'Choose a network adapter first.' }
            $ans = [System.Windows.Forms.MessageBox]::Show(
                "This removes the FOCS upload guard if one is active and resets $an to its driver defaults. The adapter will briefly disconnect. Continue?",
                'FOCS Full Network Revert',
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Warning)
            if ($ans -ne [System.Windows.Forms.DialogResult]::Yes) { return }
            $netResult.Text = Invoke-FocsNetworkFullRevert -AdapterName $an -OutputBox $netResult
        } catch {
            $netResult.Text = "Full network revert failed: $($_.Exception.Message)"
            Write-KLog $netResult.Text
            Show-KMessage $_.Exception.Message 'Full network revert error' ([System.Windows.Forms.MessageBoxIcon]::Error)
        } finally {
            $bbStatus.Text = (Get-FocsBufferbloatGuardStatus).Text
            Exit-FocsBusy
        }
    })
    $openRouter.Add_Click({try{$gw=Get-FocsDefaultGateway;if(-not $gw){throw 'Default gateway not found.'};Start-Process ("http://"+$gw)}catch{Show-KMessage $_.Exception.Message 'Open router' ([System.Windows.Forms.MessageBoxIcon]::Warning)}})
    $runLatency.Add_Click({try{$form.UseWaitCursor=$true;$latOut.Text=Invoke-FocsLatencyDoctor -Seconds ([int]$latSeconds.Value) -OutputBox $latOut}catch{$latOut.Text="Latency Doctor failed: $($_.Exception.Message)";Write-KLog $latOut.Text}finally{$form.UseWaitCursor=$false}})
    $installWpt.Add_Click({try{$form.UseWaitCursor=$true;$x=Install-FocsWpt;Show-KMessage "Windows Performance Toolkit ready:`r`n$x" 'WPT installed'}catch{Show-KMessage $_.Exception.Message 'WPT install error' ([System.Windows.Forms.MessageBoxIcon]::Error)}finally{$form.UseWaitCursor=$false}})
    $openTrace.Add_Click({try{if(-not $script:LatestLatencyTrace -or -not(Test-Path -LiteralPath $script:LatestLatencyTrace)){throw 'Run Latency Doctor first.'};$wpa=Get-FocsWpa;if($wpa){Start-Process -FilePath $wpa -ArgumentList ('"'+$script:LatestLatencyTrace+'"')}else{Start-Process explorer.exe (Split-Path -Parent $script:LatestLatencyTrace)}}catch{Show-KMessage $_.Exception.Message 'Open trace' ([System.Windows.Forms.MessageBoxIcon]::Warning)}})
    $refreshGfx.Add_Click({try{$gfxOut.Text=Get-FocsDisplayGraphicsReport}catch{$gfxOut.Text=$_.Exception.Message}});$openGraphics.Add_Click({try{Start-Process 'ms-settings:display-advancedgraphics'}catch{}})
    $mousePoll.Add_Click({try{Show-KMessage 'For the next 5 seconds, move the mouse continuously and quickly across the desk.' 'Mouse polling test';$mouseResult.Text=Invoke-FocsMousePollingTest -Seconds 5}catch{$mouseResult.Text="Mouse polling test failed: $($_.Exception.Message)"}})
    $compRefresh.Add_Click({try{$an=[string]$adapterCombo.SelectedItem;$compOut.Text=Get-FocsCompatibilityReport -Controls $controls -AdapterName $an}catch{$compOut.Text=$_.Exception.Message}})
    try{$gfxOut.Text=Get-FocsDisplayGraphicsReport}catch{}

    $svcSafe.Add_Click({$safe=@('DiagTrack','dmwappushservice','MapsBroker','Fax','RemoteRegistry','RetailDemo','PhoneSvc','WalletService','WMPNetworkSvc','lfsvc','CscService');for($i=0;$i -lt $svcList.Items.Count;$i++){$n=([string]$svcList.Items[$i] -split ' - ',2)[0];$svcList.SetItemChecked($i,($safe -contains $n))}});$svcClear.Add_Click({for($i=0;$i -lt $svcList.Items.Count;$i++){$svcList.SetItemChecked($i,$false)}});$svcApply.Add_Click({try{$mode=[string]$svcMode.SelectedItem;$b=Set-KSelectedServices -List $svcList -Mode $mode;Show-KMessage "Service changes applied as $mode.`r`nBackup: $b" 'Services'}catch{Show-KMessage $_.Exception.Message 'Service error' ([System.Windows.Forms.MessageBoxIcon]::Error)}})

    $selectReg={param([string]$Preset)for($i=0;$i -lt $regList.Items.Count;$i++){$regList.SetItemChecked($i,$false)};$wanted=if($Preset -eq 'Competitive'){@('Disable Microsoft consumer experiences','Disable Windows tips, suggestions and silent app suggestions','Disable advertising ID and tailored experiences','Disable Edge Startup Boost + background mode','Disable Widgets + hide taskbar Widgets button','Disable Bing web suggestions in Windows Search','Disable transparency effects')}else{@('Disable Microsoft consumer experiences','Disable Windows tips, suggestions and silent app suggestions','Disable advertising ID and tailored experiences','Disable Edge Startup Boost + background mode','Disable Widgets + hide taskbar Widgets button')};for($i=0;$i -lt $regList.Items.Count;$i++){if($wanted -contains [string]$regList.Items[$i]){$regList.SetItemChecked($i,$true)}}}
    $regRecommended.Add_Click({& $selectReg 'Recommended'});$regCompetitive.Add_Click({& $selectReg 'Competitive'});$regClear.Add_Click({for($i=0;$i -lt $regList.Items.Count;$i++){$regList.SetItemChecked($i,$false)}});$regApply.Add_Click({try{$b=Apply-KRegistryList -List $regList;if($b){Show-KMessage "Selected registry/privacy tweaks applied.`r`nBackup: $b" 'Registry tweaks'}else{Show-KMessage 'No registry changes were made.' 'Registry tweaks'}}catch{Show-KMessage $_.Exception.Message 'Registry error' ([System.Windows.Forms.MessageBoxIcon]::Error)}});$hagsEnable.Add_Click({try{Apply-HagsChoice -Choice 'Enable HAGS'}catch{Show-KMessage $_.Exception.Message 'HAGS error' ([System.Windows.Forms.MessageBoxIcon]::Error)}});$hagsDisable.Add_Click({try{Apply-HagsChoice -Choice 'Disable HAGS'}catch{Show-KMessage $_.Exception.Message 'HAGS error' ([System.Windows.Forms.MessageBoxIcon]::Error)}});$bcdScan.Add_Click({$regOut.Text=Get-BcdTimerReport});$msiScan.Add_Click({$regOut.Text=Get-MsiReport})

    $createBackup.Add_Click({try{$f=New-KBackup;Show-KMessage "Backup created:`r`n$f"}catch{Show-KMessage $_.Exception.Message 'Backup error' ([System.Windows.Forms.MessageBoxIcon]::Error)}});$openBackup.Add_Click({try{Start-Process explorer.exe $script:BackupRoot}catch{}});$exportReport.Add_Click({try{$p=Export-DiagnosticReport;Show-KMessage "Report saved:`r`n$p"}catch{Show-KMessage $_.Exception.Message 'Report error' ([System.Windows.Forms.MessageBoxIcon]::Error)}});$restoreLatest.Add_Click({try{$latest=Get-ChildItem -LiteralPath $script:BackupRoot -Directory -ErrorAction Stop|Sort-Object LastWriteTime -Descending|Select-Object -First 1;if(-not $latest){throw 'No backup found.'};$restore=Join-Path $latest.FullName 'RESTORE_FOCS.ps1';if(-not(Test-Path -LiteralPath $restore)){throw 'Latest backup has no restore script.'};Start-Process powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$restore+'"')) -Verb RunAs}catch{Show-KMessage $_.Exception.Message 'Restore error' ([System.Windows.Forms.MessageBoxIcon]::Error)}})

    $installLat.Add_Click({try{$form.UseWaitCursor=$true;$exe=Install-LatencyMonTool;Update-ToolStatusLabels;Show-KMessage "LatencyMon installed/updated:`r`n$exe"}catch{Show-KMessage $_.Exception.Message 'LatencyMon install error' ([System.Windows.Forms.MessageBoxIcon]::Error)}finally{$form.UseWaitCursor=$false}});$launchLat.Add_Click({try{$exe=Get-LatencyMonInstalledExe;if(-not $exe){$exe=Install-LatencyMonTool};Start-Process $exe;Show-KMessage 'For a complete LatencyMon run, select all CPUs. For cleaner DPC totals, disable LatencyMon measurement features that inject their own DPC/timer work where those options are available in your installed version. FOCS Latency Doctor uses a separate WPR trace for comparison.' 'LatencyMon diagnostic guidance'}catch{Show-KMessage $_.Exception.Message 'LatencyMon error' ([System.Windows.Forms.MessageBoxIcon]::Error)}})
    $refreshGameList={
        param([object[]]$Games,[string]$Status)
        $gameCombo.Items.Clear();$script:Ui.GameCatalog=@($Games)
        foreach($g in @($script:Ui.GameCatalog)){[void]$gameCombo.Items.Add(("{0}  [{1}]  - {2}" -f $g.Name,$g.Exe,$g.Source))}
        if($gameCombo.Items.Count -gt 0){$gameCombo.SelectedIndex=0;$benchOut.Text="$Status`r`nFound $($gameCombo.Items.Count) executable candidate(s). If a game has several EXEs, choose the one that is actually running while playing."}else{$benchOut.Text="$Status`r`nNo game executable candidates were found. Use RUNNING GAMES or BROWSE EXE."}
    }
    $scanGames.Add_Click({try{$form.UseWaitCursor=$true;$benchOut.Text='Scanning Windows game records and launcher libraries...';[System.Windows.Forms.Application]::DoEvents();$games=@(Get-FocsInstalledGames);& $refreshGameList $games 'Installed-game scan complete.'}catch{$benchOut.Text="Game scan failed: $($_.Exception.Message)";Write-KLog $benchOut.Text}finally{$form.UseWaitCursor=$false}})
    $runningGames.Add_Click({try{$games=@(Get-FocsRunningGameCandidates);& $refreshGameList $games 'Running-game scan complete.'}catch{$benchOut.Text="Running-game scan failed: $($_.Exception.Message)"}})
    $gameCombo.Add_SelectedIndexChanged({try{if($gameCombo.SelectedIndex -ge 0 -and $script:Ui.GameCatalog -and $gameCombo.SelectedIndex -lt $script:Ui.GameCatalog.Count){$g=$script:Ui.GameCatalog[$gameCombo.SelectedIndex];$benchProc.Text=[string]$g.Exe;$gamePathLabel.Text=("{0}: {1}" -f $g.Source,$g.Path)}}catch{}})
    $browseGameExe.Add_Click({try{$fd=New-Object System.Windows.Forms.OpenFileDialog;$fd.Filter='Game executable (*.exe)|*.exe|All files (*.*)|*.*';$fd.Title='Choose the actual game executable';if($fd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){$benchProc.Text=[IO.Path]::GetFileName($fd.FileName);$gamePathLabel.Text='Manual: '+$fd.FileName}}catch{Show-KMessage $_.Exception.Message 'Browse game EXE'}})
    $pmQuickTest.Add_Click({$oldTel=$script:BenchmarkTelemetryEnabled;try{$form.UseWaitCursor=$true;$proc=Resolve-FocsBenchmarkProcessName $benchProc.Text;if(-not(Find-PresentMon)){[void](Update-PresentMonTool -Force)};$script:BenchmarkTelemetryEnabled=$false;$csv=Start-PresentMonCapture -ProcessName $proc -Seconds 5 -Label 'PM_TEST';$st=Analyze-PresentMonCsv -Path $csv;$benchOut.Text=("PRESENTMON TEST OK`r`nProcess: $proc`r`nFrames captured: $($st.Frames)`r`nAverage FPS: $([Math]::Round([double]$st.AvgFPS,2))`r`n`r`nConsole: $(Find-PresentMon)`r`nCSV: $csv")}catch{$benchOut.Text="PresentMon test failed:`r`n$($_.Exception.Message)";Write-KLog $benchOut.Text}finally{$script:BenchmarkTelemetryEnabled=$oldTel;$form.UseWaitCursor=$false}})
    $baseline.Add_Click({try{$form.UseWaitCursor=$true;$proc=Resolve-FocsBenchmarkProcessName $benchProc.Text;if(-not(Find-PresentMon)){[void](Update-PresentMonTool -Force)};if($telemetryCheck.Checked -and -not(Get-FocsLhmDll)){try{[void](Update-LibreHardwareMonitorTool)}catch{Write-KLog "Telemetry update unavailable: $($_.Exception.Message)"}};$script:BenchmarkTelemetryEnabled=$telemetryCheck.Checked;$oldPc=$controls.PcLatency.Checked;$controls.PcLatency.Checked=$pcLatency.Checked;$script:BaselineProcess=$proc;$script:BaselineSet=@(Start-FocsBenchmarkSet -ProcessName $proc -Seconds ([int]$benchSeconds.Value) -Label 'BASELINE' -Runs ([int]$benchRuns.Value) -OutputBox $benchOut);$benchOut.Text=Format-FocsBenchmarkSet $script:BaselineSet 'BASELINE';$controls.PcLatency.Checked=$oldPc}catch{$detail=$_.Exception.Message;if($_.ScriptStackTrace){$detail+="`r`n`r`n"+$_.ScriptStackTrace};$benchOut.Text="Baseline set failed:`r`n$detail";Write-KLog $benchOut.Text}finally{$form.UseWaitCursor=$false}})
    $after.Add_Click({try{$form.UseWaitCursor=$true;if(-not $script:BaselineSet -or $script:BaselineSet.Count -lt 2){throw 'Capture a baseline set first.'};$proc=Resolve-FocsBenchmarkProcessName $benchProc.Text;if($script:BaselineProcess -and $proc -ine $script:BaselineProcess){throw "Baseline was captured for $script:BaselineProcess, but the current selection is $proc. Use the same game process for both sets."};$script:BenchmarkTelemetryEnabled=$telemetryCheck.Checked;$oldPc=$controls.PcLatency.Checked;$controls.PcLatency.Checked=$pcLatency.Checked;$script:AfterSet=@(Start-FocsBenchmarkSet -ProcessName $proc -Seconds ([int]$benchSeconds.Value) -Label 'AFTER' -Runs ([int]$benchRuns.Value) -OutputBox $benchOut);$benchOut.Text=Compare-FocsBenchmarkSets -Baseline $script:BaselineSet -After $script:AfterSet;$controls.PcLatency.Checked=$oldPc}catch{$detail=$_.Exception.Message;if($_.ScriptStackTrace){$detail+="`r`n`r`n"+$_.ScriptStackTrace};$benchOut.Text="Comparison set failed:`r`n$detail";Write-KLog $benchOut.Text}finally{$form.UseWaitCursor=$false}})

    Set-KProfileSelection -Name 'Recommended';Show-KPage 'Home' $navHome;Update-ToolStatusLabels;$nvStatus.Text=if(Find-NvidiaProfileInspector){"Ready: $(Get-ManagedVersion $script:NpiRoot)"}else{'Not downloaded yet'}
    $form.Add_FormClosing({try{if($script:AutoUpdateTimer){$script:AutoUpdateTimer.Stop();$script:AutoUpdateTimer.Dispose();$script:AutoUpdateTimer=$null}}catch{}})
    $form.Add_Shown({try{if($script:AutoUpdateTimer){$script:AutoUpdateTimer.Stop();$script:AutoUpdateTimer.Dispose()};$script:AutoUpdateTimer=New-Object System.Windows.Forms.Timer;$script:AutoUpdateTimer.Interval=900;$script:AutoUpdateTimer.Add_Tick({try{if($script:AutoUpdateTimer){$script:AutoUpdateTimer.Stop();$script:AutoUpdateTimer.Dispose();$script:AutoUpdateTimer=$null};if(Test-ToolAutoUpdateDue){$form.UseWaitCursor=$true;try{$r=Update-ManagedTools;if($script:Ui.ToolsResult){$script:Ui.ToolsResult.Text=($r -replace "`r?`n",' | ')};Update-ToolStatusLabels;if($script:Ui.NvStatus){$script:Ui.NvStatus.Text=if(Find-NvidiaProfileInspector){"Ready: $(Get-ManagedVersion $script:NpiRoot)"}else{'Unavailable'}}}catch{Write-KLog "Automatic tool update failed: $($_.Exception.Message)"}finally{$form.UseWaitCursor=$false}}}catch{Write-KLog "Auto-update callback failed: $($_.Exception.Message)"}});$script:AutoUpdateTimer.Start()}catch{Write-KLog "Auto-update timer setup failed: $($_.Exception.Message)"}})
    try {
        # A reducer run that was killed mid-sweep used to leave a trial upload cap applied with
        # nothing on screen to explain the slower uploads. Find and clear it at launch.
        $orphanNotice = Resolve-FocsOrphanedBufferbloatGuard
        if ($orphanNotice) {
            $netResult.Text = $orphanNotice
            $bbStatus.Text = (Get-FocsBufferbloatGuardStatus).Text
            Show-KMessage $orphanNotice 'FOCS removed a leftover upload cap' ([System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    } catch { Write-KLog "Orphaned QoS guard check failed: $($_.Exception.Message)" }
    Write-KLog "FOCS v9.5.0 App Installer Build ready. GPU=$($system.GPU) Driver=$($system.Driver) Build=$($system.Build)"
    [void]$form.ShowDialog()
}

try {
    Start-KxttsGui
    exit 0
} catch {
    $msg = "Fatal startup error: $($_.Exception.Message)`r`n$($_.ScriptStackTrace)"
    try { Add-Content -LiteralPath $script:LogFile -Value $msg -Encoding UTF8 } catch {}
    try { Show-KMessage "$msg`r`n`r`nLog: $script:LogFile" 'FOCS Utility v9.5.0 - Fatal Error' ([System.Windows.Forms.MessageBoxIcon]::Error) } catch {}
    exit 1
}
