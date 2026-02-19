import Carbon

enum GlobalHotKeyError: LocalizedError {
    case registerFailed(OSStatus)
    case eventHandlerInstallFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .registerFailed(let status):
            return "Failed to register global hotkey (\(status))."
        case .eventHandlerInstallFailed(let status):
            return "Failed to install hotkey event handler (\(status))."
        }
    }
}

final class GlobalHotKeyMonitor {
    private let signature: OSType = 0x4A435059
    private let hotKeyID: UInt32 = 1

    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var callback: (() -> Void)?

    func register(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) throws {
        unregister()
        self.callback = callback

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let installStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            hotKeyEventHandler,
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )

        guard installStatus == noErr else {
            throw GlobalHotKeyError.eventHandlerInstallFailed(installStatus)
        }

        let identifier = EventHotKeyID(signature: signature, id: hotKeyID)
        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            identifier,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        guard registerStatus == noErr else {
            unregister()
            throw GlobalHotKeyError.registerFailed(registerStatus)
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }

        callback = nil
    }

    fileprivate func handleEvent(_ event: EventRef?) -> OSStatus {
        guard let event else { return noErr }

        var identifier = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &identifier
        )

        guard status == noErr else { return status }

        guard identifier.signature == signature, identifier.id == hotKeyID else {
            return noErr
        }

        callback?()
        return noErr
    }
}

private func hotKeyEventHandler(_ next: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData else { return noErr }
    let monitor = Unmanaged<GlobalHotKeyMonitor>.fromOpaque(userData).takeUnretainedValue()
    return monitor.handleEvent(event)
}
