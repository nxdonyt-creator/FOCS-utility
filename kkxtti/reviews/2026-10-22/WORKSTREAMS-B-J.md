# Workstreams B–J: detailed implementation decisions

Review date/access date: 2026-10-22. Proposed work unless RELEASE-STATUS.md explicitly says shipped. Confidence is high for cited API/policy facts and direct code observations, medium for architectural/effort recommendations, and low for unmeasured performance or game compatibility.

## B. Distribution

See [RELEASE-PIPELINE.md](RELEASE-PIPELINE.md) for the threat model, signing options, distribution comparison and twelve-step release pipeline. It covers mutable launcher pins, protected execution, upstream helper provenance, Chromium download limits, SBOM, attestations and immutable releases.

Immediate deliverables: one source-controlled release metadata document; version/hash consistency across EXE/manifest/ZIP/launcher/site; independent signed release identity; a retained historical archive. Longer-term install ownership and a small broker are necessary for a stronger elevated-code boundary. A signature does not replace input validation or recovery.

## C. Recovery and state

See [STATE-V2-DESIGN.md](STATE-V2-DESIGN.md) and the three JSON schemas. Prioritize versioned resource snapshots, identity, all-row verification, crash status, serialized revision writes and cross-release migration before adding more stateful controls. Keep malformed or unsupported old journals read-only. Exact rollback cannot be promised for deleted files, snapshots or app data.

### Dangerous operations: disposition

| Area / code | Existing protection worth retaining | Required next change |
|---|---|---|
| System Engine.ps1 / Start-SystemDriveDecryption | Explicit warning/confirmation; not automatically applied | Move out of gaming optimization into a clearly separate administration/help flow, preferably an OS settings link. Decryption is a security change, not a measured FPS control. |
| Control Engine / no-recall / Invoke-ControlRows | Deletion wording and normal confirmation | Central gate for every write, including compensation; eligible component/edition probe; explain irreversibility |
| Performance Utility / Reset-BootOverrides, Undo-Boot; Reset Engine boot helpers | Narrow boot keys, backup, no automatic reboot | Immutable BCD object/store identity and expected After; refuse automatic old-record Undo with insufficient evidence; protect concurrent edits |
| System Engine / hibernation changes | Before-state and explicit operation | Journal enabled state, file type/size and supported power capabilities; inspect Fast Startup/sleep consequences; no battery-device preset |
| Network Engine / Set-/Undo-NetworkSettings | GUID/hardware/driver-property validation, staged reconnect | Revalidate driver choices at execution and Undo, all-row final verification, transaction lock; explicit reconnect impact |
| DNS Engine / DNS changes | Adapter-scoped server restoration | Distinguish DHCP mode from explicit list, address families and VPN/virtual adapters; refresh identity on Undo; final all-family readback |
| Game Engine / game-file changes | Closed-game checks, narrow fields and expected bytes | File identity/ACL/cloud/update detection; atomic file publication; no permission/read-only hacks |
| Appx removal | Current-user scope and reviewed allowlist | Fresh dependency graph and identity on every path; documented reinstall availability and data-loss tier |
| Temp cleanup | Age/path scope and irreversible label | Keep separate from performance presets; never sweep shader caches/Downloads or follow links |

These are source-review recommendations. The existence of a backup is not proof of a successful recovery after a crash or Windows update. Microsoft's [BCD documentation](https://learn.microsoft.com/windows-hardware/drivers/devtest/bcdedit--set) and [BitLocker BCD validation](https://learn.microsoft.com/en-us/windows/security/operating-system-security/data-protection/bitlocker/bcd-settings-and-bitlocker) justify special care around boot settings.

## D. Catalog and evidence

The [104-control audit](CATALOG-AUDIT.md) gives a decision for every built-in and JSON entry and transcribes every target. Main report section 4 handles performance classes outside the catalog.

Specific changes:

