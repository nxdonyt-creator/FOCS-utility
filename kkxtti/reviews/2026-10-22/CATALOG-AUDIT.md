# Audit of all 104 controls

Baseline: KKxtti 3.3.0, reviewed 2026-10-22. Exactly 16 built-in definitions plus 88 JSON entries; 57 JSON entries label their evidence “Reference implementation.” Each row below maps to the actual shipped definition, not an inferred setting. Full registry targets follow the decision table.

## Reading the decisions

“Documented” describes the named setting or policy, not a measured gaming benefit. “Unverified” means this review did not establish the exact current write contract; it does not prove the feature never works. All runtime effectiveness is unmeasured here. Windows 24H2/25H2/26H1/26H2 need separate capability tests; 26H1 is a hardware-specific branch. A minimum build alone is not certification. See [Windows release information](https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information), accessed 2026-10-22.

Confidence: high for exact catalog transcription and documented policy semantics; medium for proposed disposition; low for effectiveness of private registry writes. Unless explicitly dated, the publication/update date was not established; access date is 2026-10-22. Repository links are implementation evidence only. For each managed policy, show configured/effective/origin separately and block conflicting organization-managed writes. Off=null means delete the override, not Undo. Undo restores the journaled prior value.

## Decisions

| # | ID / current name | Evidence assessment | Required change / applicability | Primary source or implementation lead | Source date |
|---|---|---|---|---|---|
| 1 | game-mode — Game Mode | Partial documentation | AutoGameModeEnabled is listed by Microsoft; AllowAutoGameMode companion write is unverified. Keep Game Mode as an ordinary preference; capability-detect and verify both stored and effective status. No universal gain. | [Source](https://learn.microsoft.com/en-us/windows/apps/develop/settings/settings-windows-11) | Publication/update date not established; accessed 2026-10-22 |
| 2 | no-capture — Disable Windows game recording | Unverified exact write contract | Two private per-user values are used. The documented AllowGameDVR device policy is a different contract. Prefer opening Captures settings until per-build behavior and recording scope are established. | [Source](https://github.com/ChrisTitusTech/winutil) | Publication/update date not established; accessed 2026-10-22 |
| 3 | no-ads — Disable advertising ID | Unverified exact write contract | Privacy preference, not a performance control. A same-named CSP or Settings option does not establish these exact HKCU writes. Detect account/managed policy and verify UI after sign-in. | [Source](https://github.com/ChrisTitusTech/winutil) | Publication/update date not established; accessed 2026-10-22 |
| 4 | no-tailored — Disable tailored experiences | Unverified exact write contract | Privacy preference, not a performance control. A same-named CSP or Settings option does not establish these exact HKCU writes. Detect account/managed policy and verify UI after sign-in. | [Source](https://github.com/ChrisTitusTech/winutil) | Publication/update date not established; accessed 2026-10-22 |
| 5 | no-tips — Reduce Windows tips | Unverified private preference | Numeric ContentDeliveryManager identifiers/private flags require clean-VM evidence per Windows branch. Offer experimental preference only; do not label all promotions or installs disabled. | [Source](https://github.com/ChrisTitusTech/winutil) | Publication/update date not established; accessed 2026-10-22 |
| 6 | no-welcome — Hide the Windows welcome experience | Unverified private preference | Numeric ContentDeliveryManager identifiers/private flags require clean-VM evidence per Windows branch. Offer experimental preference only; do not label all promotions or installs disabled. | [Source](https://github.com/ChrisTitusTech/winutil) | Publication/update date not established; accessed 2026-10-22 |
| 7 | no-settings-suggestions — Reduce suggestions in Settings | Unverified private preference | Numeric ContentDeliveryManager identifiers/private flags require clean-VM evidence per Windows branch. Offer experimental preference only; do not label all promotions or installs disabled. | [Source](https://github.com/ChrisTitusTech/winutil) | Publication/update date not established; accessed 2026-10-22 |
| 8 | extensions — Show file extensions | Unverified exact write contract | Familiar UI preference, but exact current DWORD contract and effective refresh were not verified here. Keep optional after build validation; Off is a chosen opposite value, not guaranteed default. Taskbar alignment portability docs use a different representation. | [Source](https://github.com/ChrisTitusTech/winutil) | Publication/update date not established; accessed 2026-10-22 |
| 9 | hidden-files — Show hidden files | Unverified exact write contract | Familiar UI preference, but exact current DWORD contract and effective refresh were not verified here. Keep optional after build validation; Off is a chosen opposite value, not guaranteed default. Taskbar alignment portability docs use a different representation. | [Source](https://github.com/ChrisTitusTech/winutil) | Publication/update date not established; accessed 2026-10-22 |
| 10 | compact — Compact File Explorer | Unverified exact write contract | Familiar UI preference, but exact current DWORD contract and effective refresh were not verified here. Keep optional after build validation; Off is a chosen opposite value, not guaranteed default. Taskbar alignment portability docs use a different representation. | [Source](https://github.com/ChrisTitusTech/winutil) | Publication/update date not established; accessed 2026-10-22 |
| 11 | no-taskview — Hide the Task View button | Unverified exact write contract | Familiar UI preference, but exact current DWORD contract and effective refresh were not verified here. Keep optional after build validation; Off is a chosen opposite value, not guaranteed default. Taskbar alignment portability docs use a different representation. | [Source](https://github.com/ChrisTitusTech/winutil) | Publication/update date not established; accessed 2026-10-22 |
| 12 | no-search — Hide taskbar search | Unverified exact write contract | Familiar UI preference, but exact current DWORD contract and effective refresh were not verified here. Keep optional after build validation; Off is a chosen opposite value, not guaranteed default. Taskbar alignment portability docs use a different representation. | [Source](https://github.com/ChrisTitusTech/winutil) | Publication/update date not established; accessed 2026-10-22 |
| 13 | left-taskbar — Left-align the taskbar | Unverified exact write contract | Familiar UI preference, but exact current DWORD contract and effective refresh were not verified here. Keep optional after build validation; Off is a chosen opposite value, not guaranteed default. Taskbar alignment portability docs use a different representation. | [Source](https://github.com/ChrisTitusTech/winutil) | Publication/update date not established; accessed 2026-10-22 |
| 14 | no-transparency — Disable transparency | Documented status mapping | Microsoft common settings lists these exact values and 0/1 meanings. This is a settings/state reference, not a stable supported write API guarantee. Keep appearance preference and verify live refresh. | [Source](https://learn.microsoft.com/en-us/windows/apps/develop/settings/settings-common) | Publication/update date not established; accessed 2026-10-22 |
| 15 | dark-mode — Windows dark mode | Documented status mapping | Microsoft common settings lists these exact values and 0/1 meanings. This is a settings/state reference, not a stable supported write API guarantee. Keep appearance preference and verify live refresh. | [Source](https://learn.microsoft.com/en-us/windows/apps/develop/settings/settings-common) | Publication/update date not established; accessed 2026-10-22 |
| 16 | scrollbars — Always show scrollbars | Unverified exact write contract | Familiar UI preference, but exact current DWORD contract and effective refresh were not verified here. Keep optional after build validation; Off is a chosen opposite value, not guaranteed default. Taskbar alignment portability docs use a different representation. | [Source](https://github.com/ChrisTitusTech/winutil) | Publication/update date not established; accessed 2026-10-22 |
| 17 | activity-history — Disable Activity History | Legacy / partial relevance | Timeline UI and cross-device activity sync were deprecated/removed at different times. Do not infer all three policy values are consumed on every current branch. Inspect capabilities; retire ineffective rows. | [Source](https://learn.microsoft.com/en-us/windows/whats-new/deprecated-features) | Deprecation entries through 2026; individual Timeline/sync dates differ |
| 18 | consumer-features — Disable consumer app promotions | Documented policy; edition gate | DisableWindowsConsumerFeatures is documented for Enterprise/Education/IoT, not Pro. Existing edition restriction is useful; normalize SKU variants rather than exact display strings. Upgrade Evidence from reference implementation. | [Source](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-experience#allowwindowsconsumerfeatures) | Publication/update date not established; accessed 2026-10-22 |
| 19 | delivery-peers — Disable Delivery Optimization peer sharing | Documented policy; incomplete gate | DODownloadMode=0 disables peering while retaining HTTP download. Policy scope is device, Pro/Enterprise/Education/IoT; Home support not established by CSP. Upgrade evidence and keep bandwidth label. | [Source](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-deliveryoptimization#dodownloadmode) | Publication/update date not established; accessed 2026-10-22 |
| 20 | location-consent — Deny location access for this account | Unverified exact write contract | ConsentStore write may not represent all per-app/desktop permissions. Preserve privacy choice, prefer Settings link, and do not claim global location shutoff. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 21 | device-metadata — Prevent device companion metadata downloads | Deprecated feature | Device metadata deprecated May 2025; no universal removal date was established. Detect remaining component. Do not present as disabling Windows driver updates. | [Source](https://learn.microsoft.com/en-us/windows/whats-new/deprecated-features) | May 2025 deprecation entry |
| 22 | background-apps — Disable background activity for legacy Windows apps | Legacy / partial relevance | GlobalUserDisabled is not proof that arbitrary Win32 apps or modern app-specific background settings are disabled. Rename narrowly and retain experimental status pending runtime evidence. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 23 | diagnostic-data — Limit diagnostics to required data | Documented policy; incomplete gate | AllowTelemetry=1 is required diagnostic data. Policy docs list Pro/Enterprise/Education/IoT; zero is not generally available on Pro. Does not govern every application telemetry channel. Upgrade evidence. | [Source](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-system#allowtelemetry) | Publication/update date not established; accessed 2026-10-22 |
| 24 | online-speech — Disable online speech recognition | Unverified exact write contract | HasAccepted is a user consent flag; cited Privacy CSP does not by itself document this exact write. Prefer supported Settings interaction; no measured gaming gain. | [Source](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-privacy) | Publication/update date not established; accessed 2026-10-22 |
| 25 | inking-learning — Disable handwriting personalization | Unverified exact write contract | Separate personalization/data preferences. Current component consumption, stored learned-data retention and restart behavior need per-build tests; do not claim old learned data is erased. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 26 | typing-learning — Disable typing personalization | Unverified exact write contract | Separate personalization/data preferences. Current component consumption, stored learned-data retention and restart behavior need per-build tests; do not claim old learned data is erased. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 27 | typing-diagnostics — Disable typing improvement data | Unverified exact write contract | Separate personalization/data preferences. Current component consumption, stored learned-data retention and restart behavior need per-build tests; do not claim old learned data is erased. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 28 | contact-learning — Disable contact harvesting for predictions | Unverified exact write contract | Separate personalization/data preferences. Current component consumption, stored learned-data retention and restart behavior need per-build tests; do not claim old learned data is erased. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 29 | feedback-prompts — Reduce feedback prompts | Unverified exact write contract | NumberOfSIUFInPeriod alone needs current behavior evidence. A prompt preference is not proof of all diagnostics disabled. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 30 | app-launch-tracking — Disable app launch tracking | Unverified exact write contract | Start_TrackProgs affects a private shell preference; document effects on app suggestions/search only after per-build verification. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 31 | recent-docs — Hide recent documents in Start and jump lists | Partial documentation | Microsoft common settings lists Start_TrackDocs but labels its type REG_BOOL. That is not a Windows RegistryValueKind. Resolve documentation ambiguity with registry/API and UI evidence; do not invent a REG_BOOL writer. | [Source](https://learn.microsoft.com/en-us/windows/apps/develop/settings/settings-common) | Publication/update date not established; accessed 2026-10-22 |
| 32 | search-history — Disable device search history | Unverified exact write contract | Private SearchSettings values differ from documented device Search policies. Validate account scope and current Search experience; use exact mapped policy only where edition permits. | [Source](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-search) | Publication/update date not established; accessed 2026-10-22 |
| 33 | search-highlights — Disable search highlights | Unverified exact write contract | Private SearchSettings values differ from documented device Search policies. Validate account scope and current Search experience; use exact mapped policy only where edition permits. | [Source](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-search) | Publication/update date not established; accessed 2026-10-22 |
| 34 | bing-search — Disable File Explorer search suggestions | Documented policy; incomplete gate | Name in 3.3 is correctly File Explorer search suggestions. Keep it; the historical id bing-search is misleading. Policy docs cover user scope Pro/Enterprise/Education/IoT, not a universal Start web-search toggle. | [Source](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-admx-windowsexplorer#disablesearchboxsuggestions) | Publication/update date not established; accessed 2026-10-22 |
| 35 | notifications-center — Disable notification and calendar flyouts | Unverified current scope | Need exact policy/preference evidence and notification/calendar regression checks. Disabling notifications can hide useful alerts; no gaming preset. Preserve explicit selection. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 36 | toast-notifications — Disable app toast notifications | Unverified current scope | Need exact policy/preference evidence and notification/calendar regression checks. Disabling notifications can hide useful alerts; no gaming preset. Preserve explicit selection. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 37 | lock-screen — Skip the lock screen | Unverified edition/build behavior | NoLockScreen behavior needs current edition-specific documentation and verification. Must not disable lock/authentication; explain that skipping a presentation screen does not remove sign-in. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 38 | login-blur — Disable logon acrylic blur | Unverified current write contract | Cosmetic/diagnostic preference only. Verify exact current behavior and removal semantics; no performance rationale. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 39 | verbose-logon — Show verbose logon status | Unverified current write contract | Cosmetic/diagnostic preference only. Verify exact current behavior and removal semantics; no performance rationale. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 40 | verbose-bsod — Show additional blue-screen parameters | Unverified current write contract | Cosmetic/diagnostic preference only. Verify exact current behavior and removal semantics; no performance rationale. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 41 | long-paths — Enable long filesystem paths | Documented setting; application dependent | LongPathsEnabled alone is insufficient: an application must opt in with longPathAware and may cache policy. Keep developer preference, do not promise all apps accept long paths. | [Source](https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation) | Publication/update date not established; accessed 2026-10-22 |
| 42 | numlock — Enable Num Lock for this account | Unverified complete bit representation | Whole-string 2/0 replaces any pre-existing flag representation. Inspect unknown values and refuse destructive normalization. HKU .DEFAULT is the system/logon hive, not a template for all future users. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 43 | numlock-logon — Enable Num Lock on the sign-in screen | Unverified complete bit representation | Whole-string 2/0 replaces any pre-existing flag representation. Inspect unknown values and refuse destructive normalization. HKU .DEFAULT is the system/logon hive, not a template for all future users. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 44 | window-snapping — Enable window snapping | Unverified exact write contract | Retain as appearance/workflow preference after live SystemParametersInfo/Settings validation, not a gaming optimization. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 45 | no-sticky-shortcut — Disable the Sticky Keys shortcut | Documented API flags; registry transport unverified | Flags 0x4 hotkey and 0x1 enabled are distinct. Preserve other bits; use SPI_GETSTICKYKEYS/SPI_SETSTICKYKEYS for live state. Registry string write alone does not prove effective state. | [Source](https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-stickykeys) | Win32 documentation, accessed 2026-10-22 |
| 46 | no-filter-shortcut — Disable the Filter Keys shortcut | Documented API flag; registry transport unverified | 0x4 is FKF_HOTKEYACTIVE. Use SPI_GETFILTERKEYS/SPI_SETFILTERKEYS preserving timing fields and other flags. Do not disable an accessibility feature silently. | [Source](https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-filterkeys) | Publication/update date not established; accessed 2026-10-22 |
| 47 | no-toggle-shortcut — Disable the Toggle Keys shortcut | Documented API flag; registry transport unverified | 0x4 is TKF_HOTKEYACTIVE. Preserve feature-enable and sound bits; use SPI_GETTOGGLEKEYS/SPI_SETTOGGLEKEYS to confirm live state. | [Source](https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-togglekeys) | 2021-04-02 |
| 48 | no-mouse-acceleration — Disable desktop mouse acceleration | Unverified current registry transport | Desktop pointer preference; raw-input games may use a different path. Use documented SPI mouse operations and UI validation. Off 1/6/10 is not the previous user configuration. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 49 | end-task — Enable taskbar End Task | Documented UI; exact key unverified | Advanced Settings documents the End Task feature, not necessarily this private DWORD as a stable API. Detect feature availability. Warn it can terminate without saving. | [Source](https://learn.microsoft.com/en-us/windows/advanced-settings/) | Publication/update date not established; accessed 2026-10-22 |
| 50 | battery-percentage — Show taskbar battery percentage | Staged feature / unverified key | Require battery hardware and a current feature-capability check; generic MinBuild 22000 is insufficient for later taskbar features. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 51 | storage-sense — Disable automatic Storage Sense cleanup | Unverified private representation | Numeric StoragePolicy value needs per-build verification. Disabling automatic cleanup is a storage preference, not an FPS improvement. Do not trigger cleanup as a side effect. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 52 | folder-discovery — Use generic Explorer folder templates | Unverified private shell contract | CLSID/Bags/namespace/private Explorer settings can change with shell updates. Keep experimental, preserve full pre-existing state, and validate Explorer restart and default-value deletion. No blanket speed claim. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 53 | explorer-thispc — Open Explorer to This PC | Unverified private shell contract | CLSID/Bags/namespace/private Explorer settings can change with shell updates. Keep experimental, preserve full pre-existing state, and validate Explorer restart and default-value deletion. No blanket speed claim. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 54 | explorer-home — Hide Explorer Home from navigation | Unverified private shell contract | CLSID/Bags/namespace/private Explorer settings can change with shell updates. Keep experimental, preserve full pre-existing state, and validate Explorer restart and default-value deletion. No blanket speed claim. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 55 | explorer-gallery — Hide Explorer Gallery from navigation | Unverified private shell contract | CLSID/Bags/namespace/private Explorer settings can change with shell updates. Keep experimental, preserve full pre-existing state, and validate Explorer restart and default-value deletion. No blanket speed claim. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 56 | classic-context — Use the classic context menu | Unverified private shell contract | CLSID/Bags/namespace/private Explorer settings can change with shell updates. Keep experimental, preserve full pre-existing state, and validate Explorer restart and default-value deletion. No blanket speed claim. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 57 | no-widgets — Hide Widgets on the taskbar | Unverified private shell contract | TaskbarDa hides a button, not necessarily the Widgets runtime or all feeds. Do not advertise removal or memory savings without measurement. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 58 | no-taskbar-badges — Disable taskbar notification badges | Unverified exact write contract | Appearance/accessibility preference. Some Microsoft portability representations differ from these private values. Use documented live APIs where available and validate per branch; no measured FPS claim. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 59 | no-taskbar-flashing — Disable taskbar app flashing | Unverified exact write contract | Appearance/accessibility preference. Some Microsoft portability representations differ from these private values. Use documented live APIs where available and validate per branch; no measured FPS claim. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 60 | no-title-shake — Disable title-bar shake | Unverified exact write contract | Appearance/accessibility preference. Some Microsoft portability representations differ from these private values. Use documented live APIs where available and validate per branch; no measured FPS claim. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 61 | no-animation — Disable desktop window animations | Unverified exact write contract | Appearance/accessibility preference. Some Microsoft portability representations differ from these private values. Use documented live APIs where available and validate per branch; no measured FPS claim. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 62 | no-selection-fade — Disable translucent selection boxes | Unverified exact write contract | Appearance/accessibility preference. Some Microsoft portability representations differ from these private values. Use documented live APIs where available and validate per branch; no measured FPS claim. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 63 | no-icon-shadow — Disable desktop icon label shadows | Unverified exact write contract | Appearance/accessibility preference. Some Microsoft portability representations differ from these private values. Use documented live APIs where available and validate per branch; no measured FPS claim. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 64 | no-taskbar-animation — Disable taskbar animations | Unverified exact write contract | Appearance/accessibility preference. Some Microsoft portability representations differ from these private values. Use documented live APIs where available and validate per branch; no measured FPS claim. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 65 | no-sync-notices — Hide Explorer sync-provider suggestions | Unverified private shell contract | Hide promotional notices only; does not disable OneDrive sync, protect cloud files, or remove the provider. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 66 | no-lock-tips — Disable lock-screen tips | Unverified private preference | Numeric ContentDeliveryManager identifiers/private flags require clean-VM evidence per Windows branch. Offer experimental preference only; do not label all promotions or installs disabled. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 67 | no-auto-apps — Disable suggested app silent installs | Unverified private preference | Numeric ContentDeliveryManager identifiers/private flags require clean-VM evidence per Windows branch. Offer experimental preference only; do not label all promotions or installs disabled. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 68 | no-preinstalled-promos — Disable preinstalled app promotions | Unverified private preference | Numeric ContentDeliveryManager identifiers/private flags require clean-VM evidence per Windows branch. Offer experimental preference only; do not label all promotions or installs disabled. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 69 | outlook-migration — Prevent automatic new Outlook migration | Application policy; capability required | Verify installed classic Outlook channel/version and effective Office policy. Registry presence alone does not show migration is blocked across every Outlook distribution. Do not uninstall Outlook or touch mailbox data. | [Source](https://learn.microsoft.com/en-us/microsoft-365-apps/outlook/manage/admin-controlled-migration-policy) | Publication/update date not established; accessed 2026-10-22 |
| 70 | no-recall — Disable Recall and delete saved snapshots | Documented destructive policy | DisableAIDataAnalysis can delete saved snapshots. Require eligible Recall-capable device/component, exact policy scope and destructive confirmation on every write including compensation. Undo cannot restore snapshots. | [Source](https://learn.microsoft.com/en-us/windows/client-management/manage-recall) | Publication/update date not established; accessed 2026-10-22 |
| 71 | no-copilot — Disable legacy Windows Copilot integration | Deprecated legacy policy | TurnOffWindowsCopilot targets old Windows Copilot integration, not the current standalone app. Gate legacy component/build (22621.2361+ in documented 22H2 branch), hide if absent. | [Source](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-windowsai) | 2026-09-23 |
| 72 | utc-clock — Use UTC for the hardware clock | Unverified current support contract | Dual-boot clock preference with timekeeping side effects. Keep inspect/manual guidance until exact current Windows support evidence; no gaming preset. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 73 | no-wpbt — Disable firmware WPBT execution | Unverified current support contract | Firmware/OEM security-sensitive behavior. Inspect only until Microsoft/OEM applicability and recovery are established; do not infer performance benefit from a reference implementation. | [Source](https://github.com/ChrisTitusTech/winutil/blob/07ccd8e2e755a706f31569808b31f5b77acad6a9/config/tweaks.json) | Publication/update date not established; accessed 2026-10-22 |
| 74 | no-mpo — Disable Multiplane Overlay for troubleshooting | Documented vendor troubleshooting | Keep targeted troubleshoot/Undo only. Updated NVIDIA guidance describes MPO benefits; disabling can regress performance/power. No automatic FPS recommendation. | [Source](https://nvidia.custhelp.com/app/answers/detail/a_id/5157) | 2026-09-28 |
| 75 | hags — Enable hardware-accelerated GPU scheduling | Documented feature; key support incomplete | Hardware/driver capability and restart required. Introduction blog is not current universal benchmark evidence; use Windows effective state plus A/B/A, not just HwSchMode readback. | [Source](https://devblogs.microsoft.com/directx/hardware-accelerated-gpu-scheduling/) | 2020-06-30 |
| 76 | edge-startup — Disable Edge startup boost | Documented vendor policy | Edge 88+; dynamic, device-wide; personal Microsoft-account profiles supported. Startup speed can be affected. Registry write success alone is not browser acceptance. | [Source](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/startupboostenabled) | 2026-05-22 |
| 77 | edge-background — Disable Edge background mode | Documented vendor policy | Edge 77+; dynamic, device-wide; personal Microsoft-account profiles supported. Closing windows may now stop background features. Registry write success alone is not browser acceptance. | [Source](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/backgroundmodeenabled) | 2026-05-22 |
| 78 | edge-shopping — Disable Edge shopping suggestions | Documented vendor policy | Edge 87+; dynamic, per-profile; policy table excludes Microsoft-account signed-in profiles. Verify effective policy. Registry write success alone is not browser acceptance. | [Source](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/edgeshoppingassistantenabled) | 2026-05-22 |
| 79 | edge-rewards — Hide Microsoft Rewards in Edge | Documented vendor policy | Edge 88+; restart; documentation account-applicability table and description disagree. Flag uncertainty and require edge://policy + account test. Registry write success alone is not browser acceptance. | [Source](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/showmicrosoftrewards) | 2026-05-22 |
| 80 | edge-personalization — Disable Edge personalization reporting | Documented vendor policy | Edge 80+; dynamic, per-profile; not applicable to child/enterprise accounts according to description. Do not generalize to all telemetry. Registry write success alone is not browser acceptance. | [Source](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/personalizationreportingenabled) | 2026-05-22 |
| 81 | edge-feedback — Disable Edge feedback submission | Documented vendor policy | Edge 77+; restart, device-wide. Personal Microsoft-account profiles supported. Registry write success alone is not browser acceptance. | [Source](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/userfeedbackallowed) | 2026-09-11 |
| 82 | edge-first-run — Hide Edge first-run experience | Documented vendor policy | Edge 80+; restart, device-wide. Suppresses first-run UI; does not independently disable every automatic sign-in path. Registry write success alone is not browser acceptance. | [Source](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/hidefirstrunexperience) | 2026-05-22 |
| 83 | edge-error-pages — Disable Edge alternate error-page suggestions | Documented vendor policy | Edge 80+; dynamic, per-profile; table excludes Microsoft-account signed-in profiles. Registry write success alone is not browser acceptance. | [Source](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/alternateerrorpagesenabled) | 2026-05-22 |
| 84 | edge-default-prompt — Disable Edge default-browser campaigns | Documented vendor policy | Edge 113+; dynamic, per-profile; personal Microsoft-account profiles supported. Registry write success alone is not browser acceptance. | [Source](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/defaultbrowsersettingscampaignenabled) | 2026-05-22 |
| 85 | edge-promotions — Disable Edge recommendations | Documented vendor policy | Edge 89+; dynamic, per-profile; table excludes Microsoft-account signed-in profiles. Registry write success alone is not browser acceptance. | [Source](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/showrecommendationsenabled) | 2026-05-22 |
| 86 | edge-do-not-track — Send Do Not Track requests in Edge | Documented vendor policy | Edge 77+; dynamic, per-profile; table excludes Microsoft-account signed-in profiles. A request is not enforced tracking prevention. Registry write success alone is not browser acceptance. | [Source](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/configuredonottrack) | 2026-05-22 |
| 87 | edge-games-menu — Hide Edge's games menu | Deprecated vendor policy | Edge 99+; restart; DEPRECATED but documented as still operating. HubsSidebarEnabled replacement is broader; do not silently substitute. Registry write success alone is not browser acceptance. | [Source](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/allowgamesmenu) | 2026-05-22 |
| 88 | brave-rewards — Disable Brave Rewards | Documented vendor policy | Minimum version not stated in reviewed vendor page; capability-detect. Verify brave://policy after reload/restart; preserve organization policy. Preference, no measured FPS gain. | [Source](https://support.brave.app/hc/en-us/articles/360039248271-Group-Policy) | 2026-08-10 |
| 89 | brave-wallet — Disable Brave Wallet | Documented vendor policy | Minimum version not stated in reviewed vendor page; capability-detect. Verify brave://policy after reload/restart; preserve organization policy. Preference, no measured FPS gain. | [Source](https://support.brave.app/hc/en-us/articles/360039248271-Group-Policy) | 2026-08-10 |
| 90 | brave-vpn — Disable Brave VPN features | Documented vendor policy | Minimum version not stated in reviewed vendor page; capability-detect. Verify brave://policy after reload/restart; preserve organization policy. Preference, no measured FPS gain. | [Source](https://support.brave.app/hc/en-us/articles/360039248271-Group-Policy) | 2026-08-10 |
| 91 | brave-ai — Disable Brave Leo AI chat | Documented vendor policy | Minimum version not stated in reviewed vendor page; capability-detect. Verify brave://policy after reload/restart; preserve organization policy. Preference, no measured FPS gain. | [Source](https://support.brave.app/hc/en-us/articles/360039248271-Group-Policy) | 2026-08-10 |
| 92 | brave-news — Disable Brave News | Documented vendor policy | Brave 1.82.x+. Verify brave://policy after reload/restart; preserve organization policy. Preference, no measured FPS gain. | [Source](https://support.brave.app/hc/en-us/articles/360039248271-Group-Policy) | 2026-08-10 |
| 93 | brave-stats — Disable Brave daily stats ping | Documented vendor policy | Brave 1.83.x+. Verify brave://policy after reload/restart; preserve organization policy. Preference, no measured FPS gain. | [Source](https://support.brave.app/hc/en-us/articles/360039248271-Group-Policy) | 2026-08-10 |
| 94 | brave-p3a — Disable Brave P3A analytics | Documented vendor policy | Brave 1.83.x+. Verify brave://policy after reload/restart; preserve organization policy. Preference, no measured FPS gain. | [Source](https://support.brave.app/hc/en-us/articles/360039248271-Group-Policy) | 2026-08-10 |
| 95 | brave-discovery — Disable Brave web discovery contributions | Documented vendor policy | Brave 1.83.x+. Verify brave://policy after reload/restart; preserve organization policy. Preference, no measured FPS gain. | [Source](https://support.brave.app/hc/en-us/articles/360039248271-Group-Policy) | 2026-08-10 |
| 96 | ipv4-preferred — Prefer IPv4 while keeping IPv6 | Documented mask | 0x20 prefers IPv4 without disabling IPv6. Offer only for a concrete network issue; reboot/effective prefix policy verification. Conflict with full DisabledComponents write. | [Source](https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/configure-ipv6-in-windows) | Publication/update date not established; accessed 2026-10-22 |
| 97 | ipv6-disable — Disable IPv6 components | Documented but discouraged blanket action | Microsoft recommends keeping IPv6. Remove from general presets; inspect/troubleshooting-only. Full 0xFF overwrites sibling masked controls and can break dependent connectivity. | [Source](https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/configure-ipv6-in-windows) | Publication/update date not established; accessed 2026-10-22 |
| 98 | teredo-disable — Disable Teredo tunneling | Documented mask | 0x8 disables Teredo; can affect applications relying on it. Separate from IPv6 preference; shared resource requires combined mask planning and conflict handling. | [Source](https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/configure-ipv6-in-windows) | Publication/update date not established; accessed 2026-10-22 |
| 99 | notepad-ai — Disable Notepad AI features | Documented application policy | Requires Windows 11 22H2+ and Notepad 11.2503.16.0+; detect package version. Present as AI preference, not performance optimization. | [Source](https://learn.microsoft.com/en-us/windows/client-management/manage-notepad) | Publication/update date not established; accessed 2026-10-22 |
| 100 | settings-home — Hide Settings Home | Documented list policy; merge required | PageVisibilityList maps to SettingsPageVisibility; preserve other hide/showonly entries and managed policy. Existing SafePrevious refusal is preferable to clobbering a list. Require Home page capability and supported edition. | [Source](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-settings#pagevisibilitylist) | Publication/update date not established; accessed 2026-10-22 |
| 101 | start-recommendations — Hide Start recommendations | Documented policy; incomplete gate | Current documentation lists Pro/Enterprise/Education/IoT and user/device scope on 22H2+. Home behavior not established. Old Enterprise-only guidance is stale; capability/effective checks still needed. | [Source](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-start#hiderecommendedsection) | Publication/update date not established; accessed 2026-10-22 |
| 102 | new-outlook — Prefer new Outlook | Application preference; capability required | UseNewOutlook is documented for opting users into new Outlook. Detect classic Outlook and account support; opposite preference is not full application rollback. | [Source](https://learn.microsoft.com/en-us/microsoft-365-apps/outlook/get-started/start-users-new-outlook) | Publication/update date not established; accessed 2026-10-22 |
| 103 | sticky-keys — Enable Sticky Keys | Documented API flags; registry transport unverified | Flags 0x4 hotkey and 0x1 enabled are distinct. Preserve other bits; use SPI_GETSTICKYKEYS/SPI_SETSTICKYKEYS for live state. Registry string write alone does not prove effective state. | [Source](https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-stickykeys) | Win32 documentation, accessed 2026-10-22 |
| 104 | mmcss-reservation — MMCSS CPU reservation comparison | Documented setting; benefit unmeasured | 10 versus 20 is a valid experiment. Less than 10 maps to 20; zero is not zero reservation. Keep excluded from presets, require participating workload and repeated measurement. | [Source](https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service) | Publication/update date not established; accessed 2026-10-22 |

## Exact baseline targets and shipped gates

These are a transcription for review, not commands to apply. Every resource uses the process-default registry view in 3.3.0; proposed v2 must state Registry64 explicitly. Empty Editions means the current code has no edition restriction, not that every edition is supported. Current-user means the process identity, which can change after alternate-credential elevation. No REG_BOOL kind is proposed.

### game-mode

Baseline gate: MinBuild 22000; Editions []; Evidence Windows preference.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\GameBar",
    "Name": "AllowAutoGameMode",
    "Kind": "DWord",
    "On": 1,
    "Off": 0
  },
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\GameBar",
    "Name": "AutoGameModeEnabled",
    "Kind": "DWord",
    "On": 1,
    "Off": 0
  }
]
~~~

### no-capture

Baseline gate: MinBuild 22000; Editions []; Evidence Windows preference.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\GameDVR",
    "Name": "AppCaptureEnabled",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  },
  {
    "Hive": "HKCU",
    "Path": "System\\GameConfigStore",
    "Name": "GameDVR_Enabled",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### no-ads

Baseline gate: MinBuild 22000; Editions []; Evidence Windows preference.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\AdvertisingInfo",
    "Name": "Enabled",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### no-tailored

Baseline gate: MinBuild 22000; Editions []; Evidence Windows preference.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\Privacy",
    "Name": "TailoredExperiencesWithDiagnosticDataEnabled",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### no-tips

Baseline gate: MinBuild 22000; Editions []; Evidence Windows preference.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\ContentDeliveryManager",
    "Name": "SubscribedContent-338389Enabled",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### no-welcome

Baseline gate: MinBuild 22000; Editions []; Evidence Windows preference.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\ContentDeliveryManager",
    "Name": "SubscribedContent-310093Enabled",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### no-settings-suggestions

Baseline gate: MinBuild 22000; Editions []; Evidence Windows preference.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\ContentDeliveryManager",
    "Name": "SubscribedContent-338393Enabled",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  },
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\ContentDeliveryManager",
    "Name": "SubscribedContent-353694Enabled",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  },
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\ContentDeliveryManager",
    "Name": "SubscribedContent-353696Enabled",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### extensions

Baseline gate: MinBuild 22000; Editions []; Evidence Windows preference.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
    "Name": "HideFileExt",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### hidden-files

Baseline gate: MinBuild 22000; Editions []; Evidence Windows preference.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
    "Name": "Hidden",
    "Kind": "DWord",
    "On": 1,
    "Off": 2
  }
]
~~~

### compact

Baseline gate: MinBuild 22000; Editions []; Evidence Windows preference.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
    "Name": "UseCompactMode",
    "Kind": "DWord",
    "On": 1,
    "Off": 0
  }
]
~~~

### no-taskview

Baseline gate: MinBuild 22000; Editions []; Evidence Windows preference.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
    "Name": "ShowTaskViewButton",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### no-search

Baseline gate: MinBuild 22000; Editions []; Evidence Windows preference.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\Search",
    "Name": "SearchboxTaskbarMode",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### left-taskbar

Baseline gate: MinBuild 22000; Editions []; Evidence Windows preference.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
    "Name": "TaskbarAl",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### no-transparency

Baseline gate: MinBuild 22000; Editions []; Evidence Windows preference.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
    "Name": "EnableTransparency",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### dark-mode

Baseline gate: MinBuild 22000; Editions []; Evidence Windows preference.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
    "Name": "AppsUseLightTheme",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  },
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
    "Name": "SystemUsesLightTheme",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### scrollbars

Baseline gate: MinBuild 22000; Editions []; Evidence Windows preference.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Control Panel\\Accessibility",
    "Name": "DynamicScrollbars",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### activity-history

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKLM",
    "Path": "Software\\Policies\\Microsoft\\Windows\\System",
    "Name": "EnableActivityFeed",
    "Kind": "DWord",
    "On": 0,
    "Off": null
  },
  {
    "Hive": "HKLM",
    "Path": "Software\\Policies\\Microsoft\\Windows\\System",
    "Name": "PublishUserActivities",
    "Kind": "DWord",
    "On": 0,
    "Off": null
  },
  {
    "Hive": "HKLM",
    "Path": "Software\\Policies\\Microsoft\\Windows\\System",
    "Name": "UploadUserActivities",
    "Kind": "DWord",
    "On": 0,
    "Off": null
  }
]
~~~

### consumer-features

Baseline gate: MinBuild 22000; Editions ["Enterprise","Education","EnterpriseS","IoTEnterprise"]; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKLM",
    "Path": "Software\\Policies\\Microsoft\\Windows\\CloudContent",
    "Name": "DisableWindowsConsumerFeatures",
    "Kind": "DWord",
    "On": 1,
    "Off": null
  }
]
~~~

### delivery-peers

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKLM",
    "Path": "Software\\Policies\\Microsoft\\Windows\\DeliveryOptimization",
    "Name": "DODownloadMode",
    "Kind": "DWord",
    "On": 0,
    "Off": null
  }
]
~~~

### location-consent

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\CapabilityAccessManager\\ConsentStore\\location",
    "Name": "Value",
    "Kind": "String",
    "On": "Deny",
    "Off": "Allow"
  }
]
~~~

### device-metadata

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKLM",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\Device Metadata",
    "Name": "PreventDeviceMetadataFromNetwork",
    "Kind": "DWord",
    "On": 1,
    "Off": null
  }
]
~~~

### background-apps

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\BackgroundAccessApplications",
    "Name": "GlobalUserDisabled",
    "Kind": "DWord",
    "On": 1,
    "Off": 0
  }
]
~~~

### diagnostic-data

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKLM",
    "Path": "Software\\Policies\\Microsoft\\Windows\\DataCollection",
    "Name": "AllowTelemetry",
    "Kind": "DWord",
    "On": 1,
    "Off": null
  }
]
~~~

### online-speech

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Speech_OneCore\\Settings\\OnlineSpeechPrivacy",
    "Name": "HasAccepted",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### inking-learning

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\InputPersonalization",
    "Name": "RestrictImplicitInkCollection",
    "Kind": "DWord",
    "On": 1,
    "Off": 0
  }
]
~~~

### typing-learning

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\InputPersonalization",
    "Name": "RestrictImplicitTextCollection",
    "Kind": "DWord",
    "On": 1,
    "Off": 0
  }
]
~~~

### typing-diagnostics

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Input\\TIPC",
    "Name": "Enabled",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### contact-learning

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\InputPersonalization\\TrainedDataStore",
    "Name": "HarvestContacts",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### feedback-prompts

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Siuf\\Rules",
    "Name": "NumberOfSIUFInPeriod",
    "Kind": "DWord",
    "On": 0,
    "Off": null
  }
]
~~~

### app-launch-tracking

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
    "Name": "Start_TrackProgs",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### recent-docs

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
    "Name": "Start_TrackDocs",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### search-history

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\SearchSettings",
    "Name": "IsDeviceSearchHistoryEnabled",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### search-highlights

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\SearchSettings",
    "Name": "IsDynamicSearchBoxEnabled",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### bing-search

Baseline gate: MinBuild 22000; Editions []; Evidence Documented policy.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Policies\\Microsoft\\Windows\\Explorer",
    "Name": "DisableSearchBoxSuggestions",
    "Kind": "DWord",
    "On": 1,
    "Off": null
  }
]
~~~

### notifications-center

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Policies\\Microsoft\\Windows\\Explorer",
    "Name": "DisableNotificationCenter",
    "Kind": "DWord",
    "On": 1,
    "Off": null
  }
]
~~~

