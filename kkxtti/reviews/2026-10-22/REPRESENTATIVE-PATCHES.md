# Eight representative patches

Proposed 2026-10-22; PowerShell 5.1 / C# 7.3, .NET Framework 4.8 syntax. **Only patch 1 is included in 3.4.0. Patches 2–8 require integration and validation.** No runtime tests of these proposals were executed.

## 1. Guard both direct preview mutation paths (A01)

Add at the beginning of the following methods, before busy/elevation/backend logic:

~~~diff
--- source/ControlCenter.cs
+++ source/ControlCenter.cs
@@
   async void ApplyControls(string[] ids,bool enabled,string title,string undoId=null) {
+   if(readOnlyPreview){Notice("Read-only preview","Settings changes and Undo are disabled in this session.");return;}
--- source/NetworkPage.cs
+++ source/NetworkPage.cs
@@
   async void ChangeNetwork(string[] ids,bool enabled,string title,string undoId) {
+   if(readOnlyPreview){Notice("Read-only preview","Adapter changes and Undo are disabled in this session.");return;}
~~~

Acceptance design: invoke both handlers through normal controls and Backups in preview with registry/NIC mutators denied; expect zero calls. This immediate fix does not replace a central typed operation dispatcher.

## 2. Refuse accidental cross-account user operations (A04)

InitiatingSid comes from the authenticated UI/IPC context captured before elevation, never from an imported file. This helper is not IPC authentication.

~~~powershell
function Assert-InitiatingUserContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$InitiatingSid,
        [Parameter(Mandatory=$true)]
        [ValidateSet('User','Machine')][string]$Scope
    )
    try { $sidObject = [Security.Principal.SecurityIdentifier]::new($InitiatingSid) }
    catch { throw 'Invalid initiating Windows account identity.' }
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    try { $executingSid = $identity.User.Value }
    finally { $identity.Dispose() }
    if ($Scope -eq 'User' -and $executingSid -cne $sidObject.Value) {
        throw 'This process is running as another account. Use the original unelevated window for account, app and game-file changes.'
    }
}
~~~

Call before resolving HKCU, Known Folders, per-user Appx or game paths. Machine operations separately authenticate authorization and journal both SIDs. Do not automatically load another user's hive. Future cases include same-user consent, alternate credentials and administrator protection with a different elevated SID.

## 3. Authorize Recall deletion at every write, including compensation (A05)

Replace direct Write-ControlValue calls in Apply/Undo/compensation with this wrapper. Pass the correct expected snapshot. Remove the existing preflight no-recall confirmation loop to avoid duplicate prompts; make the low-level writer private to this boundary.

~~~powershell
function Write-ControlValueReviewed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$Spec,
        [Parameter(Mandatory=$true)]$Value,
        [Parameter(Mandatory=$true)]$Expected
    )
    Assert-ControlWritable $Spec
    Assert-ControlValue $Value
    Assert-ControlValue $Expected
    $path = ([string]$Spec.Path).TrimEnd('\')
    $isRecall = (
        (Get-ControlProperty $Spec 'Hive' 'HKCU') -in @('HKLM','HKCU') -and
        $path -ieq 'Software\Policies\Microsoft\Windows\WindowsAI' -and
        [string]$Spec.Name -ieq 'DisableAIDataAnalysis'
    )
    if ($isRecall -and $Value.Exists -and
        $Value.Kind -ceq 'DWord' -and [long]$Value.Data -eq 1) {
        if (-not (Confirm-Action 'This write can permanently delete Recall snapshots. Policy Undo cannot recover them. Authorize this write?' 'DELETE')) {
            throw 'Recall deletion was not authorized. Recovery needs review.'
        }
    }
    if (-not (Test-ControlEqual (Read-ControlValue $Spec) $Expected)) {
        throw 'The setting changed during review; no write was made.'
    }
    Write-ControlValue $Spec $Value
    if (-not (Test-ControlEqual (Read-ControlValue $Spec) $Value)) {
        throw 'The setting did not match the requested value after writing.'
    }
}
~~~

Apply expects Before, Undo expects After, compensation expects the observed transaction target. Declined compensation must retain Recovery needed. Future HKU/SID targets require canonicalization before the same destructive check. This does not recover deleted data or make read/write atomic.

## 4. Verify all recovered rows, including those initially original (A06)

