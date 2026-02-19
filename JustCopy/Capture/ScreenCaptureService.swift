import AppKit
import ScreenCaptureKit

enum ScreenCaptureServiceError: LocalizedError {
    case invalidSelection
    case displayNotFound
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .invalidSelection:
            return "Please select a larger area."
        case .displayNotFound:
            return "Could not find a display for the selected area."
        case .captureFailed:
            return "Screen capture failed."
        }
    }
}

final class ScreenCaptureService {
    func capture(rect selection: CGRect) async throws -> CGImage {
        guard selection.width > 0, selection.height > 0 else {
            throw ScreenCaptureServiceError.invalidSelection
        }

        guard let displayContext = makeDisplayContext(for: selection) else {
            throw ScreenCaptureServiceError.displayNotFound
        }

        let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = shareableContent.displays.first(where: { $0.displayID == displayContext.displayID }) else {
            throw ScreenCaptureServiceError.displayNotFound
        }

        let sourceRect = convertSelectionToDisplayPoints(selection, context: displayContext)
        guard sourceRect.width > 0, sourceRect.height > 0 else {
            throw ScreenCaptureServiceError.invalidSelection
        }

        let configuration = SCStreamConfiguration()
        configuration.sourceRect = sourceRect
        configuration.width = max(1, Int(round(sourceRect.width * displayContext.scale)))
        configuration.height = max(1, Int(round(sourceRect.height * displayContext.scale)))
        configuration.showsCursor = false
        configuration.capturesAudio = false

        let filter = SCContentFilter(display: display, excludingWindows: [])

        do {
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        } catch {
            throw ScreenCaptureServiceError.captureFailed
        }
    }

    private func makeDisplayContext(for selection: CGRect) -> DisplayContext? {
        let bestScreen = NSScreen.screens
            .map { ($0, $0.frame.intersection(selection).area) }
            .max { lhs, rhs in lhs.1 < rhs.1 }

        guard
            let (screen, overlap) = bestScreen,
            overlap > 0,
            let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else {
            return nil
        }

        return DisplayContext(
            displayID: CGDirectDisplayID(screenNumber.uint32Value),
            frame: screen.frame,
            scale: screen.backingScaleFactor
        )
    }

    private func convertSelectionToDisplayPoints(_ selection: CGRect, context: DisplayContext) -> CGRect {
        let localSelection = CGRect(
            x: selection.minX - context.frame.minX,
            y: selection.minY - context.frame.minY,
            width: selection.width,
            height: selection.height
        )

        let sourceRect = CGRect(
            x: localSelection.minX,
            y: context.frame.height - localSelection.maxY,
            width: localSelection.width,
            height: localSelection.height
        )

        let displayBounds = CGRect(
            x: 0,
            y: 0,
            width: context.frame.width,
            height: context.frame.height
        )

        return sourceRect.intersection(displayBounds)
    }
}

private struct DisplayContext {
    let displayID: CGDirectDisplayID
    let frame: CGRect
    let scale: CGFloat
}

private extension CGRect {
    var area: CGFloat {
        width * height
    }
}
