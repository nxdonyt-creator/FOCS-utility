# KKxtti debloat utility

Version **3.1.0**. A purple native Windows interface with 103 documented controls,
selectable app debloat, per-change review, saved undo records where supported,
game/network tools and an app installer for Chromium, Discord and Epic Games.
The source, research notes, original utility audit and tests are in the ZIP.
The existing FOCS batch utility in this repository is a separate application.

## Open on another PC

On **Windows 11 x64 Intel/AMD**, open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/nxdonyt-creator/FOCS-utility/main/kkxtti.ps1 | iex
```

The command fetches the launcher, downloads the versioned ZIP, verifies its
pinned SHA-256 hash and each payload against a separately pinned manifest, then
opens the interface. It applies no tweaks, installs/removes no apps and requests
no elevation or restart automatically. Administrator actions are chosen in the UI.
No antivirus exclusion or execution-policy change is used.

Requirements: Windows 11 x64 Intel/AMD, .NET Framework 4.8 and Windows PowerShell
5.1. The command also works from PowerShell 7 on supported Windows PCs.
Windows 10, ARM64 and non-Windows platforms are not supported by this build.

## Download or inspect first

- [Download the ZIP](https://raw.githubusercontent.com/nxdonyt-creator/FOCS-utility/main/kkxtti/releases/3.1.0/KKxtti-debloat-utility-3.1.0.zip)
- [Inspect the launcher](https://github.com/nxdonyt-creator/FOCS-utility/blob/main/kkxtti.ps1)
- [Release hashes](releases/3.1.0/SHA256SUMS.txt)

For manual use, extract the entire ZIP and open `KKxtti debloat utility.exe`.
Read `START HERE.txt` and `WEB LAUNCH.txt`. If Windows marks the download as
blocked, inspect the source and verify its hash before using Properties > Unblock
on your verified ZIP and extracting it. Keep all included engine/catalog files.

ZIP SHA-256:
```text
C4F4FEF29B92A7B5F6A1593D0A0DF498A558D230EFC673C2A08D93D4D8E9D867
```

## Saved changes and updates

The web launcher caches verified files under
`%LOCALAPPDATA%\KKxtti\Releases\3.1.0-<hash-prefix>`.
Repeat launches preserve that version's `State` records. Modified/extra payload
files prevent launch; saved records are not erased. Each version has a separate
folder. Keep old versions with their `State` if you need their undo records.
Download work is retained for inspection; the launcher does not silently clean
or migrate old application folders.

Hardware/app/network inventory is read on the PC using the utility. The Ryzen
X3D/RTX 3060 Ti, Superlight 2, Apex Pro and competitive-game notes are reference
research, not a universal preset or a claim that every PC uses those devices.
The controls include privacy and desktop preferences as well as performance
choices; they are not 103 proven FPS improvements. Benchmark-dependent options
remain opt-in. Destructive cleanup, app removal and decryption have no automatic
undo; read the review before applying them.

## Verification and trust

662 checks passed: 581 existing engine/analysis checks plus 81 new launcher
fixture/mock checks. All 21 bundled PowerShell files parsed, the rebuilt native
UI branding was checked read-only, and a fresh local Defender scan found no
threats (signatures 1.459.638.0). No actual PC tweaks or app installs/removals were
performed during these checks. See `VERIFICATION.txt` and `RELEASE CHECKS.txt`.

The executable is **unsigned**. A local scan and hashes are not a guarantee
against every scanner warning or a compromise of this hosting account. Remote
execution trusts the fetched launcher itself; pinned hashes protect the package
only while that launcher is trusted. Inspect the source or download manually if
you prefer. Do not disable antivirus to run the utility.