### toast-notifications

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\PushNotifications",
    "Name": "ToastEnabled",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### lock-screen

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKLM",
    "Path": "Software\\Policies\\Microsoft\\Windows\\Personalization",
    "Name": "NoLockScreen",
    "Kind": "DWord",
    "On": 1,
    "Off": null
  }
]
~~~

### login-blur

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKLM",
    "Path": "Software\\Policies\\Microsoft\\Windows\\System",
    "Name": "DisableAcrylicBackgroundOnLogon",
    "Kind": "DWord",
    "On": 1,
    "Off": null
  }
]
~~~

### verbose-logon

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKLM",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\System",
    "Name": "VerboseStatus",
    "Kind": "DWord",
    "On": 1,
    "Off": null
  }
]
~~~

### verbose-bsod

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKLM",
    "Path": "System\\CurrentControlSet\\Control\\CrashControl",
    "Name": "DisplayParameters",
    "Kind": "DWord",
    "On": 1,
    "Off": null
  }
]
~~~

### long-paths

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKLM",
    "Path": "System\\CurrentControlSet\\Control\\FileSystem",
    "Name": "LongPathsEnabled",
    "Kind": "DWord",
    "On": 1,
    "Off": 0
  }
]
~~~

### numlock

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Control Panel\\Keyboard",
    "Name": "InitialKeyboardIndicators",
    "Kind": "String",
    "On": "2",
    "Off": "0"
  }
]
~~~

