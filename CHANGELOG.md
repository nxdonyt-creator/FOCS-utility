# KKxtti 3.4.0 — 22 October 2026

## NVIDIA potato-profile correction

- The main Potato action now writes four allowlisted texture settings to the existing Fortnite NVIDIA DRS application profile: LOD +1.5 or +3.0, high-performance filtering and 1x anisotropic override.
- Inspect, reviewed Apply, saved original overrides/inheritance and potato-specific Reset are included. Competitive Reset remains separate.
- The INI editor is clearly labelled In-game low graphics in an optional section.
- Current Fortnite DX12 may ignore these driver overrides. Saved values do not prove changed visuals or an FPS/latency gain.

## Limited audit fixes

- Direct control Apply/Undo and NIC Apply/Undo now reject read-only preview.
- Updated the manifest version and generated 104-control inventory; labelled historical tests and reference-PC guidance.
- Published the deep engineering review with 19 findings, all 104 controls, schemas, eight example patches, release and measurement plans.

## Validation and remaining work

Compiled the native x64 dashboard; parsed PowerShell and JSON; verified the packaged extraction and file hashes. No new test suites, GPU changes, gameplay measurements, fresh AV scan or signing. State v2, signing, boot/Recall recovery and the broader roadmap remain proposed. Read the known issues before using administrative operations.

See [engineering review](https://nxdonyt-creator.github.io/FOCS-utility/review.html), [NVIDIA research](https://nxdonyt-creator.github.io/FOCS-utility/kkxtti/releases/3.4.0/SOURCES.txt) and [validation](https://nxdonyt-creator.github.io/FOCS-utility/kkxtti/releases/3.4.0/VERIFICATION.txt).

---

# KKxtti 3.3.0 — 18 October 2026

## Performance review and correctness
- Added read-only inspection of 12 registry values discussed in the supplied video.
- Added an optional MMCSS 10% versus 20% reservation comparison, excluded from presets, with exact original registry-state Undo.
- Added a searchable audit of all 104 controls and 20 other tool/profile areas, including values, evidence, tradeoffs and recovery limits.
- Corrected Recall's deletion warning and added a typed DELETE confirmation for applying or restoring the snapshot-deletion policy, including Reset all.
- Corrected File Explorer search-policy scope, Recall edition/build revision eligibility, Notepad requirements, and legacy Copilot policy wording.
- Prevented system rollback from overwriting a change made while confirmation was open. Registry, network and DNS rollback also preserve unrelated newer values.
- Added conflict checks to the simple power-plan switch and Undo.
- Blocked Performance control writes in read-only preview and clarified deleted-data recovery limits.
- Updated the website and pinned launcher package/manifest hashes. Kept earlier versions and their journals separate.

## Evidence
The final native x64 application compiles and its PowerShell sources parse. Earlier development checks passed 372 assertions before the final audit corrections; that total does not validate all final behavior. No gameplay, thermal, network or end-to-end latency gain was measured. The final audit corrections have not undergone a full runtime regression or native click-through.

Read [the full audit](audit.html), [the video review](kkxtti/releases/3.3.0/VIDEO-REVIEW.txt) and [validation limits](kkxtti/releases/3.3.0/VERIFICATION.txt).

---

# FOCS Utility v9.5.0 hardened build

## App installer and validation

- Added a dedicated App Installer page for Chromium, Discord, Steam, Epic Games Launcher, and Logitech Onboard Memory Manager.
- Uses a fixed catalog of exact WinGet package IDs; users cannot inject arbitrary package names or command-line arguments.
- Added Select All, Clear, status refresh, and reviewed install/update actions.
- Added a final confirmation that lists the selected apps before installation begins.
- Continues after individual package failures and reports each result separately.
- Added installed/available version reporting and a clear Microsoft App Installer prerequisite message when WinGet is missing.
- Chooses `install` or `upgrade` from the detected package state instead of inferring state from a failed upgrade attempt.
- Updated the website and download filename for v9.5.0.

## v9.5.0 validation performed

- Parsed the complete embedded PowerShell payload: zero syntax errors across 200 function definitions.
- Ran 49 static and unit checks covering custom-command resolution, version and statistical helpers, the five-entry app catalog, installer UI wiring, confirmation flow, and website links.
- Served the site locally and confirmed the landing page, v9.5.0 batch download, and changelog all return HTTP 200.
- Did not execute installers or system-changing tuning routines. Those require explicit user confirmation and a suitable Windows test machine or VM.

## Previous v9.4.1 corrections and hardening

Source reviewed: `FOCS_Utility_v9_4_0_NETWORK_DEPARTMENT_REWORK_TEST.bat`

## Corrections and hardening

- Corrected the stale `v9_3_0` log filename and updated visible build identifiers to `v9.4.1`.
- Restricted managed-tool downloads to absolute HTTPS URLs.
- Changed elevated-code download verification to fail closed: a download now needs a matching publisher SHA-256 digest or a valid Authenticode signature from the expected publisher.
- Added atomic directory replacement with rollback for NVIDIA Profile Inspector and LibreHardwareMonitor updates, so a failed copy no longer destroys the working installation.
- Preserved IPv4 and IPv6 Receive Segment Coalescing states independently during NIC restore instead of enabling or disabling both from one combined Boolean.
- Added an emergency `finally` rollback around Network Performance Lab mutations. If the lab errors or is interrupted, it attempts to restore the original NIC snapshot.
- Added a normal FOCS recovery backup before the Network Performance Lab starts changing adapter settings.
- Prevented a failed automatic tool update from suppressing retries for the next 24 hours.

## Validation performed

- Extracted and parsed the complete embedded PowerShell payload with the Windows PowerShell parser: zero syntax errors.
- Confirmed the host's `Enable-NetAdapterRsc` and `Disable-NetAdapterRsc` cmdlets support the IPv4, IPv6, and NoRestart parameters used by the revised restore logic.
- Confirmed there are no remaining `v9.4.0` or `v9_3_0` identifiers in the hardened build.
- Did not execute the GUI or its tuning actions because the script runs elevated and intentionally changes registry, services, power, AppX, QoS, and NIC state.

## Operational note

The hardened trust policy can refuse a legitimate release asset if its publisher provides neither a GitHub SHA-256 digest nor a trusted Authenticode signature. This is intentional: the utility runs or loads those downloads with administrator rights, so availability is not allowed to override code integrity.
