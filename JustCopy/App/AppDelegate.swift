import AppKit
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published private(set) var lastCopiedPreview = "No text copied yet."

    private let appName = "JustCopy"
    private let hotKeyMonitor = GlobalHotKeyMonitor()
    private let overlayController = SelectionOverlayController()
    private let permissionService = PermissionService()
    private let captureService = ScreenCaptureService()
    private let ocrService = OCRService()
    private let clipboardService = ClipboardService()

    private var statusItem: NSStatusItem?
    private var resetStatusWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        registerHotKey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyMonitor.unregister()
    }

    @objc private func captureTextAction(_ sender: Any?) {
        beginCaptureFlow()
    }

    @objc private func openSettingsAction(_ sender: Any?) {
        let opened = NSApplication.shared.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        if !opened {
            _ = NSApplication.shared.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc private func quitAction(_ sender: Any?) {
        NSApplication.shared.terminate(nil)
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = appName

        let menu = NSMenu()

        let capture = NSMenuItem(title: "Capture Text", action: #selector(captureTextAction(_:)), keyEquivalent: "2")
        capture.keyEquivalentModifierMask = [.command, .shift]
        capture.target = self
        menu.addItem(capture)

        let settings = NSMenuItem(title: "Settings...", action: #selector(openSettingsAction(_:)), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit \(appName)", action: #selector(quitAction(_:)), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
    }

    private func registerHotKey() {
        let modifiers = UInt32(cmdKey) | UInt32(shiftKey)

        do {
            try hotKeyMonitor.register(keyCode: UInt32(kVK_ANSI_2), modifiers: modifiers) { [weak self] in
                DispatchQueue.main.async {
                    self?.beginCaptureFlow()
                }
            }
        } catch {
            presentError(title: "Hotkey setup failed", message: error.localizedDescription)
        }
    }

    private func beginCaptureFlow() {
        guard permissionService.requestScreenRecordingPermission() else {
            presentPermissionAlert()
            return
        }

        overlayController.presentSelection { [weak self] (selectedRect: CGRect?) in
            guard let self, let selectedRect else { return }
            self.processCapture(rect: selectedRect)
        }
    }

    private func processCapture(rect: CGRect) {
        flashStatus("Scanning...")

        Task { [weak self] in
            guard let self else { return }

            do {
                let image = try await self.captureService.capture(rect: rect)
                let text = try self.ocrService.recognizeText(in: image)
                try self.clipboardService.copy(text)

                await MainActor.run {
                    self.lastCopiedPreview = text.preview(maxLength: 180)
                    self.flashStatus("Copied")
                }
            } catch {
                await MainActor.run {
                    self.flashStatus(self.appName)
                    self.presentError(title: "Could not copy text", message: error.localizedDescription)
                }
            }
        }
    }

    private func flashStatus(_ text: String) {
        statusItem?.button?.title = text

        resetStatusWorkItem?.cancel()
        guard text != appName else { return }

        let workItem = DispatchWorkItem { [weak self] in
            self?.statusItem?.button?.title = self?.appName ?? "JustCopy"
        }

        resetStatusWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: workItem)
    }

    private func presentPermissionAlert() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Screen Recording permission required"
        alert.informativeText = "JustCopy needs Screen Recording access to capture the selected area. You can enable it in System Settings."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            permissionService.openScreenRecordingSettings()
        }
    }

    private func presentError(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

private extension String {
    func preview(maxLength: Int) -> String {
        if count <= maxLength {
            return self
        }

        let index = self.index(startIndex, offsetBy: maxLength)
        return String(self[..<index]) + "..."
    }
}
