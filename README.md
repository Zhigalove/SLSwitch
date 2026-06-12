# SLSwitch

Simple Language Switcher for macOS.

SLSwitch is a small native macOS utility for switching keyboard input sources with familiar Windows-style modifier shortcuts.

## Features

- Windows-style language switching on macOS.
- Modifier-only shortcuts that feel natural during typing.
- Lightweight background app with an optional status bar icon.
- GitHub Releases-based updates from inside the app.

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

Each GitHub release should include the DMG installer:

```text
SLSwitch-Installer.dmg
```

Use version tags like `v0.1.1`. The app checks the latest GitHub release, compares the tag with `CFBundleShortVersionString`, and downloads the attached DMG when an update is available.

## Notes

- SLSwitch cycles through selectable input sources configured in macOS.
- Modifier-only shortcuts can conflict with macOS system shortcuts if the same combination is enabled in Keyboard Shortcuts.
- Local builds are ad-hoc signed. Public distribution should use Developer ID signing and notarization; otherwise macOS may require Accessibility permission again after an update.
