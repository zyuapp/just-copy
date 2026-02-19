import AppKit
import Carbon
import SwiftUI

struct ShortcutRecorderField: View {
    let shortcut: HotKeyShortcut
    let onShortcutRecorded: (HotKeyShortcut) -> Void

    @StateObject private var recorder = ShortcutRecorderController()

    var body: some View {
        Button(action: beginRecording) {
            Text(recorder.isRecording ? "Type new shortcut (Esc to cancel)" : shortcut.displayString)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .onDisappear {
            recorder.stopRecording()
        }
    }

    private func beginRecording() {
        recorder.beginRecording { recordedShortcut in
            onShortcutRecorded(recordedShortcut)
        }
    }
}

private final class ShortcutRecorderController: ObservableObject {
    @Published private(set) var isRecording = false

    private var keyEventMonitor: Any?
    private var onShortcutRecorded: ((HotKeyShortcut) -> Void)?

    deinit {
        stopRecording()
    }

    func beginRecording(onShortcutRecorded: @escaping (HotKeyShortcut) -> Void) {
        guard !isRecording else { return }

        self.onShortcutRecorded = onShortcutRecorded
        isRecording = true

        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard self.isRecording else { return event }

            if event.keyCode == UInt16(kVK_Escape) {
                self.stopRecording()
                return nil
            }

            guard let shortcut = HotKeyShortcut(event: event) else {
                NSSound.beep()
                return nil
            }

            self.onShortcutRecorded?(shortcut)
            self.stopRecording()
            return nil
        }
    }

    func stopRecording() {
        if let keyEventMonitor {
            NSEvent.removeMonitor(keyEventMonitor)
            self.keyEventMonitor = nil
        }

        onShortcutRecorded = nil
        isRecording = false
    }
}