Reader/Equal callbacks are trusted engine code, never imported scripts.

~~~powershell
function Assert-AllRowsRestored {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][object[]]$Rows,
        [Parameter(Mandatory=$true)][scriptblock]$ReadCurrent,
        [Parameter(Mandatory=$true)][scriptblock]$Equal
    )
    if ($Rows.Count -eq 0) { throw 'Empty recovery transaction.' }
    $conflicts = New-Object 'Collections.Generic.List[string]'
    foreach ($row in $Rows) {
        $current = & $ReadCurrent $row
        if (-not (& $Equal $current $row.Before)) {
            $conflicts.Add([string]$row.Id)
        }
    }
    if ($conflicts.Count -ne 0) {
        throw ('Final recovery verification failed: ' + ($conflicts -join ', '))
    }
}
~~~

Registry integration, before the final status write:

~~~powershell
$reader = { param($row) Read-ControlValue (Get-ControlSpec $row) }
$equal = { param($a,$b) Test-ControlEqual $a $b }
Assert-AllRowsRestored -Rows @($saved.Journal.Rows) -ReadCurrent $reader -Equal $equal
# Only now persist Status='Undone'.
~~~

Refactor lower-level row executors so a subset cannot mark the full transaction Undone. DNS needs mode/family/adapter validation, NIC needs current hardware/driver validation, and game recovery must reopen the file. Outside changes after verification remain possible.

## 5. Unique temporary file, flushed bytes and retained previous revision (A07)

Caller already holds the transaction/resource lock and validates expected revision, directory ownership/ancestry, schema and digest. This primitive does not solve attacker-writable directories or filesystem races.

~~~powershell
function Save-JournalBytes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Json
    )
    $full = [IO.Path]::GetFullPath($Path)
    $directory = [IO.Path]::GetDirectoryName($full)
    if (-not [IO.Directory]::Exists($directory)) { throw 'Approved directory missing.' }
    $bytes = ([Text.UTF8Encoding]::new($false,$true)).GetBytes($Json)
    if ($bytes.Length -gt 2MB) { throw 'Journal exceeds limit.' }
    $token = [Guid]::NewGuid().ToString('N')
    $temporary = [IO.Path]::Combine($directory,'.journal-' + $token + '.tmp')
    $backup = [IO.Path]::Combine($directory,'.journal-' + $token + '.previous')
    $stream = $null
    $published = $false
    try {
        $stream = [IO.FileStream]::new(
            $temporary,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,
            [IO.FileShare]::None,4096,[IO.FileOptions]::WriteThrough)
        $stream.Write($bytes,0,$bytes.Length)
        $stream.Flush($true)
        $stream.Dispose()
        $stream = $null
        if ([IO.File]::Exists($full)) {
            [IO.File]::Replace($temporary,$full,$backup,$false)
        } else {
            [IO.File]::Move($temporary,$full)
        }
        $published = $true
    } finally {
        if ($null -ne $stream) { $stream.Dispose() }
        if (-not $published -and [IO.File]::Exists($temporary)) {
            [IO.File]::Delete($temporary)
        }
    }
}
~~~

Keep previous versions under a bounded validated retention policy. Flush/replace improves persistence but is not a universal power-loss guarantee. Canonicalization/HMAC and handle-based identity protection are separate requirements.

## 6. Explicit Registry64 and unexpanded typed reads (A09)

Compatible with the current snapshot shape, including signed .NET DWord/QWord values. V2 unsigned decimal strings need explicit conversion. Apply the same OpenBaseKey view and disposal pattern to the writer.

~~~powershell
function Read-ControlValue64 {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]$Spec)
    $hiveName = Get-ControlProperty $Spec 'Hive' 'HKCU'
    $hive = switch ($hiveName) {
        'HKCU' { [Microsoft.Win32.RegistryHive]::CurrentUser }
        'HKLM' { [Microsoft.Win32.RegistryHive]::LocalMachine }
        'HKU'  { [Microsoft.Win32.RegistryHive]::Users }
        default { throw 'Unsupported hive.' }
    }
    $root = $null
    $key = $null
    try {
        $root = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
            $hive,[Microsoft.Win32.RegistryView]::Registry64)
        $key = $root.OpenSubKey([string]$Spec.Path,$false)
        if ($null -eq $key -or $key.GetValueNames() -notcontains [string]$Spec.Name) {
            return [pscustomobject]@{Exists=$false;Kind='DWord';Data=$null}
        }
        $kind = $key.GetValueKind([string]$Spec.Name).ToString()
        if ($kind -notin @('DWord','QWord','String','ExpandString','MultiString','Binary')) {
            throw ('Unsupported registry kind: ' + $kind)
        }
        $data = $key.GetValue([string]$Spec.Name,$null,
            [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        return [pscustomobject]@{Exists=$true;Kind=$kind;Data=$data}
    } finally {
        if ($null -ne $key) { $key.Dispose() }
        if ($null -ne $root) { $root.Dispose() }
    }
}
~~~

