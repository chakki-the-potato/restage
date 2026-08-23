import Foundation
import RestageKit
import RestageKitDarwin

@MainActor
enum OpenCommand {
    static func run(path: String) async -> Int32 {
        guard AccessibilityPermission.isTrusted() else {
            print(AccessibilityPermission.onboardingMessage)
            return 1
        }
        guard !ScreenLock.isLocked() else {
            print(ScreenLock.message)
            return 1
        }
        guard let displays = DisplayCatalog.current() else {
            print("디스플레이 정보를 조회할 수 없습니다")
            return 1
        }

        let config: WorkspaceConfig
        do {
            config = try ConfigLoader.load(path: path)
        } catch {
            print(error)
            return 2
        }

        let resolved = WorkspaceResolver.resolve(config, displays: displays)
        let outcomes = await WorkspaceRunner().run(resolved)

        print(RunReport.render(workspace: resolved.workspace, outcomes: outcomes))
        return RunReport.hasFailure(outcomes) ? 1 : 0
    }
}
