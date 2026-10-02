# Tendies Studio

A native iPadOS workspace for PosterBoard `.tendies` packages. The product has two equal workflows:

1. **Open and edit an existing package**: inspect its structure, preview assets, edit supported metadata and layers, validate it, and export a new package while preserving unknown files.
2. **Create a wallpaper from scratch**: choose an image, configure a supported layout and layers, preview the result, build a valid package from a known-good PosterBoard template, validate it, and export `.tendies`.

## Offline-first requirement

All end-user features must run locally on the iPad. No account, cloud service, analytics, remote API, or network connection may be required to import, create, edit, preview, validate, save, or export a project. Network access is limited to optional development/update distribution workflows, never runtime functionality.

## Installation target

- iPadOS only
- IPA intended for sideloading through LiveContainer
- The app must not require an Apple Developer subscription for its everyday offline workflow. IPA signing/import requirements depend on the user's LiveContainer and signing setup.
- Minimum target: iPadOS 17+

## Development status

This repository is an early SwiftUI scaffold, not a finished editor. It currently contains ZIP-based package import/export, a basic package browser, asset thumbnails, and structural checks. CAML editing, editable layer controls, the image-to-template creation flow, and compatibility-tested descriptor generation are not implemented yet. No successful Xcode build or installable IPA is claimed at this stage.

## Planned milestones

- **M1: Reliable package workspace**: robust import/export, package safety checks, persistent local projects, and clear descriptor/container detection.
- **M2: Existing-package editor**: asset replacement, metadata inspection/editing, CAML-aware layer controls, and preservation of unsupported data.
- **M3: New wallpaper wizard**: image import, crop/position controls, foreground/background layer setup, preview, and generation from validated templates.
- **M4: Compatibility and delivery**: test generated packages against known-good examples and supported iPadOS versions; produce an IPA suitable for the LiveContainer workflow.

## Build requirements

- Xcode 16+
- XcodeGen

Generate the project:

```sh
brew install xcodegen
xcodegen generate
open TendiesStudio.xcodeproj
```

Build:

```sh
xcodebuild -project TendiesStudio.xcodeproj -scheme TendiesStudio -destination 'generic/platform=iOS' -configuration Release build
```

## Package format notes

A `.tendies` file is ZIP-based, but a ZIP archive is not automatically a valid PosterBoard package. Descriptor and container packages have different restore semantics. New packages must be generated from validated templates and retain the required descriptor metadata, identifiers, CAML resources, and assets.

See [Nugget documentation](https://github.com/leminlimez/Nugget/blob/main/documentation.md) for documented package conventions.
