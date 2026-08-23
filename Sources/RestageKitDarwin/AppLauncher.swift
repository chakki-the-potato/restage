import AppKit
import RestageKit

// probe(실행 타겟)에서 콜드 스타트를 위해 terminate를 호출하므로 public이다.
@MainActor
public enum AppLauncher {
    /// 이미 실행 중이면 그 프로세스를 반환하고, 아니면 새로 실행한다.
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

    /// 같은 bundle ID로 여러 프로세스가 뜰 수 있다(자동화 도구가 띄운 인스턴스 등).
    /// pid 오름차순으로 반환해 선택이 결정론적이게 한다.
    public static func runningApplications(bundleID: String) -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.bundleIdentifier == bundleID && !$0.isTerminated }
            .sorted { $0.processIdentifier < $1.processIdentifier }
    }

    /// 가장 낮은 pid를 고른다. 나중에 뜬 인스턴스는 pid가 높으므로 사용자의 주 인스턴스가 선택된다.
    public static func runningApplication(bundleID: String) -> NSRunningApplication? {
        runningApplications(bundleID: bundleID).first
    }

    public static func isRunning(bundleID: String) -> Bool {
        !runningApplications(bundleID: bundleID).isEmpty
    }

    /// probe의 콜드 스타트 전용. 해당 bundle ID의 모든 인스턴스를 종료하고 사라질 때까지 기다린다.
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
