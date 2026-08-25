import AppKit
import RestageKit

enum AppAppearance: String, CaseIterable, Sendable {
    case system
    case light
    case dark

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    var titleKey: String {
        switch self {
        case .system: return "options.appearance.system"
        case .light: return "options.appearance.light"
        case .dark: return "options.appearance.dark"
        }
    }

    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
}

@MainActor
enum AppearanceSetting {
    static let defaultsKey = "preferredAppearance"

    static var current: AppAppearance {
        get {
            guard let raw = UserDefaults.standard.string(forKey: defaultsKey),
                  let appearance = AppAppearance(rawValue: raw)
            else { return .system }
            return appearance
        }
        set {
            if newValue == .system {
                UserDefaults.standard.removeObject(forKey: defaultsKey)
            } else {
                UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
            }
            apply()
        }
    }

    static func apply() {
        let appearance = current.nsAppearance
        NSApplication.shared.appearance = appearance
        for window in NSApplication.shared.windows {
            window.appearance = appearance
        }
    }
}
