# FOCS Utility

GitHub Pages source and release download for FOCS Utility v9.5.0 Hardened.

The v9.5.0 build adds a reviewed WinGet app installer for Chromium, Discord, Steam, Epic Games Launcher, and Logitech Onboard Memory Manager. Each app is selected explicitly and installed by exact package ID.

## Publish with GitHub Pages

1. Create a public GitHub repository.
2. Add the contents of this directory to the repository root.
3. In **Settings → Pages**, select **Deploy from a branch**.
4. Choose the default branch and the root (`/`) directory, then save.

The site is plain HTML with no build step or external dependencies.

## Safety

FOCS runs with administrator privileges and can change Windows registry, service, power, AppX, QoS, and network-adapter state. Review the source, use its backup facilities, and benchmark changes on the target computer.
