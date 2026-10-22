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

Read [the full audit](../audit.html), [the video review](releases/3.3.0/VIDEO-REVIEW.txt) and [validation limits](releases/3.3.0/VERIFICATION.txt).
