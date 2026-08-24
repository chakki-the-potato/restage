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
        for item in screen.items {
            guard handles[item.app] == nil, launchFailures[item.app] == nil else { continue }
            do {
                handles[item.app] = try await engine.launch(item.app)
            } catch {
                launchFailures[item.app] = String(describing: error)
            }
        }

        for item in screen.items {
            if let reason = launchFailures[item.app] {
                outcomes.append(ItemOutcome(
                    screenID: screen.id, app: item.app, status: .failed, detail: reason))
                continue
            }
            guard let handle = handles[item.app] else { continue }

            switch item {
            case .place(let placement):
                outcomes.append(await apply(placement, handle: handle, screen: screen))
            case .tabs(let plan):
                outcomes.append(await applyTabs(plan, handle: handle, screen: screen))
            }
        }

        if let anchor = screen.anchor, let handle = handles[anchor] {
            AXWindow.setApplicationFrontmost(pid: handle.pid)
        }

        return outcomes
    }

    private func apply(
        _ placement: Placement, handle: ProcessHandle, screen: ScreenPlan
    ) async -> ItemOutcome {
        if placement.selector.titleContains == nil,
           isSatisfied(placement, handle: handle, screen: screen) {
            return ItemOutcome(
                screenID: screen.id, app: placement.app, status: .alreadySatisfied,
                expected: placement.target, detail: "이미 목표 상태")
        }

        let window: WindowHandle
        do {
            window = try await engine.waitForWindow(
                handle, selector: placement.selector, timeout: Self.windowTimeout)
        } catch {
            return ItemOutcome(
                screenID: screen.id, app: placement.app,
                status: status(for: error, pid: handle.pid),
                expected: placement.target, detail: String(describing: error))
        }

        if placement.selector.titleContains != nil, screen.mode != .fullscreen,
           let frame = window.currentFrame, CurrentState.matches(frame, placement.target) {
            return ItemOutcome(
                screenID: screen.id, app: placement.app, status: .alreadySatisfied,
                expected: placement.target, actual: frame, detail: "이미 목표 상태")
        }

        let result = await engine.place(window, slot: placement.slot, display: screen.display)
        // 화면 단위 mode와 항목 단위 fullscreen 중 하나라도 켜져 있으면 전용 데스크탑으로 보낸다.
        let wantsFullScreen = screen.mode == .fullscreen || placement.fullscreen
        guard wantsFullScreen, result.isPass else {
            return outcome(from: result, placement: placement, screen: screen)
        }

        let fullScreenResult = await engine.fullscreen(window)
        return outcome(from: fullScreenResult, placement: placement, screen: screen)
    }

    private func applyTabs(
        _ plan: TabPlan, handle: ProcessHandle, screen: ScreenPlan
    ) async -> ItemOutcome {
        let dialect: BrowserDialect
        do {
            dialect = try BrowserDialect.forApp(plan.app)
        } catch {
            return ItemOutcome(
                screenID: screen.id, app: plan.app, status: .failed,
                detail: String(describing: error))
        }

        do {
            _ = try await engine.waitForWindow(
                handle, selector: .mostRecentlyActive, timeout: Self.windowTimeout)
        } catch {
            let status: OutcomeStatus = CurrentState.windowCount(pid: handle.pid) > 0
                ? .unreachable : .failed
            return ItemOutcome(
                screenID: screen.id, app: plan.app, status: status,
                detail: String(describing: error))
        }

        let tabs: TabController.Result
        do {
            tabs = try await TabController.apply(plan, dialect: dialect)
        } catch {
            return ItemOutcome(
                screenID: screen.id, app: plan.app, status: .failed,
                detail: String(describing: error))
        }

        guard let target = plan.target, let slot = plan.slot else {
            return tabOutcome(tabs, plan: plan, screen: screen)
        }
        return await placeBrowserWindow(
            target, slot: slot, plan: plan, handle: handle, screen: screen, tabs: tabs)
    }

    /// 탭 작업을 한 창을 배치한다.
    ///
    /// AppleScript로 식별한 창과 AX 창을 직접 대응시킬 방법이 없으므로, 그 앱을 맨 앞으로
    /// 올린 뒤 AX 창 목록의 첫 번째를 쓴다. AX 목록은 최근 활성 순이다.
    private func placeBrowserWindow(
        _ target: CGRect, slot: Slot, plan: TabPlan, handle: ProcessHandle,
        screen: ScreenPlan, tabs: TabController.Result
    ) async -> ItemOutcome {
        if tabs.openedCount == 0, CurrentState.isPlaced(pid: handle.pid, target: target) {
            return ItemOutcome(
                screenID: screen.id, app: plan.app, status: .alreadySatisfied,
                expected: target, detail: "탭 \(plan.tabs.count)개와 창 위치 모두 이미 목표 상태")
        }

        AXWindow.setApplicationFrontmost(pid: handle.pid)
        guard let window = try? await engine.waitForWindow(
            handle, selector: .mostRecentlyActive, timeout: Self.windowTimeout)
        else {
            return tabOutcome(tabs, plan: plan, screen: screen)
        }
        let result = await engine.place(window, slot: slot, display: screen.display)
        let placed = outcome(
            from: result,
            placement: Placement(app: plan.app, slot: slot, target: target),
            screen: screen)
        guard tabs.openedCount > 0 else { return placed }
        return ItemOutcome(
            screenID: placed.screenID, app: placed.app, status: placed.status,
            expected: placed.expected, actual: placed.actual,
            detail: "탭 \(tabs.openedCount)개 추가. \(placed.detail)")
    }

    private func tabOutcome(
        _ result: TabController.Result, plan: TabPlan, screen: ScreenPlan
    ) -> ItemOutcome {
        guard result.openedCount > 0 else {
            return ItemOutcome(
                screenID: screen.id, app: plan.app, status: .alreadySatisfied,
                detail: "탭 \(plan.tabs.count)개 모두 이미 열려 있음")
        }
        return ItemOutcome(
            screenID: screen.id, app: plan.app, status: .placed,
            detail: "탭 \(result.openedCount)개 추가")
    }

    /// 제목이 안 맞는 것은 config를 고쳐야 하는 문제이므로 `unreachable`이 아니라 `failed`다.
    /// `unreachable`은 다른 Space에 있어 손댈 수 없다는 뜻으로만 쓴다.
    private func status(for error: Error, pid: Int32) -> OutcomeStatus {
        if case EngineError.noWindowMatchingTitle = error { return .failed }
        return CurrentState.windowCount(pid: pid) > 0 ? .unreachable : .failed
    }

    /// 이미 목표 상태인지 판정한다. 이것이 멱등성의 핵심이다.
    ///
    /// 제목을 지정한 항목에는 쓰지 않는다. 이 판정은 그 앱의 아무 창이나 목표에 있으면
    /// 참을 내므로, 창이 여러 개인 앱에서 엉뚱한 창을 보고 통과시킨다.
    /// 그 경우에는 창을 먼저 찾은 뒤 그 창의 좌표를 직접 비교한다.
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
              let bundleID = try? InstalledApps.bundleID(for: anchor),
              let app = AppLauncher.runningApplication(bundleID: bundleID) else { return }
        AXWindow.setApplicationFrontmost(pid: app.processIdentifier)
    }
}
