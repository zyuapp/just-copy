import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published private(set) var hotKeyShortcut = HotKeyShortcut.defaultCapture

    private let appName = "JustCopy"
    private enum StatusIconState {
        case idle
        case scanning
        case copied

        var symbolName: String {
            switch self {
            case .idle:
                return "doc.on.clipboard"
            case .scanning:
                return "viewfinder"
            case .copied:
                return "checkmark.circle.fill"
            }
        }

        var tooltip: String {
            switch self {
            case .idle:
                return "JustCopy"
            case .scanning:
                return "Scanning text..."
            case .copied:
                return "Copied"
            }
        }
    }

    private let hotKeyMonitor = GlobalHotKeyMonitor()
    private let hotKeyPreferencesStore = HotKeyPreferencesStore()
    private let overlayController = SelectionOverlayController()
    private let permissionService = PermissionService()
    private let captureService = ScreenCaptureService()
    private let ocrService = OCRService()
    private let clipboardService = ClipboardService()

    private var captureTask: Task<Void, Never>?
    private lazy var replayKitAnchorWindow: NSWindow = {
        let window = NSWindow(
            contentRect: NSRect(x: -10_000, y: -10_000, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.alphaValue = 0
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.orderOut(nil)
        return window
    }()

    @objc dynamic var window: NSWindow? {
        replayKitAnchorWindow
    }

    private lazy var settingsWindowController = SettingsWindowController(appDelegate: self)
    private var statusItem: NSStatusItem?
    private var resetStatusWorkItem: DispatchWorkItem?
    private var isRecordingShortcut = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        restoreAndRegisterHotKey()
        _ = replayKitAnchorWindow
    }

    func applicationWillTerminate(_ notification: Notification) {
        captureTask?.cancel()
        hotKeyMonitor.unregister()
    }

    @objc private func captureTextAction(_ sender: Any?) {
        DispatchQueue.main.async { [weak self] in
            self?.beginCaptureFlow()
        }
    }

    @objc private func openSettingsAction(_ sender: Any?) {
        settingsWindowController.show()
    }

    @objc private func quitAction(_ sender: Any?) {
        NSApplication.shared.terminate(nil)
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.title = ""
        item.button?.imagePosition = .imageOnly

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
        setStatusIcon(.idle)
    }

    func applyHotKeyShortcut(_ shortcut: HotKeyShortcut) {
        guard shortcut != hotKeyShortcut else { return }
        let previousShortcut = hotKeyShortcut

        do {
            try registerGlobalHotKey(shortcut: shortcut)
            hotKeyShortcut = shortcut
            hotKeyPreferencesStore.save(shortcut: shortcut)
        } catch let registrationError {
            do {
                try registerGlobalHotKey(shortcut: previousShortcut)
            } catch let restoreError {
                presentError(
                    title: "Hotkey setup failed",
                    message: "\(registrationError.localizedDescription)\n\(restoreError.localizedDescription)"
                )
                return
            }

            presentError(
                title: "Could not update shortcut",
                message: "\(registrationError.localizedDescription)\nThe previous shortcut (\(previousShortcut.displayString)) is still active."
            )
        }
    }

    func setShortcutRecording(_ isRecording: Bool) {
        guard isRecording != isRecordingShortcut else { return }
        isRecordingShortcut = isRecording

        if isRecording {
            hotKeyMonitor.unregister()
            return
        }

        do {
            try registerGlobalHotKey(shortcut: hotKeyShortcut)
        } catch {
            presentError(
                title: "Hotkey setup failed",
                message: "\(error.localizedDescription)\nReopen Settings to choose a new shortcut."
            )
        }
    }

    private func restoreAndRegisterHotKey() {
        let preferredShortcut = hotKeyPreferencesStore.loadShortcut()

        do {
            try registerGlobalHotKey(shortcut: preferredShortcut)
            hotKeyShortcut = preferredShortcut
        } catch let registrationError {
            if preferredShortcut != .defaultCapture {
                do {
                    try registerGlobalHotKey(shortcut: .defaultCapture)
                    hotKeyShortcut = .defaultCapture
                    hotKeyPreferencesStore.save(shortcut: .defaultCapture)
                    presentError(
                        title: "Hotkey reset to default",
                        message: "\(registrationError.localizedDescription)\nJustCopy restored the default shortcut (\(HotKeyShortcut.defaultCapture.displayString))."
                    )
                    return
                } catch { }
            }

            presentError(title: "Hotkey setup failed", message: registrationError.localizedDescription)
        }
    }

    private func registerGlobalHotKey(shortcut: HotKeyShortcut) throws {
        try hotKeyMonitor.register(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers) { [weak self] in
            DispatchQueue.main.async {
                self?.beginCaptureFlow()
            }
        }
    }

    private func beginCaptureFlow() {
        guard !isRecordingShortcut else { return }

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
        flashStatus(.scanning)

        captureTask?.cancel()
        captureTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            do {
                try await Task.sleep(nanoseconds: 40_000_000)
                let image = try await self.captureService.capture(rect: rect)
                try Task.checkCancellation()
                let text = try self.ocrService.recognizeText(in: image)
                try Task.checkCancellation()
                try await self.clipboardService.copy(text)

                await MainActor.run {
                    self.flashStatus(.copied)
                }
            } catch {
                if error is CancellationError {
                    return
                }
                await MainActor.run {
                    self.flashStatus(.idle)
                    self.presentError(title: "Could not copy text", message: error.localizedDescription)
                }
            }
        }
    }

    private func flashStatus(_ state: StatusIconState) {
        setStatusIcon(state)

        resetStatusWorkItem?.cancel()
        guard state != .idle else { return }

        let workItem = DispatchWorkItem { [weak self] in
            self?.setStatusIcon(.idle)
        }

        resetStatusWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: workItem)
    }

    private func setStatusIcon(_ state: StatusIconState) {
        guard let button = statusItem?.button else { return }
        button.title = ""
        button.toolTip = state.tooltip

        guard let image = NSImage(systemSymbolName: state.symbolName, accessibilityDescription: state.tooltip) else {
            return
        }

        image.isTemplate = true
        image.size = NSSize(width: 15, height: 15)
        button.image = image
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