### numlock-logon

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKU",
    "Path": ".DEFAULT\\Control Panel\\Keyboard",
    "Name": "InitialKeyboardIndicators",
    "Kind": "String",
    "On": "2",
    "Off": "0"
  }
]
~~~

### window-snapping

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Control Panel\\Desktop",
    "Name": "WindowArrangementActive",
    "Kind": "String",
    "On": "1",
    "Off": "0"
  }
]
~~~

### no-sticky-shortcut

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Control Panel\\Accessibility\\StickyKeys",
    "Name": "Flags",
    "Kind": "String",
    "On": 0,
    "Off": 4,
    "Mask": 4
  }
]
~~~

### no-filter-shortcut

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Control Panel\\Accessibility\\Keyboard Response",
    "Name": "Flags",
    "Kind": "String",
    "On": 0,
    "Off": 4,
    "Mask": 4
  }
]
~~~

### no-toggle-shortcut

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Control Panel\\Accessibility\\ToggleKeys",
    "Name": "Flags",
    "Kind": "String",
    "On": 0,
    "Off": 4,
    "Mask": 4
  }
]
~~~

### no-mouse-acceleration

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Control Panel\\Mouse",
    "Name": "MouseSpeed",
    "Kind": "String",
    "On": "0",
    "Off": "1"
  },
  {
    "Hive": "HKCU",
    "Path": "Control Panel\\Mouse",
    "Name": "MouseThreshold1",
    "Kind": "String",
    "On": "0",
    "Off": "6"
  },
  {
    "Hive": "HKCU",
    "Path": "Control Panel\\Mouse",
    "Name": "MouseThreshold2",
    "Kind": "String",
    "On": "0",
    "Off": "10"
  }
]
~~~

