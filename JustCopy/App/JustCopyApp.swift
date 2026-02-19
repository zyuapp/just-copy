import SwiftUI

@main
struct JustCopyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate)
                .frame(width: 480, height: 280)
        }
    }
}
