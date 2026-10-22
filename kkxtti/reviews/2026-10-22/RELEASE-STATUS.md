# 3.4.0 update status

Release package prepared 2026-10-22. The website and repository distribute the same versioned package; the publishing commit is identifiable in repository history.

## Implemented

- The main Potato page now targets the existing Fortnite **NVIDIA driver profile** through NVAPI DRS.
- Four texture settings: Direct3D LOD bias +1.5 or +3.0, high-performance texture filtering, user-defined anisotropic mode and 1x filtering.
- Inspect, explicit Apply, saved local/inherited state and a potato-specific Reset. Competitive-profile Reset remains separate.
- The original INI editor is labelled **In-game low graphics** in a separate optional section.
- Direct control Apply/Undo and NIC Apply/Undo handlers now reject preview mode.
- Manifest version and generated control inventory are current; historical checks are labelled.
- Gaming UI guidance no longer assumes 1080p/240 Hz. The old hardware-specific guide is prominently marked historical; full runtime hardware detection remains planned.
- NVIDIA research links and the website explain current DX12 uncertainty.

## Validation performed

The native x64 .NET Framework dashboard compiled successfully. Packaging metadata below records PowerShell parsing, JSON parsing, archive extraction and file-hash verification when completed.

**Not performed:** new unit/regression/UI test suites, driver-profile application, game screenshots, gameplay/FPS/latency/thermal measurement, clean Windows VM matrix, fresh antivirus scan or signing. No machine settings were changed.

## Remaining work

The full deep review evaluates **3.3.0** as its fixed baseline. The state-v2 schemas, patches 2–8, signing pipeline, common broker/identity design, boot/Recall recovery corrections, catalog effective-state checks and repeated A/B/A workflow are proposals.

Current release remains unsigned, uses mutable launcher trust and per-release history, and retains the known recovery/identity limitations documented in [KNOWN-ISSUES.txt](KNOWN-ISSUES.txt). No universal visual or performance improvement is claimed. Use the old release's State to recover old changes.


## Packaging record

- Version: 3.4.0
- ZIP bytes: 667332
- Manifest entries verified: 78 (plus the manifest itself)
- Windows PowerShell 5.1 sources parsed: 30
- Package JSON files parsed: 2
- ZIP SHA-256: F7B2C4142F686632F3280AC2326045960470CFC007B15EFCDBB1FA2FC964B12B
- Manifest SHA-256: 3655EDF7F70775BB6371D7CFBE854129ED443E13A5146BD2F4B7D3ED38CCBA22

[Website](https://nxdonyt-creator.github.io/FOCS-utility/) · [NVIDIA research](https://nxdonyt-creator.github.io/FOCS-utility/kkxtti/releases/3.4.0/SOURCES.txt) · [Release history](https://github.com/nxdonyt-creator/FOCS-utility/commits/main/)
