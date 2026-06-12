# SLSwitch

Simple Language Switcher for macOS.

SLSwitch is a small native macOS utility for switching keyboard input sources with familiar Windows-style modifier shortcuts.

## Features

- Switches to the next macOS input source with a modifier-only shortcut.
- Supports `Shift + Command`, `Shift + Option`, and `Shift + Control`.
- Lets you choose the active shortcut.
- Detects global modifier shortcuts through macOS Accessibility access.
- Optional status bar menu for quick switching and settings.
- Native settings window.
- Checks GitHub Releases for new versions from the app.

## Requirements

- macOS 13 or newer
- Apple Silicon Mac
- Accessibility permission

## Installation

Download `SLSwitch-Installer.dmg`, drag `SLSwitch.app` to `Applications`, then grant Accessibility access for `SLSwitch.app`.

Accessibility permission is preserved across updates only when releases are signed with the same Developer ID identity and the app stays at the same bundle path, usually `/Applications/SLSwitch.app`.

## Build

```bash
VERSION=0.1.1 BUILD_NUMBER=2 ./build_app.sh
```

The app is created at:

```text
build/SLSwitch.app
```

## Package

```bash
VERSION=0.1.1 BUILD_NUMBER=2 CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./package_dmg.sh
```

The installer is created at:

```text
build/SLSwitch-Installer.dmg
```

## Releases and Updates

In-app update checks read the latest release from `Zhigalove/SLSwitch` on GitHub. Attach the installer as:

```text
SLSwitch-Installer.dmg
```

Use version tags like `v0.1.1`. The app compares the release tag with `CFBundleShortVersionString`.

## Notes

- SLSwitch cycles through selectable input sources configured in macOS.
- Modifier-only shortcuts can conflict with macOS system shortcuts if the same combination is enabled in Keyboard Shortcuts.
- Local builds are ad-hoc signed. Public distribution should use Developer ID signing and notarization; otherwise macOS may require Accessibility permission again after an update.
