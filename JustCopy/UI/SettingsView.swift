import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appDelegate: AppDelegate

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Press your global shortcut, drag an area on screen, and the recognized text is copied to the clipboard.")
                .font(.callout)
                .foregroundStyle(.secondary)

            // MARK: - General Section
            SettingsSection(icon: "gear", title: "General") {
                Toggle("Start at Launch", isOn: Binding(
                    get: { SMAppService.mainApp.status == .enabled },
                    set: { newValue in
                        try? newValue
                            ? SMAppService.mainApp.register()
                            : SMAppService.mainApp.unregister()
                    }
                ))
            }

            // MARK: - Shortcut Section
            SettingsSection(icon: "keyboard", title: "Shortcut") {
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
            }

            // MARK: - How to Use Section
            SettingsSection(icon: "questionmark.circle", title: "How to Use") {
                VStack(alignment: .leading, spacing: 12) {
                    NumberedStep(number: 1, text: "Press your shortcut to start the area selection.")
                    NumberedStep(number: 2, text: "Drag a box around text and release the mouse.")
                    NumberedStep(number: 3, text: "Recognized text is copied automatically.")
                }
            }

            Spacer(minLength: 0)

            // MARK: - Version Footer
            HStack {
                Spacer()
                Text("JustCopy v1.0.1")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Section Container

private struct SettingsSection<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.primary)

            content
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Numbered Step

private struct NumberedStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "\(number).circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.accentColor)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }
}