Validate identity before HKCU. Future fixtures cover default value names, empty arrays, ExpandString, high-bit DWORDs and 32-bit host entry. Reject unknown kinds instead of silently coercing them.

## 7. Bound downloads while copying, before ZIP extraction (A14)

C# helper for the installer. Caller owns both streams and imposes HTTP origin/status/content-encoding/length checks, connection/read timeout and a fresh private output. A synchronous Read can remain blocked until the transport timeout.

~~~csharp
public static long CopyBounded(
    System.IO.Stream input,
    System.IO.Stream output,
    long maximumBytes,
    System.Threading.CancellationToken cancellation)
{
    if (input == null || output == null)
        throw new System.ArgumentNullException();
    if (maximumBytes <= 0)
        throw new System.ArgumentOutOfRangeException("maximumBytes");
    byte[] buffer = new byte[65536];
    long total = 0;
    for (;;)
    {
        cancellation.ThrowIfCancellationRequested();
        int read = input.Read(buffer, 0, buffer.Length);
        if (read == 0) break;
        if ((long)read > maximumBytes - total)
            throw new System.IO.InvalidDataException("Download exceeds byte limit.");
        output.Write(buffer, 0, read);
        total += read;
    }
    cancellation.ThrowIfCancellationRequested();
    return total;
}
~~~

On failure remove only the new partial output. Preserve all generation/digest and archive path/count/decompression limits; this helper is not an authenticity check.

## 8. Preserve explicit p99 and worst-1%-mean definitions (A15)

Pure metric helper. Caller preselects the producer/metric/time window; never silently trim slow frames. This is not a repeated-run significance test.

~~~csharp
public sealed class FrameTailMetrics
{
    public double P99Milliseconds { get; private set; }
    public double P99EquivalentFps { get; private set; }
    public double WorstOnePercentMeanMilliseconds { get; private set; }
    public double WorstOnePercentMeanEquivalentFps { get; private set; }
    public int TailSamples { get; private set; }

    public static FrameTailMetrics Calculate(
        System.Collections.Generic.IEnumerable<double> milliseconds)
    {
        if (milliseconds == null) throw new System.ArgumentNullException("milliseconds");
        var values = new System.Collections.Generic.List<double>(milliseconds);
        if (values.Count == 0) throw new System.ArgumentException("No frame intervals.");
        foreach (double x in values)
            if (double.IsNaN(x) || double.IsInfinity(x) || x <= 0)
                throw new System.ArgumentException("Intervals must be finite and positive.");
        values.Sort();
        int rank = System.Math.Max(1, (int)System.Math.Ceiling(0.99 * values.Count));
        int count = System.Math.Max(1, (int)System.Math.Ceiling(0.01 * values.Count));
        double tailMean = 0.0;
        int seen = 0;
        for (int i = values.Count - count; i < values.Count; ++i)
        {
            ++seen;
            tailMean += (values[i] - tailMean) / seen;
        }
        double p99 = values[rank - 1];
        return new FrameTailMetrics {
            P99Milliseconds = p99,
            P99EquivalentFps = 1000.0 / p99,
            WorstOnePercentMeanMilliseconds = tailMean,
            WorstOnePercentMeanEquivalentFps = 1000.0 / tailMean,
            TailSamples = count
        };
    }
}
~~~

The baseline already distinguishes nearest-rank p99 from a worst-tail mean. Retain that distinction in labels/exports; do not call it an arithmetic bug. Show insufficient-sample warnings for tiny tails. Add the capture semantics and repeated-block uncertainty in STATISTICS-SPEC.md before declaring an improvement.
