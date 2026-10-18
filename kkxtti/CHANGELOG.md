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
