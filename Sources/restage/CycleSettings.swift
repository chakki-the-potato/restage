import RestageKit

enum CycleSettings {
    static let hotkeyKey = "cycleHotkey"
    static let lastOpenedKey = "lastOpenedWorkspace"

    static var hotkey: String? {
        get { AppDefaults.shared.string(forKey: hotkeyKey) }
        set { write(newValue, forKey: hotkeyKey) }
    }

    static var spec: HotkeySpec? {
        guard let hotkey else { return nil }
        return try? HotkeySpec.parse(hotkey)
    }

    static var lastOpened: String? {
        get { AppDefaults.shared.string(forKey: lastOpenedKey) }
        set { write(newValue, forKey: lastOpenedKey) }
    }

    private static func write(_ value: String?, forKey key: String) {
        guard let value else {
            AppDefaults.shared.removeObject(forKey: key)
            return
        }
        AppDefaults.shared.set(value, forKey: key)
    }
}
