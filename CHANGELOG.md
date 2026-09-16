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
