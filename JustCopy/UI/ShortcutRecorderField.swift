import AppKit
import Carbon
import SwiftUI

struct ShortcutRecorderField: View {
    let shortcut: HotKeyShortcut
    let onShortcutRecorded: (HotKeyShortcut) -> Void
    let onRecordingStateChanged: (Bool) -> Void

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
        recorder.beginRecording(
            onRecordingStateChanged: onRecordingStateChanged
        ) { recordedShortcut in
            onShortcutRecorded(recordedShortcut)
        }
    }
}

private final class ShortcutRecorderController: ObservableObject {
    @Published private(set) var isRecording = false

    private var keyEventMonitor: Any?
    private var onRecordingStateChanged: ((Bool) -> Void)?
    private var onShortcutRecorded: ((HotKeyShortcut) -> Void)?

    deinit {
        stopRecording()
    }

    func beginRecording(
        onRecordingStateChanged: @escaping (Bool) -> Void,
        onShortcutRecorded: @escaping (HotKeyShortcut) -> Void
    ) {
        guard !isRecording else { return }

        self.onRecordingStateChanged = onRecordingStateChanged
        self.onShortcutRecorded = onShortcutRecorded
        isRecording = true
        self.onRecordingStateChanged?(true)

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

            let callback = self.onShortcutRecorded
            self.stopRecording()
            callback?(shortcut)
            return nil
        }
    }

    func stopRecording() {
        let wasRecording = isRecording

        if let keyEventMonitor {
            NSEvent.removeMonitor(keyEventMonitor)
            self.keyEventMonitor = nil
        }

        if wasRecording {
            onRecordingStateChanged?(false)
        }
        onRecordingStateChanged = nil
        onShortcutRecorded = nil
        isRecording = false
    }
}
