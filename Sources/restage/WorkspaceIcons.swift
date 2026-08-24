import AppKit
import RestageKit
import RestageKitDarwin

/// config에 적힌 앱 이름으로 아이콘을 찾는다.
///
/// 목록에서 워크스페이스를 알아보는 가장 빠른 단서는 그 안에 무엇이 들었는지다. 이름은
/// 사용자가 지은 것이라 나중에 보면 기억이 안 나지만 아이콘은 바로 읽힌다.
@MainActor
enum WorkspaceIcons {
    enum Mark: Equatable {
        case icon(NSImage)
        /// 설치는 되어 있는데 아이콘을 읽지 못했다.
        case monogram(String)
        /// 그 이름의 앱이 없다. 눌러도 이 항목은 배치되지 않는다.
        case missing(String)
    }

    /// 성공한 것만 기억한다. 못 찾은 앱은 나중에 설치될 수 있어 매번 다시 본다.
    private static var icons: [AppID: NSImage] = [:]

    static func mark(for app: AppID) -> Mark {
        if let cached = icons[app] { return .icon(cached) }

        let letter = monogram(app)
        guard let bundleID = try? InstalledApps.bundleID(for: app) else { return .missing(letter) }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return .monogram(letter)
        }

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icons[app] = icon
        return .icon(icon)
    }

    /// 설치되지 않아 배치할 수 없는 앱. 카드에 사유를 적는 데 쓴다.
    static func missingApps(among apps: [AppID]) -> [AppID] {
        apps.filter {
            if case .missing = mark(for: $0) { return true }
            return false
        }
    }

    private static func monogram(_ app: AppID) -> String {
        String(app.rawValue.prefix(1)).uppercased()
    }
}
