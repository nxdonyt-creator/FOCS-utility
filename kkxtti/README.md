# KKxtti debloat utility 3.3.0

[Open the download webpage](https://nxdonyt-creator.github.io/FOCS-utility/) · [Read the complete tweak audit](https://nxdonyt-creator.github.io/FOCS-utility/audit.html)

A native Windows utility with 104 reviewed registry controls, game profiles, frame-time comparisons, network tools and saved configuration recovery. Most controls are preferences; no universal FPS or latency gain is claimed.

## Open on another computer

On Windows 11 x64 (Intel/AMD), run:

```powershell
irm https://raw.githubusercontent.com/nxdonyt-creator/FOCS-utility/main/kkxtti.ps1 | iex
```

The launcher verifies the versioned ZIP and every packaged file against pinned SHA-256 values before opening the interface. Opening applies no tweaks. Requirements: .NET Framework 4.8 and Windows PowerShell 5.1. The launcher also works from PowerShell 7 on supported Windows. ARM64 and Windows 10 are not supported.

## New in 3.3.0

- Read-only inspection of 12 registry values from the supplied video.
- Optional MMCSS 10%/20% comparison, with exact saved-state Undo.
- Searchable audit of every control and the other tool areas.
- Correct Recall deletion confirmation, policy scope and eligibility.
- Better conflict handling for registry, system, network, DNS and power recovery.
- [Release notes](CHANGELOG.md) and [validation limits](releases/3.3.0/VERIFICATION.txt).

## Downloads and recovery

[Download 3.3.0](https://raw.githubusercontent.com/nxdonyt-creator/FOCS-utility/main/kkxtti/releases/3.3.0/KKxtti-debloat-utility-3.3.0.zip). Extract the complete archive; keep the source, engine files and executable together. The executable is unsigned.

ZIP SHA-256: `79D43956A265A1695046C56E21E05B0484C3F0A9BA8AAE9F56596F97EDDB3EB8`

The launcher caches each version under `%LOCALAPPDATA%\KKxtti\Releases\<version>-<hash-prefix>`. Keep earlier release folders and their State records. Use the version that made a change to undo it before applying overlapping changes. Undo restores recorded configuration; it cannot restore deleted Recall snapshots, removed app data or cleaned files.

[Version 3.2.0](releases/3.2.0/KKxtti-debloat-utility-3.2.0.zip) remains available. The legacy FOCS batch utility is a separate download and is outside this audit.
