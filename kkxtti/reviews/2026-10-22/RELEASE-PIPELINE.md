# Hardened release pipeline and supply-chain assessment

Proposed implementation plan, 2026-10-22. Confidence high for trust-boundary findings; medium for cost/eligibility choices, which require the maintainer's actual legal identity and account configuration. Nothing here claims the current unsigned bundle is signed, attested or immutable.

## What the current launcher protects

The baseline launcher in source/web/Launcher Core.ps1 validates supported Windows/architecture, constrains archive paths and inventory, and checks pinned archive, manifest and file hashes before launch. These are useful consistency checks. The pin is embedded in **kkxtti.ps1 fetched from mutable main**. An attacker who can change that script can change the pin or remove checking altogether. irm | iex executes the script before any independent authentication of its contents.

| Compromise | What an attacker could do | What current hashes accomplish |
|---|---|---|
| ZIP asset altered while reviewed launcher remains trusted | Replace binaries/scripts | Pinned archive digest rejects mismatch |
| File in cached package modified before launcher validation | Substitute code | Per-file validation rejects mismatch at that check |
| Cached script modified after validation, or EXE started directly | Supply altered script to elevated execution | No continuously enforced immutable execution boundary |
| Repository/account capable of changing main | Replace launcher, payload, hashes and explanations | No independent publisher authentication |
| Pages only | Replace displayed command/link/instructions | Existing independently obtained launcher pin may still help; newly copied attacker command does not |
| Upstream unsigned helper release compromised | Ship malicious helper from plausible upstream location | Matching upstream digest does not establish trustworthy source/build |
| Signing account or protected release workflow compromised | Produce a signed malicious new version | Signing identifies an approved publisher/build path; it does not prove benign behavior |

“Download and inspect” is a better default interaction, but people cannot realistically audit an entire bundle at each launch. Provide a signed versioned installer or protected package, exact release notes, hashes and reproducible evidence. Keep the one-liner as an explicitly optional advanced entry point. Pin a bootstrap version/commit and document how to compare a publisher signature or out-of-band digest; changing main to a different mutable URL is not a new trust root. PowerShell execution policy is not a security boundary. [Microsoft execution-policy documentation](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies/).

## Distribution options

| Option | Fit for KKxtti | Decision |
|---|---|---|
| Signed installer + protected Program Files code and separate state | Directly addresses mutable elevated code; permits a small signed broker | Preferred near-term design; install/update atomically; no writable script search paths |
| WinGet manifest | Exact version, publisher/license metadata and InstallerSha256; discoverability/update channel | Add after license/signing/install semantics are settled; use existing validation, never ignore security hashes |
| Scoop | Portable per-user distribution and manifest hashes; bucket itself is a trust dependency | Optional channel; per-user writable code still needs safe elevation design |
| Chocolatey | Package scripting, checksums and community moderation | Secondary channel; do not add a second mutable download/execute bootstrap |
| MSIX | Protected package files and separate state; packaging/virtualization changes matter | Prototype after broker boundaries; full-trust packaging is not automatically AppContainer isolation |
| Current ZIP | Easy to inspect and use offline; weak install ownership | Retain advanced portable mode with explicit limitations; no claim of elevated tamper resistance |

