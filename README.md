# Tendies Studio

A native iPadOS workspace for inspecting, creating from templates, editing, validating, and exporting PosterBoard `.tendies` packages.

## Status

Early development scaffold. The current app provides a native iPad interface, ZIP-based package inspection, safe asset replacement, and archive export. Full CAML editing and validated from-scratch descriptor generation are planned next.

## Requirements

- Xcode 16+
- iPadOS 17+
- XcodeGen

## Generate the Xcode project

```sh
brew install xcodegen
xcodegen generate
open TendiesStudio.xcodeproj
```

## Build

```sh
xcodebuild -project TendiesStudio.xcodeproj -scheme TendiesStudio -destination 'generic/platform=iOS' -configuration Release build
```

To export a signed IPA, configure an Apple Distribution certificate and provisioning profile in Xcode or the GitHub Actions secrets documented in `.github/workflows/ios.yml`.

## Package format

Tendies Studio treats a `.tendies` file as a ZIP-based package and preserves unknown files when editing. Descriptor packages and container packages have different restore semantics. Do not assume that an arbitrary folder is a valid PosterBoard descriptor: use a known-good template and validate all required metadata before export.

See [Nugget documentation](https://github.com/leminlimez/Nugget/blob/main/documentation.md) for the documented package conventions.