### end-task

Baseline gate: MinBuild 22631; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced\\TaskbarDeveloperSettings",
    "Name": "TaskbarEndTask",
    "Kind": "DWord",
    "On": 1,
    "Off": 0
  }
]
~~~

### battery-percentage

Baseline gate: MinBuild 26100; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
    "Name": "IsBatteryPercentageEnabled",
    "Kind": "DWord",
    "On": 1,
    "Off": null
  }
]
~~~

### storage-sense

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\StorageSense\\Parameters\\StoragePolicy",
    "Name": "01",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### folder-discovery

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Classes\\Local Settings\\Software\\Microsoft\\Windows\\Shell\\Bags\\AllFolders\\Shell",
    "Name": "FolderType",
    "Kind": "String",
    "On": "NotSpecified",
    "Off": null
  }
]
~~~

### explorer-thispc

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
    "Name": "LaunchTo",
    "Kind": "DWord",
    "On": 1,
    "Off": 2
  }
]
~~~

### explorer-home

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Classes\\CLSID\\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}",
    "Name": "System.IsPinnedToNameSpaceTree",
    "Kind": "DWord",
    "On": 0,
    "Off": null
  }
]
~~~

### explorer-gallery

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Classes\\CLSID\\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}",
    "Name": "System.IsPinnedToNameSpaceTree",
    "Kind": "DWord",
    "On": 0,
    "Off": null
  }
]
~~~

