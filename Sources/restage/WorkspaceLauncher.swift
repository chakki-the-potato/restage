import RestageKit
import RestageKitDarwin

@MainActor
enum WorkspaceLauncher {
    enum Outcome {
        case succeeded
        case partial(String)
        case failed(String)

        var message: String? {
            switch self {
            case .succeeded: return nil
            case .partial(let text), .failed(let text): return text
            }
        }
    }

    static func run(
        _ name: String, onProgress: ((RunProgress) -> Void)? = nil
    ) async -> Outcome {
        guard AccessibilityPermission.isTrusted() else {
            return .failed(AccessibilityPermission.onboardingMessage)
        }
        guard !ScreenLock.isLocked() else {
            return .failed(ScreenLock.message)
        }
        guard let displays = DisplayCatalog.current() else {
            return .failed(L10n.string("error.display.unavailable"))
        }

        do {
            let path = try WorkspaceRegistry().resolve(name)
            let config = try ConfigLoader.load(path: path)
            let resolved = WorkspaceResolver.resolve(config, displays: displays)
            let outcomes = await WorkspaceRunner().run(resolved, onProgress: onProgress)
            guard let summary = RunFailures.summary(outcomes) else { return .succeeded }
            return .partial(summary)
        } catch {
            return .failed("\(error)")
        }
    }
}
