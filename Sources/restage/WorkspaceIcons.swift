import AppKit
import RestageKit
import RestageKitDarwin

@MainActor
enum WorkspaceIcons {
    enum Mark: Equatable {
        case icon(NSImage)
        case monogram(String)
        case missing(String)
    }

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