### classic-context

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Classes\\CLSID\\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\\InprocServer32",
    "Name": "",
    "Kind": "String",
    "On": "",
    "Off": null
  }
]
~~~

### no-widgets

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
    "Name": "TaskbarDa",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### no-taskbar-badges

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
    "Name": "TaskbarBadges",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### no-taskbar-flashing

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
    "Name": "TaskbarFlashing",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### no-title-shake

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
    "Name": "DisallowShaking",
    "Kind": "DWord",
    "On": 1,
    "Off": 0
  }
]
~~~

### no-animation

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Control Panel\\Desktop\\WindowMetrics",
    "Name": "MinAnimate",
    "Kind": "String",
    "On": "0",
    "Off": "1"
  }
]
~~~

### no-selection-fade

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
    "Name": "ListviewAlphaSelect",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### no-icon-shadow

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
    "Name": "ListviewShadow",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### no-taskbar-animation

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
    "Name": "TaskbarAnimations",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### no-sync-notices

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
    "Name": "ShowSyncProviderNotifications",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### no-lock-tips

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\ContentDeliveryManager",
    "Name": "RotatingLockScreenOverlayEnabled",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### no-auto-apps

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\ContentDeliveryManager",
    "Name": "SilentInstalledAppsEnabled",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### no-preinstalled-promos

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\ContentDeliveryManager",
    "Name": "PreInstalledAppsEnabled",
    "Kind": "DWord",
    "On": 0,
    "Off": 1
  }
]
~~~

