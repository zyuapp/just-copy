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

            ShortcutRecorderField(shortcut: appDelegate.hotKeyShortcut) { shortcut in
                appDelegate.applyHotKeyShortcut(shortcut)
            }

            Text("Click the field, then press a shortcut with at least one modifier key. Press Escape to cancel recording.")
                .foregroundStyle(.secondary)

            Divider()

            Text("Last copied snippet")
                .font(.headline)

            ScrollView {
                Text(appDelegate.lastCopiedPreview)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(10)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
