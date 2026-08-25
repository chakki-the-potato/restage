import AppKit
import RestageKit

/// 앱의 밝기.
///
/// 시스템을 따르는 것이 기본이다. 그래도 고정하는 길을 두는 이유는, 밝은 화면에서 일하다
/// 이것만 어둡게 두고 싶은 경우가 있기 때문이다.
enum AppAppearance: String, CaseIterable, Sendable {
    case system
    case light
    case dark

    /// nil이면 시스템이 정한 것을 그대로 쓴다.
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

/// 고른 밝기를 기억하고 앱 전체에 건다.
///
/// 창마다 거는 것이 아니라 `NSApp`에 한 번 건다. 창은 자기 값을 따로 정하지 않는 한
/// 앱의 값을 물려받으므로, 패널이든 알림 창이든 같은 밝기로 뜬다.
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

    /// 앱이 뜰 때 한 번, 그리고 바꿀 때마다 부른다.
    ///
    /// `NSApp`에만 걸면 그 뒤에 만드는 창만 따라온다. 이미 떠 있는 창은 자기가 물려받은
    /// 값을 그대로 들고 있어서, 패널을 띄워 둔 채 밝기를 바꾸면 패널만 그대로다.
    /// 그래서 지금 있는 창에도 같은 값을 직접 건다. nil을 걸면 다시 물려받는다.
    static func apply() {
        let appearance = current.nsAppearance
        NSApplication.shared.appearance = appearance
        for window in NSApplication.shared.windows {
            window.appearance = appearance
        }
    }
}
