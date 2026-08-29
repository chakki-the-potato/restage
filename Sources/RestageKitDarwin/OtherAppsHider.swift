import AppKit
import RestageKit

public enum OtherAppsHider {
    public struct RunningApp: Sendable, Equatable {
        public let bundleID: String
        public let isRegular: Bool
        public let isHidden: Bool
        public let pid: Int32

        public init(bundleID: String, isRegular: Bool, isHidden: Bool, pid: Int32) {
            self.bundleID = bundleID
            self.isRegular = isRegular
            self.isHidden = isHidden
            self.pid = pid
        }
    }

    private static let finderBundleID = "com.apple.finder"

    private static let settleTimeout: Duration = .seconds(2)

    @MainActor
    public static func hide(keeping declared: [AppID]) async -> [String] {
        let keeping = Set(declared.compactMap { try? InstalledApps.bundleID(for: $0) })
        let running = NSWorkspace.shared.runningApplications
        let wanted = Set(targets(
            running: running.map {
                RunningApp(
                    bundleID: $0.bundleIdentifier ?? "",
                    isRegular: $0.activationPolicy == .regular,
                    isHidden: $0.isHidden,
                    pid: $0.processIdentifier)
            },
            keeping: keeping,
            selfPID: ProcessInfo.processInfo.processIdentifier))

        let asked = running.filter { wanted.contains($0.bundleIdentifier ?? "") }
        guard !asked.isEmpty else { return [] }

        for app in asked { app.hide() }
        await settle(asked)
        return names(ofHiddenAmong: asked)
    }

    public static func targets(
        running: [RunningApp], keeping: Set<String>, selfPID: Int32
    ) -> [String] {
        running
            .filter { $0.isRegular && !$0.isHidden }
            .filter { $0.pid != selfPID }
            .filter { $0.bundleID != finderBundleID }
            .filter { !$0.bundleID.isEmpty && !keeping.contains($0.bundleID) }
            .map(\.bundleID)
    }

    @MainActor
    private static func settle(_ asked: [NSRunningApplication]) async {
        var previous: [String] = []
        _ = await Polling.poll(timeout: settleTimeout) { () -> Bool? in
            let current = names(ofHiddenAmong: asked)
            defer { previous = current }
            return !current.isEmpty && current == previous ? true : nil
        }
    }

    @MainActor
    private static func names(ofHiddenAmong apps: [NSRunningApplication]) -> [String] {
        apps.filter(\.isHidden).compactMap { $0.localizedName ?? $0.bundleIdentifier }.sorted()
    }
}