1. Replace Supported=true from MinBuild alone with applicability states: supported-and-verified, documented-but-unverified-here, unavailable, managed, deprecated, and unknown. Never translate unknown into a green success state.
2. Split Evidence into source class, exact support section, date, confidence and runtime evidence. A reference implementation is useful for discovering behavior, but is not a Microsoft compatibility contract.
3. Prefer source-defined policies to numeric private shell flags only when their scope and user intent match. Do not silently substitute a broad device policy for a per-user UI preference.
4. Detect browser version and effective policy, including account restrictions. AllowGamesMenu is deprecated; Brave News and telemetry controls need their documented version gates. Preserve policy source/conflict information.
5. Exclude security disabling, blanket service removal, “network optimizer” bundles and undocumented timer/MSI/affinity recipes. A useful addition must address a real workflow with a known recovery path.
6. Add read-only active-hours/update/pause-expiry, pending-reboot, OneDrive sync and current display/VRR information before adding writes. Specific new policies need individual primary-source verification and clean-VM evidence before release.

Managed policy detection must distinguish observed configuration from actual management ownership. Use Resultant Set of Policy and MDM diagnostic evidence when available; a registry Policies path alone does not tell who set it. Microsoft documents only limited [MDM-versus-GP conflict behavior](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-controlpolicyconflict), not universal precedence.

## E. Performance and measurements

Main report section 4 is the claims table; [STATISTICS-SPEC.md](STATISTICS-SPEC.md) is the implementable analysis contract. Keep existing honest distinctions: p99 interval vs mean of worst 1%, and frame pacing vs end-to-end latency.

The high-value feature is a repeatable experiment: detect environment → capture A → apply one reversible operation → capture B → Undo and verify → capture A again → repeat balanced blocks → report effect and uncertainty. Stop when Undo conflicts; never keep applying new treatments on an unknown baseline. Store capture executable hash, version/schema, process/swapchain, frame generation status, game build, driver, OS build/UBR, power source/plan, display timing and temperatures/background load when available.

