import AppKit
import RestageKit

@MainActor
public enum AppLauncher {
    public static func launch(bundleID: String) async throws -> ProcessHandle {
        if let running = runningApplication(bundleID: bundleID) {
            return ProcessHandle(pid: running.processIdentifier, wasLaunched: false)
        }

        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            throw EngineError.applicationNotFound(bundleID: bundleID)
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false

        do {
            let app = try await NSWorkspace.shared.openApplication(
                at: url, configuration: configuration)
            return ProcessHandle(pid: app.processIdentifier, wasLaunched: true)
        } catch {
            throw EngineError.launchFailed(
                bundleID: bundleID, underlying: error.localizedDescription)
        }
    }

    public static func runningApplications(bundleID: String) -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.bundleIdentifier == bundleID && !$0.isTerminated }
            .sorted { $0.processIdentifier < $1.processIdentifier }
    }

    public static func runningApplication(bundleID: String) -> NSRunningApplication? {
        runningApplications(bundleID: bundleID).first
    }

    public static func isRunning(bundleID: String) -> Bool {
        !runningApplications(bundleID: bundleID).isEmpty
    }

    public static func terminate(bundleID: String, timeout: Duration) async -> Bool {
        let running = runningApplications(bundleID: bundleID)
        guard !running.isEmpty else { return true }
        running.forEach { $0.terminate() }

        let gone = await Polling.poll(interval: .milliseconds(100), timeout: timeout) {
            isRunning(bundleID: bundleID) ? nil : true
        }
        if gone == true { return true }

        runningApplications(bundleID: bundleID).forEach { $0.forceTerminate() }
        let forced = await Polling.poll(interval: .milliseconds(100), timeout: .seconds(3)) {
            isRunning(bundleID: bundleID) ? nil : true
        }
        return forced == true
    }
}
