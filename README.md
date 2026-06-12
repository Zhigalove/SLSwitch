# SLSwitch

Simple Language Switcher for macOS.

SLSwitch is a small native macOS utility for switching keyboard input sources with familiar Windows-style modifier shortcuts.

## Features

- Switch macOS input sources with familiar Windows-style shortcuts.
- Choose one of three shortcuts: `Shift + Command`, `Shift + Option`, or `Shift + Control`.

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

## License

MIT License.
