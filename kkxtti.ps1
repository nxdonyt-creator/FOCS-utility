# KKxtti debloat utility 3.3.0 - inspect this script before remote execution.
# Source and release: https://github.com/nxdonyt-creator/FOCS-utility/tree/main/kkxtti
# This launcher opens the UI without applying tweaks or requesting elevation.
& {
 $ErrorActionPreference='Stop'
 Set-StrictMode -Version 2
# Reviewed bootstrap implementation; also embedded in the public kkxtti.ps1.
# Compatible with Windows PowerShell 5.1. No Windows tweaks or auto-elevation.
function Assert-KKxttiWindows {
 if(-not [Environment]::Is64BitOperatingSystem){throw 'KKxtti requires 64-bit Windows 11.'}
 if(-not (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion')){throw 'KKxtti requires Windows.'}
 $build=[int](Get-ItemPropertyValue -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name CurrentBuildNumber)
 if($build -lt 22000){throw 'KKxtti requires Windows 11 (build 22000 or newer).'}
 $processors=@(Get-CimInstance Win32_Processor -ErrorAction Stop)
 if(-not $processors.Count -or @($processors | Where-Object Architecture -ne 9).Count){throw 'This KKxtti release supports x64 Intel/AMD PCs; ARM64 is not supported.'}
 $release=[int](Get-ItemPropertyValue -LiteralPath 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release)
 if($release -lt 528040){throw 'Install .NET Framework 4.8 or newer through Windows first.'}
 if(-not(Test-Path -LiteralPath (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'))){throw 'Windows PowerShell 5.1 is required by the native interface.'}
}
function Assert-KKxttiRelativePath([string]$Relative) {
 if([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative) -or $Relative -match '[:\x00-\x1F]'){throw 'Invalid package path.'}
 $segments=($Relative.Replace('/','\')) -split '\\'
 foreach($segment in $segments){if(-not $segment -or $segment -in @('.','..') -or $segment.TrimEnd(' ','.') -cne $segment -or $segment -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?$'){throw 'Invalid package path segment.'}}
}
function Assert-KKxttiDirectory([string]$Path,[string]$Root) {
 $boundary=[IO.Path]::GetFullPath($Root).TrimEnd('\');$full=[IO.Path]::GetFullPath($Path)
 if(-not($full.Equals($boundary,[StringComparison]::OrdinalIgnoreCase) -or $full.StartsWith($boundary+'\',[StringComparison]::OrdinalIgnoreCase))){throw 'Package path escaped its destination.'}
 $node=$full
 while($node){if(Test-Path -LiteralPath $node){if((Get-Item -LiteralPath $node -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Package location contains a link or junction.'}};$parent=[IO.Path]::GetDirectoryName($node);if($parent -eq $node){break};$node=$parent}
}
function Get-KKxttiManifest([string]$Directory,[string]$ManifestSha256) {
 $manifest=Join-Path $Directory 'SHA256SUMS.txt';Assert-KKxttiDirectory $manifest $Directory
 if(-not(Test-Path -LiteralPath $manifest -PathType Leaf) -or (Get-Item -LiteralPath $manifest).Length -gt 256KB){throw 'Release hash manifest is missing or too large.'}
 if((Get-FileHash -LiteralPath $manifest -Algorithm SHA256).Hash -cne $ManifestSha256){throw 'Release hash manifest does not match the pinned launcher.'}
 $seen=@{};$rows=@()
 foreach($line in Get-Content -LiteralPath $manifest -Encoding UTF8){
  if($line -cnotmatch '^(?<Hash>[A-F0-9]{64})  (?<Path>.+)$'){throw 'Invalid release hash manifest.'}
  $relative=$Matches.Path;Assert-KKxttiRelativePath $relative
  $key=$relative.Replace('/','\')
  if($seen.ContainsKey($key) -or $key -ieq 'SHA256SUMS.txt' -or $key -match '^(?i:State)(\\|$)'){throw 'Duplicate or reserved manifest path.'}
  $seen[$key]=$true;$rows+=[pscustomobject]@{Relative=$key;Hash=$Matches.Hash}
 }
 if($rows.Count -lt 1 -or $rows.Count -gt 1000 -or -not $seen.ContainsKey('KKxtti debloat utility.exe')){throw 'Invalid release file inventory.'}
 $rows
}
function Test-KKxttiRelease([string]$Directory,[string]$ManifestSha256) {
 Assert-KKxttiDirectory $Directory $Directory
 $rows=@(Get-KKxttiManifest $Directory $ManifestSha256);$allowed=@{'SHA256SUMS.txt'=$true}
 foreach($row in $rows){
  $path=Join-Path $Directory $row.Relative;Assert-KKxttiDirectory $path $Directory
  if(-not(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $row.Hash){throw ('Cached release file is missing or modified: '+$row.Relative+'. Your saved State is kept; do not bypass this check.')}
  $allowed[$row.Relative]=$true
 }
 # Do not traverse user transaction data. Extra executable/code files in the
 # immutable release are refused; State remains separate and is never deleted.
 $queue=New-Object 'Collections.Generic.Stack[string]';$queue.Push($Directory)
 while($queue.Count){
  foreach($item in Get-ChildItem -LiteralPath $queue.Pop() -Force){
   $relative=$item.FullName.Substring($Directory.TrimEnd('\').Length+1)
   if($relative -ieq 'State'){
    if(-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'State must be an ordinary directory.'};continue
   }
   Assert-KKxttiDirectory $item.FullName $Directory
   if($item.PSIsContainer){$queue.Push($item.FullName)}elseif(-not $allowed.ContainsKey($relative)){throw ('Unexpected file in cached release: '+$relative)}
  }
 }
 $rows
}
function Expand-KKxttiPackage([string]$Archive,[string]$Destination) {
 Add-Type -AssemblyName System.IO.Compression
 Add-Type -AssemblyName System.IO.Compression.FileSystem
 Assert-KKxttiDirectory $Destination $Destination
 if(Test-Path -LiteralPath $Destination){throw 'Extraction destination must be new.'}
 $zip=[IO.Compression.ZipFile]::OpenRead($Archive)
 try{
  if($zip.Entries.Count -lt 1 -or $zip.Entries.Count -gt 1500){throw 'Invalid package entry count.'}
  $prefix='KKxtti debloat utility/';$seen=@{};$total=0L
  foreach($entry in $zip.Entries){
   if(-not $entry.FullName.StartsWith($prefix,[StringComparison]::Ordinal) -or $entry.FullName.Contains('\')){throw 'Unexpected ZIP root or separator.'}
   $relative=$entry.FullName.Substring($prefix.Length).TrimEnd('/')
   if(-not $relative){continue}
   Assert-KKxttiRelativePath $relative;$key=$relative.Replace('/','\')
   if($seen.ContainsKey($key) -or $key -match '^(?i:State)(\\|$)'){throw 'Duplicate or reserved ZIP path.'};$seen[$key]=$true
   $total+=$entry.Length
   if($total -gt 100MB -or $entry.Length -gt 50MB){throw 'Release extraction size limit exceeded.'}
   if((($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000 -or ($entry.ExternalAttributes -band 0x400)){throw 'Package contains a link.'}
   Assert-KKxttiDirectory (Join-Path $Destination $relative) $Destination
  }
  if(-not $seen.ContainsKey('KKxtti debloat utility.exe') -or -not $seen.ContainsKey('SHA256SUMS.txt')){throw 'Required release files are missing from ZIP.'}
  [void][IO.Directory]::CreateDirectory($Destination)
  foreach($entry in $zip.Entries){
   $relative=$entry.FullName.Substring($prefix.Length).TrimEnd('/');if(-not $relative){continue}
   $target=Join-Path $Destination $relative;Assert-KKxttiDirectory $target $Destination
   if($entry.FullName.EndsWith('/')){[void][IO.Directory]::CreateDirectory($target);continue}
   [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
   $inputStream=$entry.Open();$outputStream=[IO.File]::Open($target,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
   try{$inputStream.CopyTo($outputStream)}finally{$inputStream.Dispose();$outputStream.Dispose()}
  }
 }finally{$zip.Dispose()}
}
function Receive-KKxttiArchive([string]$Url,[string]$Path) {
 $parsed=[uri]$Url
 if($parsed.Scheme -cne 'https' -or $parsed.Host -cne 'raw.githubusercontent.com' -or $parsed.UserInfo){throw 'Unexpected release download host.'}
 $tls=[Net.ServicePointManager]::SecurityProtocol
 try{
  [Net.ServicePointManager]::SecurityProtocol=$tls -bor [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest -Uri $Url -UseBasicParsing -OutFile $Path -TimeoutSec 120 -ErrorAction Stop
 }finally{[Net.ServicePointManager]::SecurityProtocol=$tls}
 if(-not(Test-Path -LiteralPath $Path -PathType Leaf) -or (Get-Item -LiteralPath $Path).Length -gt 10MB){throw 'Downloaded release is missing or too large.'}
}
function Start-KKxttiInterface([string]$Directory) {
 Start-Process -FilePath (Join-Path $Directory 'KKxtti debloat utility.exe') -WorkingDirectory $Directory -WindowStyle Hidden | Out-Null
}
function Invoke-KKxttiLauncher([string]$Version,[string]$ArchiveUrl,[string]$ArchiveSha256,[string]$ManifestSha256,[string]$Root=(Join-Path $env:LOCALAPPDATA 'KKxtti\Releases'),[switch]$NoLaunch) {
 Assert-KKxttiWindows
 if($Version -cnotmatch '^\d+\.\d+\.\d+$' -or $ArchiveSha256 -cnotmatch '^[A-F0-9]{64}$' -or $ManifestSha256 -cnotmatch '^[A-F0-9]{64}$'){throw 'Invalid pinned release metadata.'}
 $rootFull=[IO.Path]::GetFullPath($Root);Assert-KKxttiDirectory $rootFull $rootFull
 $destination=Join-Path $rootFull ($Version+'-'+$ArchiveSha256.Substring(0,12));Assert-KKxttiDirectory $destination $rootFull
 if(Test-Path -LiteralPath $destination){
  $null=Test-KKxttiRelease $destination $ManifestSha256
  Write-Host ('Opening verified cached KKxtti '+$Version+'. Saved changes remain available.')
 }else{
  [void][IO.Directory]::CreateDirectory($rootFull)
  $download=Join-Path $rootFull ('download-'+[guid]::NewGuid().ToString('N'));Assert-KKxttiDirectory $download $rootFull
  [void][IO.Directory]::CreateDirectory($download);$archive=Join-Path $download 'package.zip'
  Write-Host ('Downloading KKxtti debloat utility '+$Version+'...')
  Receive-KKxttiArchive $ArchiveUrl $archive
  if((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -cne $ArchiveSha256){throw 'Release ZIP hash mismatch. Nothing was launched.'}
  $prepared=Join-Path $download 'prepared';Expand-KKxttiPackage $archive $prepared
  $rows=@(Test-KKxttiRelease $prepared $ManifestSha256)
  # Unblock only the verified release files, never the user's other downloads.
  foreach($row in $rows){Unblock-File -LiteralPath (Join-Path $prepared $row.Relative)}
  Unblock-File -LiteralPath (Join-Path $prepared 'SHA256SUMS.txt')
  Assert-KKxttiDirectory $prepared $rootFull;Assert-KKxttiDirectory $destination $rootFull
  if(Test-Path -LiteralPath $destination){$null=Test-KKxttiRelease $destination $ManifestSha256}
  else{Move-Item -LiteralPath $prepared -Destination $destination -ErrorAction Stop}
  $null=Test-KKxttiRelease $destination $ManifestSha256
 }
 Write-Host ('Location: '+$destination)
 Write-Host 'Opening the interface applies no tweaks. Administrator access is a separate user-selected action.'
 if(-not $NoLaunch){Start-KKxttiInterface $destination}
 $destination
}

 Invoke-KKxttiLauncher -Version '3.3.0' -ArchiveUrl 'https://raw.githubusercontent.com/nxdonyt-creator/FOCS-utility/main/kkxtti/releases/3.3.0/KKxtti-debloat-utility-3.3.0.zip' -ArchiveSha256 '79D43956A265A1695046C56E21E05B0484C3F0A9BA8AAE9F56596F97EDDB3EB8' -ManifestSha256 'A84B019C1FCFE7F133401CDAC7B30266195C002C8B6B42A24DB5EEB0196BD1FC'
}