Sources: [WinGet manifests](https://learn.microsoft.com/windows/package-manager/package/manifest); [Scoop official project](https://github.com/ScoopInstaller/Scoop); [Chocolatey security](https://docs.chocolatey.org/en-us/information/security/); [MSIX containerization](https://learn.microsoft.com/en-us/windows/msix/msix-containerization-overview); [Microsoft elevation guidance](https://blogs.windows.com/windowsdeveloper/2025/05/19/enhance-your-application-security-with-administrator-protection/) (2025-05-19). Distribution does not waive Windows security or organization policy.

## Signing options for a solo maintainer

- **Microsoft Artifact Signing:** the current pricing page lists Basic at US$9.99/month for 5,000 signatures; verify local currency/taxes and current pricing before procurement. Public-trust eligibility currently differs for organizations and individuals: the quickstart lists several supported organization regions, while individuals are limited to the US/Canada. Do not infer eligibility from this PC's timezone or assume every Azure subscription qualifies. Paid subscription and identity validation are prerequisites. [Pricing](https://azure.microsoft.com/en-us/products/artifact-signing), [eligibility](https://learn.microsoft.com/en-us/azure/artifact-signing/quickstart), [FAQ](https://learn.microsoft.com/en-us/azure/artifact-signing/faq), accessed 2026-10-22.
- **SignPath Foundation:** apply after establishing an OSI-compatible project license, maintained public source, documented builds, project reputation and required account protections. Acceptance is not guaranteed. Its terms require manual approval of signing requests and restrict signing to the project's own software; do not re-sign an upstream unsigned helper as if KKxtti authored it. The Foundation publisher identity may differ from the project name. [Terms](https://signpath.org/terms), current page accessed 2026-10-22.
- **Commercial OV/EV certificate:** obtain quotes only after choosing the legal publisher and key-storage/provider model. No vendor-specific current price was verified. Do not purchase EV solely to promise a warning-free first launch: Microsoft's current guidance says new OV and EV files can still show SmartScreen reputation warnings. [SmartScreen reputation](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation), accessed 2026-10-22.

Sign executable code, the broker, applicable PowerShell scripts and installer; timestamp through the chosen provider and verify chain, publisher and timestamp on the resulting bytes. Never put a PFX/password in the repository. Prefer short-lived workload identity to a narrowly scoped signing service, restricted to the protected release workflow and environment. Public trust, SmartScreen reputation and Smart App Control compatibility are related but distinct checks.

## Concrete pipeline

This outline deliberately avoids pretend pinned action SHAs. Before adding a workflow, resolve each action/compiler/tool version to a reviewed immutable digest and commit it into a dependency lockfile. A floating action major tag is not a content pin.

1. **Repository preparation.** Choose and add the project license after ownership review; add SECURITY.md, CONTRIBUTING, supported-version policy and third-party notices. Protect main/tags/workflows, require MFA and reviewed release changes. A solo maintainer can still use a protected manual signing environment and a separate publish credential.
2. **Unprivileged pull-request job.** No signing or release secrets. Checkout exact commit. Record runner image, OS, .NET/PowerShell/compiler versions. Run static parsing, PSScriptAnalyzer with scoped documented suppressions, schema/duplicate/link validation, mocked unit tests and parser fuzz corpus. Forked code never receives a signing token. These checks are proposed, not executed by this review.
3. **Pinned build job.** Build C# 7.3/.NET 4.8 and PowerShell 5.1-compatible source. Pin Roslyn/SDK if replacing the ambient Framework compiler; retain the existing compiler only with a recorded version and explicit reproducibility limitation. All package dependencies have fixed versions, source URLs, digests and license identifiers.
4. **Reproducibility comparison.** Two clean builds of the same unsigned source/dependencies. Normalize only declared build paths/timestamps, record all differences, and compare unsigned payloads before signing. Authenticode timestamps and ZIP metadata prevent naive final-byte reproducibility; publish unsigned-build digests plus a clear transformation record. Never strip differences merely to make hashes match.
5. **Integration gate.** Disposable Windows client VM matrix and manual hardware evidence described in WORKSTREAMS-B-J.md. A generic windows-latest hosted runner is a build environment, not certification for Home/Pro/Enterprise UI/driver behavior. Record image versions and results.
6. **Inventory/SBOM.** Include all EXEs/scripts/source/config/licensing files, bundled Profile Inspector and reference data, NVIDIA header-derived binding provenance, build tools and redistributables where applicable. Choose a supported CycloneDX or SPDX version and validate against that specification. Include hashes, supplier, license expression, dependency relationships and unknowns. SBOM is inventory, not a vulnerability-free certificate. [CycloneDX](https://cyclonedx.org/specification/overview/), [SPDX](https://spdx.dev/use/specifications/).
7. **Protected signing job.** Download the exact successful build artifact by digest. Recheck source commit, review approval and environment. Sign only allowlisted project outputs. Verify signatures after signing. Preserve upstream helper signatures/status and licenses separately.
8. **Package after signing.** Generate the final per-file manifest from final signed bytes; include every permitted file and reject unexpected executable content. Package with forward-slash ZIP names and bounded extraction rules. Hash the ZIP and manifest last. Generate release metadata from one source of truth for version, architecture, hashes and requirements.
9. **Attest.** Produce provenance for the final artifact digest, plus SBOM attestation if supported. Record repository, workflow identity, commit, dependencies, builder and verification instructions. Attestation helps establish build origin, not absence of code flaws. Claims about SLSA level must match the actual isolation and provenance architecture, not the mere presence of an attestation action. [GitHub artifact attestations](https://docs.github.com/en/actions/concepts/security/artifact-attestations).
10. **Draft, review, publish.** Upload all signed payloads, hashes, SBOM, provenance and evidence to a draft GitHub Release. Verify downloaded bytes/signatures/attestations using a separate job/identity. Enable immutable releases before publication and publish only once all assets are attached. GitHub's feature protects published assets/tags; notes/latest labels remain mutable, and it does not prevent an authorized attacker publishing a malicious new release. [Immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases).
11. **Update distribution atomically.** Update the website, optional bootstrap and package-manager manifests to the exact release metadata. Prefer immutable release URLs. Keep old versions and journals accessible. Do not silently overwrite a previously published version.
12. **Incident response.** Publish a security advisory and withdraw affected distribution pointers; preserve evidence and immutable historical assets. Rotate credentials, investigate the source/build/signing chain, publish a higher fixed version and clearly identify affected digests. Do not erase history to make an incident disappear.

Suggested permissions: build jobs contents:read only; attest job adds only the required id-token/attestations permissions; publish job contents:write only after the protected gate. Never use pull_request_target to execute untrusted PR code with privileged credentials. Confirm exact current action requirements when implementing.

## NVIDIA components and Chromium

Profile Inspector 3.0.2.1 is an optional upstream MIT component. Preserve LICENSE.txt and exact upstream provenance; it is not NVIDIA-signed software. The current launch helper hashes its runtime files and does not silently import a profile. Updating requires renewed source/license/digest review and a new bundle version. Launch unelevated when possible; a full driver-profile editor cannot be made harmless by calling it “sandboxed.” An isolated VM cannot alter the user's real driver profile as its useful purpose.

The custom NvidiaApi.cs bridge is narrower: installed nvapi64.dll, fixed applications and setting IDs, snapshots/readback/Undo. Retain the NVIDIA license/attribution for header-derived code and the exact header revision. The 3.4 change uses documented IDs with a community-observed LOD encoding, so rendering behavior remains an experiment. See the bundled NVIDIA POTATO RESEARCH.txt and [official NVAPI headers](https://github.com/NVIDIA/nvapi).

Chromium snapshot generation pins which object is downloaded; metadata MD5 is an integrity check from the same origin. A locally computed SHA-256 after download is an audit record, not an independent expected digest. Prefer stable vendor browsers installed through their supported channel. If snapshots remain, label their update/support limits, enforce HTTP size/time/cancellation and streamed-byte limits before extraction, and keep all ZIP path/duplicate/size checks.

## AV false positives and claims

Release scans should record artifact hash, scanner/signature version, time, result and any submission reference. Never disable Defender or tell users to add a broad exclusion to install the utility. Submit a suspected false positive through the vendor's developer process and retain its determination. [Microsoft submissions](https://learn.microsoft.com/en-us/defender-xdr/submission-guide).

Do not upload user journals/logs or private files to public scanning services. VirusTotal's own 2018 Monitor paper contrasts public file sharing with its private service; current service terms/eligibility must be checked before automating uploads. [Vendor paper](https://vt-gtm-wp-media.storage.googleapis.com/vtmonitor-use-case-mitigating-false-positives.pdf). No new VirusTotal submission or antivirus scan was performed here. An old clean scan does not certify a newly compiled executable.
