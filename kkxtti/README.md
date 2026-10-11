# KKxtti debloat utility

Version **3.2.0**. A purple native Windows interface with 103 documented controls,
selectable app debloat, reviewed changes, saved undo records, game/network tools
and an installer for Chromium, Discord and Epic Games. Source and tests are in
the ZIP. The existing FOCS batch utility in this repository remains separate.

## New in 3.2

- **Custom KKxtti Ultimate Gaming power plan:** a separate copy of your desktop's
  current plan with supported AC performance settings, inspection and Reset.
- **NVIDIA profiles for Fortnite and Rainbow Six Siege:** per-game power,
  filtering, V-Sync and driver-limiter settings with saved-value Reset.
- **Fortnite Potato graphics:** low quality with 50/67/75/100% render scale,
  preview and Reset. Preserves display dimensions, sensitivity and FPS cap.
- **Live peripherals:** present device names, composite HID grouping, hotplug
  refresh and the last mouse/receiver supplying input. No guessed polling rate.
- **Recovery center:** prominent restore-point creation and Reset saved tweaks,
  which restores this version's reversible journals in newest-first order.

These are optional profiles to benchmark, not a promise of higher FPS or lower
latency on every PC. Lower graphics can reduce clarity; performance settings can
increase heat. Use in-game Reflex where available. See the
[settings and primary research sources](releases/3.2.0/SOURCES.txt).

## Open on another PC

On **Windows 11 x64 Intel/AMD**, open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/nxdonyt-creator/FOCS-utility/main/kkxtti.ps1 | iex
```

The launcher downloads the versioned ZIP, verifies its pinned SHA-256 hash and
each payload against a separately pinned manifest, then opens the interface.
Opening it applies no tweaks, installs/removes no apps and requests no elevation
or restart automatically. Administrator actions are chosen in the UI. It does
not add antivirus exclusions or change Windows execution policy.

Requirements: Windows 11 x64 Intel/AMD, .NET Framework 4.8 and Windows PowerShell
5.1. The command also works from PowerShell 7 on supported Windows PCs.
Windows 10, ARM64 and non-Windows platforms are not supported by this build.

## Download or inspect first

- [Download version 3.2.0](https://raw.githubusercontent.com/nxdonyt-creator/FOCS-utility/main/kkxtti/releases/3.2.0/KKxtti-debloat-utility-3.2.0.zip)
- [Inspect the launcher](https://github.com/nxdonyt-creator/FOCS-utility/blob/main/kkxtti.ps1)
- [Release hashes](releases/3.2.0/SHA256SUMS.txt)
- [Verification and limits](releases/3.2.0/VERIFICATION.txt)

For manual use, extract the entire ZIP and open `KKxtti debloat utility.exe`.
Read `START HERE.txt` and `WEB LAUNCH.txt`; keep all included files together.
If Windows marks the download as blocked, inspect the source and verify its
hash before using Properties > Unblock on your verified ZIP and extracting it.

ZIP SHA-256:

```text
4373AA4DE5CE21D31F0FEA484AAA79E7DAF8D58FE36CC25DC346FA86835605FD
```

## Saved changes and updates

The launcher caches verified files under
`%LOCALAPPDATA%\KKxtti\Releases\3.2.0-<hash-prefix>`.
Repeat launches preserve that version's `State` records. Modified/extra payload
files prevent launch; saved records are not erased. Each version has a separate
folder. Keep old versions with their `State` to restore their saved changes.
Download work is retained; old application folders are not silently removed
or merged. Version 3.1.0 remains available in `releases/3.1.0/`.

Reset restores saved prior values, not arbitrary factory defaults. Conflicting
later edits stop it. Restore legacy boot/power snapshots individually in Backups.
App removal, installation, cleanup and decryption have no automatic Reset here.
Windows restore-point creation can be unavailable or frequency-limited.

Hardware/app/network inventory is read on the PC using the utility. Old hardware
notes are reference research. Device identity is read locally from Windows;
keypresses, pointer coordinates and button contents are not recorded. Wireless
receivers may not reveal their paired mouse model or selected polling rate.

## Verification and trust

**756 automated checks passed:** all 662 previous checks rerun, plus 84 new
profile/recovery/peripheral checks and 10 native identity/preview checks.
Mutations used mocks, isolated registry keys or fixture files. All 27 PowerShell
files and both JSON files parsed, and the x64 native dashboard compiled.
Read-only checks confirmed installed NVIDIA profiles, supported power values,
present devices and the secondary-monitor preview. No live tweak was applied.
A full final-build UI click-through and gameplay/latency benchmarks were not
performed while the user was studying; see the detailed verification record.

Local Defender scans found no threats (signatures 1.459.672.0). The executable is
**unsigned**. A clean local scan and hashes cannot guarantee acceptance by every
scanner or protect against compromise of the launcher/hosting account itself.
Inspect the source or download manually if preferred. Do not disable antivirus
to run the utility.
