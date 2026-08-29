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
            let hidden = await HideOthers.run(config, resolved)
            guard let summary = RunFailures.summary(outcomes) else { return .succeeded }
            guard let note = HideOthers.note(hidden) else { return .partial(summary) }
            return .partial(summary + "\n" + note)
        } catch {
            return .failed("\(error)")
        }
    }
}