### outlook-migration

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Policies\\Microsoft\\Office\\16.0\\Outlook\\Options\\General",
    "Name": "DoNewOutlookAutoMigration",
    "Kind": "DWord",
    "On": 0,
    "Off": null
  }
]
~~~

### no-recall

Baseline gate: MinBuild 26100; Editions ["Professional","ProfessionalN","Enterprise","EnterpriseN","Education","EducationN","IoTEnterprise","IoTEnterpriseS"]; Evidence Documented policy.

~~~json
[
  {
    "Hive": "HKLM",
    "Path": "Software\\Policies\\Microsoft\\Windows\\WindowsAI",
    "Name": "DisableAIDataAnalysis",
    "Kind": "DWord",
    "On": 1,
    "Off": null
  }
]
~~~

### no-copilot

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Policies\\Microsoft\\Windows\\WindowsCopilot",
    "Name": "TurnOffWindowsCopilot",
    "Kind": "DWord",
    "On": 1,
    "Off": null
  }
]
~~~

### utc-clock

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKLM",
    "Path": "System\\CurrentControlSet\\Control\\TimeZoneInformation",
    "Name": "RealTimeIsUniversal",
    "Kind": "DWord",
    "On": 1,
    "Off": null
  }
]
~~~

### no-wpbt

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKLM",
    "Path": "System\\CurrentControlSet\\Control\\Session Manager",
    "Name": "DisableWpbtExecution",
    "Kind": "DWord",
    "On": 1,
    "Off": null
  }
]
~~~

