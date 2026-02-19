import AppKit
import Carbon

final class SelectionOverlayController {
    private var windowsByDisplayID: [CGDirectDisplayID: SelectionWindow] = [:]
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
        let availableDisplayIDs = Set(NSScreen.screens.compactMap(\.displayID))
        let staleDisplayIDs = windowsByDisplayID.keys.filter { !availableDisplayIDs.contains($0) }

        for staleDisplayID in staleDisplayIDs {
            windowsByDisplayID[staleDisplayID]?.orderOut(nil)
            windowsByDisplayID.removeValue(forKey: staleDisplayID)
        }

        for screen in NSScreen.screens {
            guard let displayID = screen.displayID else { continue }

            let window = windowsByDisplayID[displayID] ?? makeSelectionWindow(for: screen)
            windowsByDisplayID[displayID] = window
            window.setFrame(screen.frame, display: true)

            let selectionView = SelectionView(frame: CGRect(origin: .zero, size: screen.frame.size))
            selectionView.autoresizingMask = [.width, .height]
            selectionView.onSelectionFinished = { [weak self] rect in
                self?.finish(with: rect)
            }

            window.contentView = selectionView
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func finish(with rect: CGRect?) {
        guard isActive else { return }
        isActive = false

        if let keyEventMonitor {
            NSEvent.removeMonitor(keyEventMonitor)
            self.keyEventMonitor = nil
        }

        let callback = completion
        completion = nil

        windowsByDisplayID.values.forEach {
            $0.orderOut(nil)
            $0.contentView = nil
        }

        if cursorPushed {
            NSCursor.pop()
            cursorPushed = false
        }

        callback?(rect)
    }

    private func makeSelectionWindow(for screen: NSScreen) -> SelectionWindow {
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
        window.animationBehavior = .none
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.ignoresMouseEvents = false
        return window
    }
}

final class SelectionWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        guard let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }

        return CGDirectDisplayID(screenNumber.uint32Value)
    }
}
