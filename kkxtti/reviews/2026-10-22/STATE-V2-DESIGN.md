# State and catalog v2: integration contract

**Proposed design, 2026-10-22; not implemented by the 3.4.0 NVIDIA correction.** Read with [state schema](state-journal-v2.schema.json), [catalog schema](catalog-entry-v2.schema.json), [portable-profile schema](profile-v1.schema.json), and findings A02/A06/A07/A09/A10/A11 in the main report.

## Storage, identity and trust

Use a stable product directory, independent of the release executable. Put user records under LocalApplicationData/KKxtti/State/v2, bound to the initiating SID. Put machine-operation records in an administrator-owned ProgramData/KKxtti/State/v2 location, written by the broker. Separate diagnostic exports from authoritative recovery records. Never execute scripts, paths, registry targets or commands supplied by imported state.

The schema stores a local installation identifier and a machine fingerprint, plus initiating/executing SIDs. A fingerprint is a routing/accident-prevention aid, not an unforgeable hardware identity. Account rename should not break SID identity; Windows reinstall, account replacement and disk cloning require review. Do not use the visible computer name as sole identity.

Bind a machine transaction to the initiating user's request and the actual broker identity. The unelevated UI continues reading HKCU, per-user Appx and game paths. A broker accepts only versioned operation IDs with typed arguments, revalidates their schema and resolves approved resources itself. It must authenticate the IPC peer and bind requests to a nonce/session; a SID text field alone is not authentication. Alternate-credential UAC uses a different security principal; do not silently redirect account actions. [UAC process model](https://learn.microsoft.com/en-gb/windows/security/application-security/application-control/user-account-control/how-it-works).

## Record and state transitions

The machine-readable schema is a deliberately strict starting contract. Each row captures an immutable resource descriptor, typed before/target/observed-after values, operation version, catalog digest and resource identity. Resolve HKCU to HKU plus the initiating SID before journaling. .DEFAULT is permitted only for explicitly approved logon-desktop operations; it does not mean “all new users.”

Use Prepared → Applying → Applied, or PartiallyApplied/Conflict/NeedsReview; Undoing → Undone only after every owned resource matches the saved before-state. Persist Prepared before the first mutation and persist the observed outcome after each mutation. Do not mark Applied merely because a subprocess exited zero. Re-open and read the relevant resource using the correct registry view and native type.

Recovery first acquires an exclusive transaction/resource lock, then reads fresh state. For each row:

- Current equals Before: already restored; include it in final verification.
- Current equals observed applied state: eligible to restore.
- Current equals neither: conflict; no automatic overwrite.
- Uncertain or unsupported current provider/version: NeedsReview.
- An irreversible side effect cannot be rolled back even if its registry setting can.

Read the entire set again immediately before final status. Because unrelated programs and Windows do not take KKxtti's lock, this reduces races rather than proving an OS-wide atomic multi-resource transaction. A concurrent post-verification edit becomes subsequent drift. Never describe registry compare/read/write sequences as native atomic compare-and-swap.

For masked values compare owned bits, preserve unowned current bits, and restore only owned bits. When the original value did not exist, delete it only if no unrelated bits or later owners remain; otherwise keep the other bits and explain why full absence cannot be restored. A whole-value writer conflicts with every masked writer of that resource. A masked delete is invalid. Resolve multiple disjoint masks into one planned write before execution.

## Durable publication and corruption

Serialize writers for the whole read-plan-write-record transaction, not just the final save. Each journal update checks the expected revision and prior payload hash. Write UTF-8 to a unique same-directory temporary file using CreateNew, flush the stream with Flush(true), and replace an existing journal while retaining a distinct previous revision backup. Initial creation uses a same-volume move. Validate schema, digest, identity and operation versions on every read. Reject duplicate JSON property names, excessive depth/bytes/rows, non-finite numbers and unexpected fields.

