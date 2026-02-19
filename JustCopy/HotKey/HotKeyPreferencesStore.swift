import Foundation

final class HotKeyPreferencesStore {
    private enum Keys {
        static let keyCode = "hotkey.keyCode"
        static let modifiers = "hotkey.modifiers"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadShortcut() -> HotKeyShortcut {
        guard defaults.object(forKey: Keys.keyCode) != nil,
              defaults.object(forKey: Keys.modifiers) != nil else {
            return .defaultCapture
        }

        let keyCode = UInt32(defaults.integer(forKey: Keys.keyCode))
        let modifiers = UInt32(defaults.integer(forKey: Keys.modifiers))
        return HotKeyShortcut(keyCode: keyCode, modifiers: modifiers) ?? .defaultCapture
    }

    func save(shortcut: HotKeyShortcut) {
        defaults.set(Int(shortcut.keyCode), forKey: Keys.keyCode)
        defaults.set(Int(shortcut.modifiers), forKey: Keys.modifiers)
    }
}
