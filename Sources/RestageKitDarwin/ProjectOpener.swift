import AppKit
import RestageKit

@MainActor
enum ProjectOpener {
    static func open(_ path: String, in app: AppID) async throws {
        let bundleID = try InstalledApps.bundleID(for: app)
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            throw EngineError.applicationNotFound(bundleID: bundleID)
        }
        let expanded = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else {
            throw EngineError.openPathMissing(path: path)
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        do {
            _ = try await NSWorkspace.shared.open(
                [URL(fileURLWithPath: expanded)], withApplicationAt: appURL,
                configuration: configuration)
        } catch {
            throw EngineError.openPathFailed(path: path, underlying: error.localizedDescription)
        }
    }
}
