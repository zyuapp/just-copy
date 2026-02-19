import AppKit
import Carbon

final class SelectionOverlayController {
    private var windows: [SelectionWindow] = []
    private var keyEventMonitor: Any?
    private var completion: ((CGRect?) -> Void)?
    private var cursorPushed = false
    private var isActive = false

    func presentSelection(completion: @escaping (CGRect?) -> Void) {
        guard !isActive else { return }

        isActive = true
        self.completion = completion

        NSApplication.shared.activate(ignoringOtherApps: true)
        NSCursor.crosshair.push()
        cursorPushed = true

        installEscapeMonitor()
        presentOverlayWindows()
    }

    private func installEscapeMonitor() {
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            if event.keyCode == UInt16(kVK_Escape) {
                self.finish(with: nil)
                return nil
            }

            return event
        }
    }

    private func presentOverlayWindows() {
        for screen in NSScreen.screens {
            let window = SelectionWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )

            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.ignoresMouseEvents = false

            let selectionView = SelectionView(frame: CGRect(origin: .zero, size: screen.frame.size))
            selectionView.autoresizingMask = [.width, .height]
            selectionView.onSelectionFinished = { [weak self] rect in
                self?.finish(with: rect)
            }

            window.contentView = selectionView
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }
    }

    private func finish(with rect: CGRect?) {
        guard isActive else { return }
        isActive = false

        if let keyEventMonitor {
            NSEvent.removeMonitor(keyEventMonitor)
            self.keyEventMonitor = nil
        }

        windows.forEach {
            $0.orderOut(nil)
            $0.close()
        }
        windows.removeAll()

        if cursorPushed {
            NSCursor.pop()
            cursorPushed = false
        }

        let callback = completion
        completion = nil
        callback?(rect)
    }
}

final class SelectionWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
