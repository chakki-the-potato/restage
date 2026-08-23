import AppKit
import RestageKit

@MainActor
public struct WorkspaceRunner {
    public static let windowTimeout: Duration = .seconds(15)

    private let engine: AXWindowEngine

    public init(engine: AXWindowEngine = AXWindowEngine()) {
        self.engine = engine
    }

    public func run(_ resolved: ResolvedWorkspace) async -> [ItemOutcome] {
        var outcomes: [ItemOutcome] = []

        for screen in resolved.screens {
            outcomes.append(contentsOf: await runScreen(screen))
        }

        for skipped in resolved.skipped {
            outcomes.append(ItemOutcome(
                screenID: skipped.id, app: nil, status: .skipped, detail: skipped.reason))
        }

        focusFirstAnchor(resolved)
        return outcomes
    }

    private func runScreen(_ screen: ScreenPlan) async -> [ItemOutcome] {
        var handles: [AppID: ProcessHandle] = [:]
        var launchFailures: [AppID: String] = [:]
        var outcomes: [ItemOutcome] = []

        // 실행은 먼저 전부 시도해 여러 앱의 기동 시간이 겹치게 하고,
        // 보고는 선언 순서대로 낸다.
        for placement in screen.placements {
            do {
                handles[placement.app] = try await engine.launch(placement.app)
            } catch {
                launchFailures[placement.app] = String(describing: error)
            }
        }

        for placement in screen.placements {
            if let reason = launchFailures[placement.app] {
                outcomes.append(ItemOutcome(
                    screenID: screen.id, app: placement.app, status: .failed,
                    expected: placement.target, detail: reason))
                continue
            }
            guard let handle = handles[placement.app] else { continue }
            outcomes.append(await apply(placement, handle: handle, screen: screen))
        }

        for item in screen.unsupported {
            outcomes.append(ItemOutcome(
                screenID: screen.id, app: item.app, status: .skipped, detail: item.reason))
        }

        if let anchor = screen.anchor, let handle = handles[anchor] {
            AXWindow.setApplicationFrontmost(pid: handle.pid)
        }

        return outcomes
    }

    private func apply(
        _ placement: Placement, handle: ProcessHandle, screen: ScreenPlan
    ) async -> ItemOutcome {
        if isSatisfied(placement, handle: handle, screen: screen) {
            return ItemOutcome(
                screenID: screen.id, app: placement.app, status: .alreadySatisfied,
                expected: placement.target, detail: "이미 목표 상태")
        }

        let window: WindowHandle
        do {
            window = try await engine.waitForWindow(handle, timeout: Self.windowTimeout)
        } catch {
            let status: OutcomeStatus = CurrentState.windowCount(pid: handle.pid) > 0
                ? .unreachable : .failed
            return ItemOutcome(
                screenID: screen.id, app: placement.app, status: status,
                expected: placement.target, detail: String(describing: error))
        }

        let result = await engine.place(window, slot: placement.slot, display: screen.display)
        guard screen.mode == .fullscreen, result.isPass else {
            return outcome(from: result, placement: placement, screen: screen)
        }

        let fullScreenResult = await engine.fullscreen(window)
        return outcome(from: fullScreenResult, placement: placement, screen: screen)
    }

    /// 이미 목표 상태인지 판정한다. 이것이 멱등성의 핵심이다.
    ///
    /// 전체화면 목표는 AX로 판정할 수 없다. 전체화면 앱의 창은 다른 Space에 있어
    /// `AXWindows`가 비어 있기 때문이다. `CurrentState`가 `CGWindowList`로 판정한다.
    private func isSatisfied(
        _ placement: Placement, handle: ProcessHandle, screen: ScreenPlan
    ) -> Bool {
        if screen.mode == .fullscreen {
            return CurrentState.isFullScreen(pid: handle.pid, on: screen.display)
        }
        return CurrentState.isPlaced(pid: handle.pid, target: placement.target)
    }

    private func outcome(
        from result: PlacementResult, placement: Placement, screen: ScreenPlan
    ) -> ItemOutcome {
        switch result {
        case .ok(let actual, _, _, let warnings):
            return ItemOutcome(
                screenID: screen.id, app: placement.app, status: .placed,
                expected: placement.target, actual: actual,
                detail: warnings.joined(separator: "; "))
        case .constrained(let actual, let expected, let reason):
            return ItemOutcome(
                screenID: screen.id, app: placement.app, status: .constrained,
                expected: expected, actual: actual, detail: reason)
        case .failed(let expected, let actual, let reason):
            return ItemOutcome(
                screenID: screen.id, app: placement.app, status: .failed,
                expected: expected, actual: actual, detail: reason)
        }
    }

    /// 전체가 끝난 뒤 첫 화면의 anchor로 최종 포커스를 준다.
    ///
    /// 포커스에 `NSRunningApplication.activate()`를 쓰지 않는다. 호출하는 쪽이 GUI 앱이
    /// 아니면 macOS가 무시하기 때문이다. AX 경로만 실제로 동작한다.
    private func focusFirstAnchor(_ resolved: ResolvedWorkspace) {
        guard let screen = resolved.screens.first,
              let anchor = screen.anchor,
              let bundleID = try? AppRegistry.bundleID(for: anchor),
              let app = AppLauncher.runningApplication(bundleID: bundleID) else { return }
        AXWindow.setApplicationFrontmost(pid: app.processIdentifier)
    }
}