PresentMon 2.6.0 was published 2026-09-21. It has several metric families and capture paths; do not infer units from “FrameTime” alone. Its [release](https://github.com/GameTechDev/PresentMon/releases/tag/v2.6.0) and [console documentation](https://github.com/GameTechDev/PresentMon/blob/main/README-ConsoleApplication.md) should be pinned to the shipped producer revision. A generic overlay screenshot cannot replace raw capture provenance.

No reviewed primary source demonstrates a universal FPS/latency gain for this utility's presets on current Windows and every supported game. The absence of such evidence does not prove every control is ineffective; it makes an honest experiment the appropriate behavior.

## F. Appx/debloat

### Scope and current platform behavior

Get-AppxPackage/Remove-AppxPackage target installed packages; current-user removal differs from AllUsers. DISM provisioned-package removal concerns provisioning for new users, not simply undoing each existing account's installation. Keep these as distinct operations with distinct permissions and data-loss previews. [Appx removal](https://learn.microsoft.com/en-us/powershell/module/appx/remove-appxpackage?view=windowsserver2025-ps); [provisioned package removal](https://learn.microsoft.com/en-us/powershell/module/dism/remove-appxprovisionedpackage?view=windowsserver2025-ps).

Current Microsoft policy-based inbox removal documentation covers Windows 11 **24H2 and later**, Enterprise/Education, managed-device scenarios. It is not a general Home debloater. It operates through provisioning/sign-in behavior, can block reinstallation while selected, and clearing policy does not itself reinstall apps. Newer policy surfaces include package-family targeting, so pin the actual policy/schema revision and rollout. [Microsoft policy-based inbox removal](https://learn.microsoft.com/en-us/windows/configuration/policy-based-inbox-app-removal/policy-based-inbox-app-removal), accessed 2026-10-22. Do not reuse older “25H2 only” summaries.

### A maintained list, not a universal safe list

No clean-VM removal/reinstall validation was run here, so the following are **candidate tiers**, not “verified-safe on every PC.” Package names are taken from Get-AppCatalog in the reviewed code. A release may promote a package to validated only with the exact build/package/dependency/reinstall evidence below.

| Tier | Baseline packages / user features | Proposed product behavior and recovery |
|---|---|---|
| 0: preserve | Store, DesktopAppInstaller, framework/resource/runtime packages, Windows Security, Start/Shell hosts, authentication brokers, Gaming Services, GameInput | Exclude from generic removal even if absent from the current allowlist. Fresh dependency and non-removable flags must also block. Never wildcard-delete similarly named packages. |
| 1: optional, low integration | Microsoft.BingNews, Microsoft.BingWeather, Microsoft.WindowsFeedbackHub, Microsoft.MicrosoftSolitaireCollection, Microsoft.MicrosoftOfficeHub | Explicit selection; show saved data/account consequences. Reinstall through the current official Store listing after matching publisher/PFN. Do not promise old app data/progress. |
| 2: user workflows/data | Photos, Paint, Camera, ScreenSketch, Clipchamp, ZuneMusic, ZuneVideo, SoundRecorder, StickyNotes, Calculator, Notepad, Terminal, Alarms, PowerAutomateDesktop | Require replacement/data-export checklist specific to the app. Save Notepad tabs, notes, recordings, projects and terminal profiles first. Reinstall via verified Store/WinGet identity; repair/reset may be preferable. |
| 3: connectivity/shell/gaming | Microsoft.YourPhone, MicrosoftWindows.CrossDevice, Microsoft.OutlookForWindows, Microsoft.XboxGamingOverlay, MicrosoftWindows.Client.WebExperience | No preset removal. Preview calls/camera/notifications/mail/capture/widgets consequences. Preserve dependent services/packages. Only offer after exact build integration and reinstall tests. |
| 4: legacy/availability uncertain | DevHome, Getstarted, WindowsMaps, People, SkypeApp, XboxApp, Microsoft3DViewer, MixedReality.Portal | Detect whether still installed/supported. Do not advertise guaranteed Store reinstall. Some components have been discontinued or removed from distribution. Keep archived package evidence and OS-specific repair guidance. |
| Separate choices | Microsoft.GetHelp, Microsoft.Copilot | Help access and AI preference respectively; no default “junk” label. Confirm installed package, future availability and whether another integration uses it. |

These tiers cover the complete baseline allowlist conceptually; the exact PFNs/publishers must be resolved from installed inventory rather than guessed from display names. Microsoft's current [deprecation list](https://learn.microsoft.com/en-us/windows/whats-new/deprecated-features) records Store removal for Maps (July 2025) and 3D Viewer (July 2026), so “reinstall anything from Store” is already too broad.

### Removal transaction contract

Resolve the exact PackageFullName for the initiating SID immediately before review and again before removal. Require its expected publisher, PFN, version, architecture and main-package role; reject frameworks, resource packages, non-removable/system components and unreviewed dependencies. Persist display name/PFN/full name/version/dependents/reinstall recipe and data-loss acknowledgement before removal. Re-query registration afterward. Do not execute the legacy console path with weaker checks; route it through the same engine.

Reinstall recipe must include a verified Store product ID or exact WinGet source/ID, publisher, verification date and prerequisites. Where no current product is available, say “reinstall not established” before removal. Never invent product IDs or use a blanket Add-AppxPackage registration loop as guaranteed restoration. If provisioning was removed, a compatible signed package/source image and dependency chain are separate prerequisites.

Acceptance evidence: clean VM snapshot, exact OS/edition/app versions, package graph before/after, logged-in and newly created user behavior, Start/Search/Store sign-in/install, Windows Update, default app handling, Xbox/Game Bar/GameInput, Phone Link/Widgets as applicable, reboot and reinstall result, and deliberate retained-data checks. Any failed dependency moves the item to protected until investigated.

## G. Gaming and hardware

### Game configuration

The existing narrow per-field approach and closed-game check are worth keeping. Add a plugin **data** format interpreted by trusted code; plugins cannot contain PowerShell/C# or arbitrary commands.

Proposed plugin fields:

~~~json
{
  "schemaVersion": 1,
  "id": "fortnite",
  "pluginVersion": 1,
  "publisher": "Epic Games",
  "processNames": ["FortniteClient-Win64-Shipping"],
  "locatorId": "FortniteLocalSettings",
  "format": "ini",
  "encodingPolicy": "preserve",
  "requiresClosedGame": true,
  "cloudSyncPolicy": "detect-and-warn",
  "supportedGameVersions": [],
  "fields": [],
  "driverProfile": {
    "provider": "nvidia-drs",
    "application": "fortniteclient-win64-shipping.exe",
    "presetIds": ["competitive", "potato"]
  }
}
~~~

This is a structural example, not an enabled plugin: empty supported versions/fields means inspect-only. A field entry needs section/key, type/range/enum, duplicate-key policy, exact source, supported game revision and restart behavior. Trusted locator IDs resolve known folders and approved relative paths. Regex/process names are bounded, normalized data. Separate game config and GPU profile operations in both schema and UI.

Preserve unknown keys/comments/newline/BOM/encoding. Refuse ambiguous duplicates and unsupported versions. Read exact original bytes; recheck file identity and game processes immediately before replace; do not alter ACLs, force read-only files, stop cloud sync or kill games. After launching/closing the game, offer a read-only comparison to detect launcher/game normalization. Cloud sync creates an external writer, not proof of tool failure.

No primary anti-cheat exemption was established for these exact Fortnite/Siege editors. Ordinary config editing is not equivalent to an anti-cheat bypass, but no “ban-proof” promise is justified. Keep away from process injection, protected game files, binaries, executable hooks and undocumented enforcement bypasses.

### NVIDIA potato correction

The 3.4 implementation targets the existing Fortnite NVIDIA DRS application profile with four allowlisted texture settings and saved prior inheritance/local state. Positive Direct3D LOD bias encoding is taken from the upstream inspector mapping; official NVAPI IDs alone do not prove a visible effect in the current renderer. Epic's current support says DX11 was removed and Performance uses DX12. Keep it explicitly experimental, compare same-scene images and measured frames, and restore on no benefit.

Sources: [NVIDIA exact header revision](https://github.com/NVIDIA/nvapi/blob/70d337db9186e968eab622f7e786de7e437faf3d/NvApiDriverSettings.h); [Inspector encoding revision](https://github.com/Orbmu2k/nvidiaProfileInspector/blob/2994194abe61f6807a3ea2015cdd875f6e1fc67b/nvidiaProfileInspector/CustomSettingNames.xml); [Epic DX11 notice](https://www.epicgames.com/help/c-34254770/c-33726977/a25166658); [Epic rendering modes](https://www.epicgames.com/help/c-34254770/c-38015632/my-rendering-mode-option-in-fortnite-was-not-saved-a22616652); [D3D12 sampler](https://learn.microsoft.com/en-us/windows/win32/api/d3d12/ns-d3d12-d3d12_sampler_desc). All accessed 2026-10-22.

### Runtime hardware inventory

| Information | Preferred read-only source | Honest limitation |
|---|---|---|
| OS branch/build/UBR/edition | Windows version APIs/registry plus edition query | Marketing version alone misses cumulative updates/staged features |
| CPU/model/topology | CIM Win32_Processor plus GetSystemCpuSetInformation / logical processor APIs | EfficiencyClass/cache topology helps identify hybrid structure; X3D behavior and scheduling policy cannot be inferred from a name alone |
| GPU/vendor/adapter LUID/driver | DXGI enumeration and signed installed-driver inventory | Multiple adapters/hybrid graphics; report which adapter rendered the game |
| Display/refresh/HDR/VRR | QueryDisplayConfig + DisplayConfigGetDeviceInfo; DXGI display/color capabilities | Advertised capability differs from effective game mode/VRR operation |
| RAM | CIM Win32_PhysicalMemory capacity, Speed/ConfiguredClockSpeed | SMBIOS values are not proof of active XMP/EXPO or FCLK; show unknown unless vendor-supported evidence exists |
| Storage | Storage/CIM disk and volume APIs | Avoid destructive benchmarks and unsupported “health” interpretation |
| NIC | Get-NetAdapter/advanced properties, PnP/driver identity | Property labels/valid values vary by driver; no universal keyword value |
| Power | powercfg read-only active/query + AC/battery status | Plans differ by platform; hidden values require appropriate query mode |
| HAGS/MPO/Game Mode | Supported UI/API/driver capability plus configured registry state | Separate configured from effective; no binary green check from a private value alone |
| Temperature/power | Vendor-supported telemetry if available | Sampling overhead, permission and GPU/model support vary; absence is unknown |

Sources: [CPU sets](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getsystemcpusetinformation) (2025-10-31); [CPU set structure](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-system_cpu_set_information); [display paths](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-querydisplayconfig); [physical memory](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-physicalmemory). Handle variable-size CPU records and display-buffer retry races; never hard-code this review PC's 5700X3D/3060 Ti/240 Hz as the user's hardware.

### AMD/Intel parity

Use the same provider interface: DetectCapabilities → Inspect → PlanDiff → Apply → Readback → Restore. Availability can differ; parity means truthful equivalent workflows, not pretending all vendors expose NVIDIA's settings.

- AMD's current [ADLX](https://gpuopen.com/adlx/) is version 2.0 and exposes supported display/graphics/monitoring/tuning surfaces. Begin read-only, then implement a tiny documented per-game feature set with capability checks and snapshot/restore. Do not infer an NVIDIA LOD equivalent exists.
- Intel's [Graphics Control Library](https://github.com/intel/drivers.gpu.control-library) provides driver interfaces for supported display/media/3D/telemetry. Respect per-driver/per-device feature support and 64-bit telemetry requirements; no blind registry clone of Arc Control.
- [NVML](https://developer.nvidia.com/management-library-nvml) is useful for supported NVIDIA telemetry but is not a universal consumer GPU settings API. Query capabilities; do not assume every GeForce exposes every data-center-oriented metric.

## H. UX, accessibility and architecture

Code observations: search/filter and several AutomationProperties names already exist; the app uses standard WPF controls alongside custom cards/toggles. The manifest is system-DPI-aware, the UI has a large minimum width and a custom dark palette. These observations do not establish keyboard, Narrator, contrast or multi-monitor correctness; no interactive accessibility audit was performed.

Implement in order:

1. Persistent mode banner: Preview, User changes, or elevated machine operation. Every mutator goes through one dispatch capability check. Preview can inspect/read and create a local report, never apply/Undo/reconnect/remove.
2. Review diff with exact scope/account/resource, before/target, risk, expected effective refresh and irreversible effects. Use words as well as color; explain deletion versus opposite value versus Undo.
3. Operation progress with a stable operation ID and phase. Cancellation before mutation is immediate; after mutation stop at a safe boundary and reconcile, never abandon state mid-write. Native subprocess timeout is not proof the OS operation stopped.
4. Error panel gives actionable category, last known state, journal location and retry/recovery route. Export redacted diagnostics only after user choice; strip account names, paths, IPs, package lists where unnecessary.
5. Keyboard navigation/access keys, visible focus, Escape/cancel and default-button safety. UIA names/help/state for custom switches and progress; status changes announce without stealing focus. Verify Narrator and Windows high contrast; use system colors/resources and light/dark preferences.
6. Reflow at 100/125/150/200/250% and multiple monitors, text scaling and small screens. Per-monitor DPI requires layout validation, not merely a manifest edit. Localization moves strings into resources, includes pluralization and long/RTL text.
7. First run detects missing prerequisites, managed machine and available recovery. Never preselect high-risk actions. Let users search by intent and uncertainty, not just a count of tweaks.

[Competitor matrix](KKxtti-DEEP-REVIEW.md#5-competitor-comparison) describes current source-verified comparisons. O&O's current 3.6.1135 release is 2026-09-29 and includes category filters/localization; its prior 3.5 includes voice/keyboard work. These are useful design references, not evidence that all its security choices should be copied. [Changelog](https://www.oo-software.com/en/shutup10/changelog).

### Refactoring route

Keep the WPF shell initially. Extract PowerShell engines into a module with explicit exports and typed request/result schemas. Replace interpolated command strings with an operation-ID dispatcher and bounded data arguments; retain SetVariable-based parameter passing. Move shared registry/file/journal/identity helpers into one implementation. Then introduce a minimal authenticated elevated broker for device operations. Port only complex/error-prone providers to C# once the contract and acceptance corpus are stable.

A wholesale rewrite makes recovery regressions harder to isolate. Suggested effort: dispatcher/module 1–2 weeks; state/identity/broker 3–6 weeks; provider-by-provider C# migration 1–3 days each after tests, plus integration. These estimates are engineering judgments and overlap with the roadmap; they are not additional promised calendar totals.

## I. Test and release strategy

No new unit/integration test suites were run during this review. Existing mocked test results are historical evidence only and do not certify final recovery corrections.

| Layer | Concrete cases | Gate / evidence |
|---|---|---|
| Pester 5 | Every write/Undo/deletion/type/mask; conflict and compensation injection; alternate SID; preview entry points; invalid journal | Pin Pester 5.9.0 for PS5.1/7.4+ as documented; fail if any real registry/network/native mutator escapes mocks |
| PSScriptAnalyzer | Approved rule baseline; unbound parameters, dangerous aliases, encoding and compatibility | Pin version; each suppression needs rationale and expiry |
| C# unit tests | CSV quotes/newlines/BOM/culture, finite/range limits, percentile labels, cancellation and bridge errors | Golden small datasets; known exact expected values; no frame-as-independent significance shortcut |
| Catalog golden files | Count/IDs/schema, targets/kinds/masks, source dates, dependencies, policy gates | Reviewed semantic diff; changing a resource increments operation version |
| Parser fuzzing | JSON duplicate fields/depth/size/types; CSV huge/escaped/malformed cells; ZIP traversal/case/ADS/devices/symlinks/bombs | Bounded time/memory, fail closed, no writes outside a fresh scratch root |
| Recovery faults | Kill between Prepared/write/readback/status; corrupt/truncate/reorder journals; old release/machine/driver changes | Snapshot VM; no false Applied/Undone; retain conflict evidence |
| Windows VMs | 24H2 Enterprise while serviced; 25H2 Home/Pro/Enterprise; current 26H2 editions available under license; 26H1 only relevant hardware/image | Exact build/UBR/edition/app versions, reboot/sign-in, GPO/MDM variants; no unsupported image certification |
| UI automation | Keyboard-only, preview routes, all review dialogs, focus, screen-reader names, high contrast/scaling/localization | Automation plus manual accessibility review |
| Hardware lab | NVIDIA/AMD/Intel, hybrid/X3D CPU, battery/AC, VRR/HDR/multi-monitor, physical NICs, EAC/BattlEye games | Versioned manual records, repeated measurements; no VM-only driver/latency claim |

Pester 6 exists as of July 2026; the requested Pester 5 line is now maintenance, not the newest major. PS5.1 class caching can require fresh processes. V5 mocks can fall through to real commands when filters do not match: use deny-by-default mocks and isolate mutating modules. [Pester v5 installation](https://pester.dev/docs/v5/introduction/installation), [v5 mocking](https://pester.dev/docs/v5/usage/mocking).

Windows Sandbox is useful for bounded parser/launcher smoke tests; it is not Windows Home coverage or a complete inbox-app image. Microsoft notes missing inbox apps in 24H2 Sandbox, and its virtual GPU cannot validate real driver-profile behavior. Use explicit .wsb settings: read-only mapped input, networking disabled when unnecessary, and no writable host folder for destructive tests. [Sandbox installation](https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-install), [configuration](https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-configure-using-wsb-file).

Manual release blockers: data-deletion wording and cancellation, alternate-credential identity, boot recovery with BitLocker considerations, clean install/update/old-history access, physical display/network behavior and any claimed performance gain. Never perform a power-cut experiment on a user's working PC. Hardware instability, game-server variance and physical click-to-photon latency require dedicated evidence.

## J. Licensing, brands and disclosure

The reviewed project root/package does not establish a clear license for the new utility as a whole. Public source availability alone does not grant normal open-source reuse rights. Choose an appropriate license only after checking authorship and copied contributions; do not silently apply MIT to third-party code or inherited legacy assets. [GitHub licensing guidance](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository).

Profile Inspector's MIT notice is bundled; retain it and upstream ownership. NVIDIA's NVAPI source/header license must accompany relevant derived code; preserve the exact text and notices already included in source, not just an informal “uses NVAPI” line. Maintain THIRD-PARTY-NOTICES with component/version/license/source/hash and modifications. Legacy Hanzu/Hone-like assets require separate rights review; an unavailable original ZIP is not verified provenance.

Use game/GPU/Windows names descriptively. Do not imply NVIDIA, Microsoft, Epic, Ubisoft or another utility endorses the product. Avoid copied logos or trade dress without permission; trademark clearance for the chosen product name was not performed. Respect Windows/game licensing and anti-cheat rules; no activation bypass, OS protection disablement or claim of publisher approval.

Proposed SECURITY.md: supported versions; private GitHub vulnerability reporting; information to include (version/hash/repro/impact, redacted logs); no public upload of personal state; target acknowledgement window such as seven days labelled a maintainer commitment only if accepted; coordinated remediation/advisory process; no guarantee of bounties or fixed deadlines. Add a clear “security report versus performance support” distinction and document release-key compromise handling.

This section identifies engineering/legal-process requirements, not a jurisdiction-specific legal conclusion or a new license grant.
