import RestageKit
import RestageKitDarwin

/// 워크스페이스 하나를 실행한다.
///
/// 메뉴바 패널과 전역 단축키가 같은 경로를 타야 하므로 화면과 분리한다.
/// 실패를 던지지 않고 값으로 돌려주는 이유는 어느 쪽에서 불러도 사용자에게 보여줄 문장이
/// 필요하기 때문이다.
@MainActor
enum WorkspaceLauncher {
    enum Outcome {
        case succeeded
        /// 일부 항목이 실패했다. 나머지는 배치됐다.
        case partial(String)
        /// 실행 자체가 시작되지 못했다.
        case failed(String)

        var message: String? {
            switch self {
            case .succeeded: return nil
            case .partial(let text), .failed(let text): return text
            }
        }
    }

    static func run(_ name: String) async -> Outcome {
        guard AccessibilityPermission.isTrusted() else {
            return .failed(AccessibilityPermission.onboardingMessage)
        }
        guard !ScreenLock.isLocked() else {
            return .failed(ScreenLock.message)
        }
        guard let displays = DisplayCatalog.current() else {
            return .failed("디스플레이 정보를 조회할 수 없습니다")
        }

        do {
            let path = try WorkspaceRegistry().resolve(name)
            let config = try ConfigLoader.load(path: path)
            let resolved = WorkspaceResolver.resolve(config, displays: displays)
            let outcomes = await WorkspaceRunner().run(resolved)
            guard let summary = MenuContent.failureSummary(outcomes) else { return .succeeded }
            return .partial(summary)
        } catch {
            return .failed("\(error)")
        }
    }
}
