# JustCopy

JustCopy is a native macOS menu bar app that copies text from on-screen regions that do not allow normal text selection.
Use a global shortcut, drag a screenshot area, run OCR with Vision, and place the recognized text into your clipboard.

## Features

- Native macOS implementation using SwiftUI and AppKit
- Global hotkey (`Command+Shift+2`) to start capture
- Drag-to-select overlay across connected displays
- OCR powered by Apple Vision (`VNRecognizeTextRequest`)
- Clipboard output through `NSPasteboard`
- Screen recording permission handling with recovery flow

## Requirements

- macOS 14.0+
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Quick Start

```bash
make run
```

On first use, macOS asks for Screen Recording permission. If access is denied, trigger capture again and open System Settings from the prompt.

## Install via Homebrew

```bash
brew tap zyuapp/tap
brew install --cask zyuapp/tap/just-copy
```

## Build Commands

```bash
make generate   # Generate JustCopy.xcodeproj via XcodeGen
make build      # Build Debug app into .build
make run        # Build and open the app
make clean      # Remove generated project and build artifacts
```

## Project Layout

- `project.yml` - XcodeGen project specification
- `JustCopy/` - macOS app source files
- `Makefile` - local build and run commands
