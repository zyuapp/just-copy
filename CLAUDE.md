# JustCopy - CLAUDE.md

## Project Summary
- Native macOS menu bar app for OCR from selected screen regions.
- Stack: SwiftUI + AppKit + Vision + ScreenCaptureKit.
- App target: `JustCopy` (macOS 14+).

## Common Commands
```bash
make generate   # Generate JustCopy.xcodeproj from project.yml
make build      # Build Debug app into .build
make run        # Build and launch the app
make clean      # Remove .build and generated xcodeproj
```

## Important Files
- `project.yml`: XcodeGen project source of truth.
- `Makefile`: local build/run workflow.
- `JustCopy/App/AppDelegate.swift`: app lifecycle, capture orchestration.
- `JustCopy/Capture/`: overlay selection + screenshot capture.
- `JustCopy/OCR/OCRService.swift`: Vision text recognition.
- `JustCopy/Clipboard/ClipboardService.swift`: clipboard writes.
- `JustCopy/Permissions/PermissionService.swift`: screen recording permission flow.

## Architecture Notes
- Trigger capture from global hotkey (`Cmd+Shift+2`) or status menu.
- Overlay windows collect a drag rectangle.
- ScreenCaptureKit captures selected region.
- Vision recognizes text.
- Recognized text is copied to the system pasteboard.

## Agent Guidelines
- Do not manually edit `JustCopy.xcodeproj`; edit `project.yml` and run `make generate`.
- Validate with `make build` after code changes.
- There is no automated test suite yet; rely on build + manual capture flow checks.
- If capture behavior is changed, manually verify:
  - start capture
  - drag selection
  - OCR completes
  - text appears in clipboard