### no-mpo

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKLM",
    "Path": "Software\\Microsoft\\Windows\\Dwm",
    "Name": "OverlayTestMode",
    "Kind": "DWord",
    "On": 5,
    "Off": null
  }
]
~~~

### hags

Baseline gate: MinBuild 22000; Editions []; Evidence Reference implementation.

~~~json
[
  {
    "Hive": "HKLM",
    "Path": "System\\CurrentControlSet\\Control\\GraphicsDrivers",
    "Name": "HwSchMode",
    "Kind": "DWord",
    "On": 2,
    "Off": 1
  }
]
~~~

### edge-startup

Baseline gate: MinBuild 22000; Editions []; Evidence Vendor policy.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Policies\\Microsoft\\Edge",
    "Name": "StartupBoostEnabled",
    "Kind": "DWord",
    "On": 0,
    "Off": null
  }
]
~~~

### edge-background

Baseline gate: MinBuild 22000; Editions []; Evidence Vendor policy.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Policies\\Microsoft\\Edge",
    "Name": "BackgroundModeEnabled",
    "Kind": "DWord",
    "On": 0,
    "Off": null
  }
]
~~~

### edge-shopping

Baseline gate: MinBuild 22000; Editions []; Evidence Vendor policy.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Policies\\Microsoft\\Edge",
    "Name": "EdgeShoppingAssistantEnabled",
    "Kind": "DWord",
    "On": 0,
    "Off": null
  }
]
~~~

### edge-rewards

Baseline gate: MinBuild 22000; Editions []; Evidence Vendor policy.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Policies\\Microsoft\\Edge",
    "Name": "ShowMicrosoftRewards",
    "Kind": "DWord",
    "On": 0,
    "Off": null
  }
]
~~~

### edge-personalization

Baseline gate: MinBuild 22000; Editions []; Evidence Vendor policy.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Policies\\Microsoft\\Edge",
    "Name": "PersonalizationReportingEnabled",
    "Kind": "DWord",
    "On": 0,
    "Off": null
  }
]
~~~

### edge-feedback

Baseline gate: MinBuild 22000; Editions []; Evidence Vendor policy.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Policies\\Microsoft\\Edge",
    "Name": "UserFeedbackAllowed",
    "Kind": "DWord",
    "On": 0,
    "Off": null
  }
]
~~~

### edge-first-run

Baseline gate: MinBuild 22000; Editions []; Evidence Vendor policy.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Policies\\Microsoft\\Edge",
    "Name": "HideFirstRunExperience",
    "Kind": "DWord",
    "On": 1,
    "Off": null
  }
]
~~~

### edge-error-pages

Baseline gate: MinBuild 22000; Editions []; Evidence Vendor policy.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Policies\\Microsoft\\Edge",
    "Name": "AlternateErrorPagesEnabled",
    "Kind": "DWord",
    "On": 0,
    "Off": null
  }
]
~~~

### edge-default-prompt

Baseline gate: MinBuild 22000; Editions []; Evidence Vendor policy.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Policies\\Microsoft\\Edge",
    "Name": "DefaultBrowserSettingsCampaignEnabled",
    "Kind": "DWord",
    "On": 0,
    "Off": null
  }
]
~~~

### edge-promotions

Baseline gate: MinBuild 22000; Editions []; Evidence Vendor policy.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Policies\\Microsoft\\Edge",
    "Name": "ShowRecommendationsEnabled",
    "Kind": "DWord",
    "On": 0,
    "Off": null
  }
]
~~~

### edge-do-not-track

Baseline gate: MinBuild 22000; Editions []; Evidence Vendor policy.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Policies\\Microsoft\\Edge",
    "Name": "ConfigureDoNotTrack",
    "Kind": "DWord",
    "On": 1,
    "Off": null
  }
]
~~~

### edge-games-menu

