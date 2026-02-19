import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appDelegate: AppDelegate

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.system(size: 22, weight: .semibold))

            Text("Press your global shortcut, drag an area on screen, and the recognized text is copied to the clipboard.")
                .font(.callout)
                .foregroundStyle(.secondary)

            GroupBox("Global shortcut") {
                VStack(alignment: .leading, spacing: 10) {
                    ShortcutRecorderField(
                        shortcut: appDelegate.hotKeyShortcut,
                        onShortcutRecorded: { shortcut in
                            appDelegate.applyHotKeyShortcut(shortcut)
                        },
                        onRecordingStateChanged: { isRecording in
                            appDelegate.setShortcutRecording(isRecording)
                        }
                    )
                    Text("Click the field and press a shortcut with at least one modifier key. Press Escape to cancel.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }

            GroupBox("How to use") {
                VStack(alignment: .leading, spacing: 8) {
                    InstructionRow(text: "Press your shortcut to start the area selection.")
                    InstructionRow(text: "Drag a box around text and release the mouse.")
                    InstructionRow(text: "Recognized text is copied automatically.")
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct InstructionRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.system(size: 5))
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.callout)
            Spacer(minLength: 0)
        }
    }
}
