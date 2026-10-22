# KKxtti debloat utility 3.4.0

[Download webpage](https://nxdonyt-creator.github.io/FOCS-utility/) · [Engineering review](https://nxdonyt-creator.github.io/FOCS-utility/review.html) · [104-control inventory](https://nxdonyt-creator.github.io/FOCS-utility/audit.html)

## New in 3.4.0

The Potato page now edits the existing Fortnite NVIDIA driver profile, with LOD +1.5/+3.0 choices, filtering settings, Inspect and separate Reset. The in-game INI editor is labelled separately. Current Fortnite DX12 may ignore the driver overrides: no changed visuals, FPS or latency gain is promised.

Two direct preview mutation routes are guarded. The deep review includes 19 findings, all 104 controls, state/catalog schemas, eight example patches and a prioritized plan. The broader roadmap is not implemented in this release.

## Download

[Download the complete 3.4.0 ZIP](https://raw.githubusercontent.com/nxdonyt-creator/FOCS-utility/main/kkxtti/releases/3.4.0/KKxtti-debloat-utility-3.4.0.zip). Extract all files together. Windows 11 x64 Intel/AMD, .NET Framework 4.8 and Windows PowerShell 5.1 are required. ARM64 is unsupported.

The application is unsigned. [Validation limits](https://nxdonyt-creator.github.io/FOCS-utility/kkxtti/releases/3.4.0/VERIFICATION.txt) · [Known issues](https://nxdonyt-creator.github.io/FOCS-utility/kkxtti/releases/3.4.0/KNOWN-ISSUES.txt).

ZIP SHA-256: F7B2C4142F686632F3280AC2326045960470CFC007B15EFCDBB1FA2FC964B12B

## Optional PowerShell launcher

Inspect the launcher before running it. It checks pinned package/file hashes; the pins are inside the mutable launcher and do not authenticate a compromised launcher itself.

~~~powershell
irm https://raw.githubusercontent.com/nxdonyt-creator/FOCS-utility/main/kkxtti.ps1 | iex
~~~

Opening applies no tweaks. Each release keeps separate State records under its cached version folder. Preserve older versions and use the version that made a change for its Undo before overlapping edits. Settings recovery cannot restore deleted Recall snapshots, removed app data or cleaned files.

[Previous 3.3.0 ZIP](https://raw.githubusercontent.com/nxdonyt-creator/FOCS-utility/main/kkxtti/releases/3.3.0/KKxtti-debloat-utility-3.3.0.zip) remains available. The legacy FOCS batch utility is separate and outside this audit.
