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

## First Launch

Current public builds are not notarized by Apple, so macOS may show a security warning the first time you open SLSwitch.

Use one of the standard macOS approval flows:

1. Right-click `SLSwitch.app` in `Applications`.
2. Choose `Open`.
3. Confirm that you want to open the app.

If macOS does not show the confirmation button, open `System Settings` -> `Privacy & Security` and use `Open Anyway` for SLSwitch.

Advanced users can remove the quarantine flag for this app only:

```bash
xattr -dr com.apple.quarantine /Applications/SLSwitch.app
```

Use this command only for builds downloaded from the official `Zhigalove/SLSwitch` GitHub releases. Do not disable Gatekeeper globally.

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
