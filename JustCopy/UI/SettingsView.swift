import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appDelegate: AppDelegate

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("JustCopy")
                .font(.system(size: 24, weight: .semibold))

            Text("Press Command-Shift-2 to start selection. Drag around text, release the mouse, and recognized text is copied to your clipboard.")
                .foregroundStyle(.secondary)

            Divider()

            Text("Global shortcut")
                .font(.headline)

            ShortcutRecorderField(
                shortcut: appDelegate.hotKeyShortcut,
                onShortcutRecorded: { shortcut in
                    appDelegate.applyHotKeyShortcut(shortcut)
                },
                onRecordingStateChanged: { isRecording in
                    appDelegate.setShortcutRecording(isRecording)
                }
            )

            Text("Click the field, then press a shortcut with at least one modifier key. Press Escape to cancel recording.")
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