Baseline gate: MinBuild 22000; Editions []; Evidence Vendor policy.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Policies\\Microsoft\\Edge",
    "Name": "AllowGamesMenu",
    "Kind": "DWord",
    "On": 0,
    "Off": null
  }
]
~~~

### brave-rewards

Baseline gate: MinBuild 22000; Editions []; Evidence Vendor policy.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Policies\\BraveSoftware\\Brave",
    "Name": "BraveRewardsDisabled",
    "Kind": "DWord",
    "On": 1,
    "Off": null
  }
]
~~~

### brave-wallet

Baseline gate: MinBuild 22000; Editions []; Evidence Vendor policy.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Policies\\BraveSoftware\\Brave",
    "Name": "BraveWalletDisabled",
    "Kind": "DWord",
    "On": 1,
    "Off": null
  }
]
~~~

### brave-vpn

Baseline gate: MinBuild 22000; Editions []; Evidence Vendor policy.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Policies\\BraveSoftware\\Brave",
    "Name": "BraveVPNDisabled",
    "Kind": "DWord",
    "On": 1,
    "Off": null
  }
]
~~~

### brave-ai

Baseline gate: MinBuild 22000; Editions []; Evidence Vendor policy.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Policies\\BraveSoftware\\Brave",
    "Name": "BraveAIChatEnabled",
    "Kind": "DWord",
    "On": 0,
    "Off": null
  }
]
~~~

### brave-news

Baseline gate: MinBuild 22000; Editions []; Evidence Vendor policy.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Policies\\BraveSoftware\\Brave",
    "Name": "BraveNewsDisabled",
    "Kind": "DWord",
    "On": 1,
    "Off": null
  }
]
~~~

### brave-stats

Baseline gate: MinBuild 22000; Editions []; Evidence Vendor policy.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Policies\\BraveSoftware\\Brave",
    "Name": "BraveStatsPingEnabled",
    "Kind": "DWord",
    "On": 0,
    "Off": null
  }
]
~~~

### brave-p3a

Baseline gate: MinBuild 22000; Editions []; Evidence Vendor policy.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Policies\\BraveSoftware\\Brave",
    "Name": "BraveP3AEnabled",
    "Kind": "DWord",
    "On": 0,
    "Off": null
  }
]
~~~

### brave-discovery

Baseline gate: MinBuild 22000; Editions []; Evidence Vendor policy.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Policies\\BraveSoftware\\Brave",
    "Name": "BraveWebDiscoveryEnabled",
    "Kind": "DWord",
    "On": 0,
    "Off": null
  }
]
~~~

### ipv4-preferred

Baseline gate: MinBuild 22000; Editions []; Evidence Documented policy.

~~~json
[
  {
    "Hive": "HKLM",
    "Path": "System\\CurrentControlSet\\Services\\Tcpip6\\Parameters",
    "Name": "DisabledComponents",
    "Kind": "DWord",
    "On": 32,
    "Off": 0,
    "Mask": 32
  }
]
~~~

### ipv6-disable

Baseline gate: MinBuild 22000; Editions []; Evidence Documented policy.

~~~json
[
  {
    "Hive": "HKLM",
    "Path": "System\\CurrentControlSet\\Services\\Tcpip6\\Parameters",
    "Name": "DisabledComponents",
    "Kind": "DWord",
    "On": 255,
    "Off": 0
  }
]
~~~

### teredo-disable

Baseline gate: MinBuild 22000; Editions []; Evidence Documented policy.

~~~json
[
  {
    "Hive": "HKLM",
    "Path": "System\\CurrentControlSet\\Services\\Tcpip6\\Parameters",
    "Name": "DisabledComponents",
    "Kind": "DWord",
    "On": 8,
    "Off": 0,
    "Mask": 8
  }
]
~~~

### notepad-ai

Baseline gate: MinBuild 22621; Editions []; Evidence Documented policy.

~~~json
[
  {
    "Hive": "HKLM",
    "Path": "Software\\Policies\\WindowsNotepad",
    "Name": "DisableAIFeatures",
    "Kind": "DWord",
    "On": 1,
    "Off": null
  }
]
~~~

### settings-home

Baseline gate: MinBuild 22000; Editions []; Evidence Documented policy.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer",
    "Name": "SettingsPageVisibility",
    "Kind": "String",
    "On": "hide:home",
    "Off": null,
    "SafePrevious": [
      "hide:home"
    ]
  }
]
~~~

### start-recommendations

Baseline gate: MinBuild 22621; Editions []; Evidence Documented policy.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Policies\\Microsoft\\Windows\\Explorer",
    "Name": "HideRecommendedSection",
    "Kind": "DWord",
    "On": 1,
    "Off": null
  }
]
~~~

### new-outlook

Baseline gate: MinBuild 22000; Editions []; Evidence Documented application preference.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Software\\Microsoft\\Office\\16.0\\Outlook\\Preferences",
    "Name": "UseNewOutlook",
    "Kind": "DWord",
    "On": 1,
    "Off": 0
  }
]
~~~

### sticky-keys

Baseline gate: MinBuild 22000; Editions []; Evidence Windows bit flag.

~~~json
[
  {
    "Hive": "HKCU",
    "Path": "Control Panel\\Accessibility\\StickyKeys",
    "Name": "Flags",
    "Kind": "String",
    "Mask": 1,
    "On": 1,
    "Off": 0
  }
]
~~~

### mmcss-reservation

Baseline gate: MinBuild 22000; Editions []; Evidence Documented setting; benefit unmeasured.

~~~json
[
  {
    "Hive": "HKLM",
    "Path": "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile",
    "Name": "SystemResponsiveness",
    "Kind": "DWord",
    "On": 10,
    "Off": 20
  }
]
~~~

## Catalog-wide acceptance criteria

1. Every entry has an operation version, immutable resource identity, exact hive/view/type, explicit set/delete action, build branch and capability/app-version rules, risk and restart behavior.
2. Store source URL, source publication/update date (nullable), access date, exact supporting section and evidence class separately. Require runtime evidence before claiming effective support.
3. Validate unique ids, valid kinds, value ranges, mask subsets, empty default value names, dependencies and cycles. Reject masked deletes and overlapping incompatible writes before journaling.
4. Conflict matrix: all DisabledComponents writers overlap; Sticky Keys feature/hotkey are disjoint masks on one resource; SettingsPageVisibility is a shared list. Also model old and new releases, external tools and GPO/MDM.
5. Detect configured policy plus Resultant Set of Policy/MDM diagnostics where available. Unknown ownership stays unknown; domain membership alone is not proof that a specific setting is managed. [Policy conflict scope](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-controlpolicyconflict) does not establish universal precedence for every CSP.
6. A link checker confirms reachability and redirects, not truth. A maintainer reviews changed source text; VM evidence records exact build, edition, app version, restart and visible effective behavior.

## Useful additions, and exclusions

Add supported Settings links and read-only Windows Update status/active-hours/pause-expiry inspection first. A future policy control needs exact current CSP scope and organizational ownership detection; never disable servicing. Add OneDrive sync/status and selective-sync guidance, not automated cloud-file deletion. Recall/Copilot/Widgets should detect installed/current components, distinguish hiding from removal, and explain data consequences. Telemetry levels must respect edition and avoid “zero telemetry” marketing. Do not add broad service stripping, security/mitigation disabling, undocumented scheduler packs, blanket IPv6 removal, firmware hacks or a registry tweak count target. These are engineering recommendations, not claims of measured speedup.
