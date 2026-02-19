import AppKit

enum ClipboardServiceError: LocalizedError {
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .writeFailed:
            return "Could not write text to the clipboard."
        }
    }
}

final class ClipboardService {
    @MainActor
    func copy(_ text: String) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        guard pasteboard.setString(text, forType: .string) else {
            throw ClipboardServiceError.writeFailed
        }
    }
}