[File.Replace](https://learn.microsoft.com/en-us/dotnet/api/system.io.file.replace) and [FileStream.Flush](https://learn.microsoft.com/en-us/dotnet/api/system.io.filestream.flush) support these building blocks. They do not establish a power-loss guarantee for every filesystem, controller and filter driver. Crash/reboot/power-fault evidence is still required. If both current and backup disagree or are corrupt, quarantine them, retain bytes and offer diagnostic export; do not guess a Before state.

A checksum detects accidental corruption, not malicious editing when the attacker can rewrite both payload and checksum. Proposed SHA-256/HMAC input is RFC 8785 canonical JSON of the entire envelope excluding integrity, including transactionId, revision and previousPayloadSha256. Use a vetted canonicalizer; PowerShell ConvertTo-Json is not an RFC 8785 implementation. Store large integer values as decimal strings to preserve exact DWord/QWord bits across JSON implementations. [RFC 8785](https://www.rfc-editor.org/rfc/rfc8785), June 2020.

HMAC key storage should be ACL-restricted and protected for the appropriate machine/user context. A broker-owned key helps reject arbitrary user-crafted machine journals. It does not protect against a compromised administrator or the signing process itself; user-scoped protection does not defeat same-user malware. Key IDs permit rotation. Portable exports contain desired controls, not authority to execute an old transaction on another machine. No embedded secret belongs in the source repository.

## Schema limitations and required semantic validator

JSON Schema is not sufficient on its own. The implementation must enforce:

1. DWord range 0..4294967295 and QWord 0..18446744073709551615; data/native-kind correspondence; valid strict base64; maximum decoded bytes.
2. Set actions require present=true; delete is a separate action. Registry rows cannot use JsonSnapshot. Snapshot fields for DNS, NIC, power, NVIDIA and Appx each need a versioned provider-specific validator.
3. HKLM requires sid=null; HKU requires the authenticated initiating SID or approved .DEFAULT. Registry64 is explicit.
4. File relative paths reject absolute paths, traversal, ADS, reserved names and reparse/hardlink substitution. Resolve approved roots from trusted runtime detection, not the imported document.
5. No arbitrary resource path becomes writable merely because it fits the schema. Match the trusted operation definition and saved version.
6. Duplicate row IDs/resources, incompatible masks, dependency cycles and inconsistent timestamps/status transitions fail closed.
7. Both producer and consumer must enable format assertions; JSON Schema format is not automatically an enforcement guarantee.
8. A destructive acknowledgment is evidence of a past UI decision, not reusable permission. Reasserting Recall deletion during compensation needs a new matching authorization or stops in NeedsReview.
9. Unknown schema/operation versions remain read-only. Never coerce unknown records into current catalog definitions.

The supplied state resource union covers representative registry, file, DNS, NIC, power-setting, NVIDIA, BCD and Appx operations. Before production migration, add equally strict service/hibernation/power-plan schemas and provider validators; unsupported legacy operation families remain manual-only. This is an explicit staged migration boundary.

## Migration from schema 1 and old releases

Discover legacy State directories read-only. Inventory release version, engine/catalog hashes, machine/user identity evidence and journal status. Copy originals into a timestamped import archive without deleting or rewriting them. Map Id/Index using the **exact historical catalog**, not today's array order. The public 3.3 package and hash manifest can establish which catalog was shipped; locally altered or missing versions need review.

Only migrate a record if resource identity, typed Before/After and ownership can be reconstructed without inference. Missing expected After in old BCD records cannot be invented from current state; retain them as historical backups with a manual comparison. Do not retroactively label the migration itself a successful application or Undo.

Produce a migration report listing imported, duplicate, ambiguous and unsupported records. Preserve original hashes, source release and conversion version. Run migration idempotently by original digest plus source installation. The new engine uses one global resource conflict index across imported and new transactions, while retaining chronological history. A Windows feature update invalidates applicability assumptions: refresh effective-state probes before offering Undo or reapply.

## Drift and profiles

A drift scan is read-only. Compare desired, stored and effective states, recording the observation time and management origin. Report “unchanged,” “Windows/app changed it,” “managed policy,” “resource disappeared,” or “unknown”; attribution beyond available evidence stays unknown. Notify on meaningful drift. Do not silently enforce settings against Windows Update, Defender, an administrator or another tool.

Profile-as-code exports stable control IDs, operation versions, desired on/off, catalog digest, portability category and notes. Import previews capabilities and an exact local diff, then requires the ordinary review flow. It creates fresh local Before records; it never imports another computer's Undo data as authoritative. Profiles contain no executable PowerShell, package wildcard, process name injection, machine SID, credentials or absolute personal path. High-impact/destructive controls require separate local confirmation and are excluded from automatic presets.

## Recovery alternatives

| Mechanism | Useful for | Why it is not exact transaction Undo |
|---|---|---|
| System Restore | Optional broader OS recovery when protection is enabled and a point exists | Availability, scope and recovery success must be checked; it does not recover every app/user-data side effect |
| Registry export | Human-readable emergency evidence of selected keys | Broad import can overwrite later changes; normally lacks operation identity/effective-state semantics |
| DISM image/provisioning | OS image maintenance and provisioning | Does not reconstruct each user's removed application data or current registration automatically |
| Store/WinGet reinstall | Reacquiring an available application | Version/availability/account/network can differ; deleted data is not restored |
| Full image/file backup | Stronger disaster recovery | Separate storage, restore testing and user ownership are required |
| Journal v2 | Exact narrow resource recovery where state is known | Cannot reverse deletion, guarantee outside writers cooperate, or defeat an administrator |

The table is a recovery-design comparison, not a guarantee for a particular Windows restore configuration. Include operation-specific recovery instructions and explicit irreversible side effects in every review dialog.
