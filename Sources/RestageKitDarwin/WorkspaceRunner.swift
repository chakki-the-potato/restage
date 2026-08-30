import AppKit
import RestageKit

@MainActor
public struct WorkspaceRunner {
    public static let windowTimeout: Duration = .seconds(15)

    static let reachRounds = 3

    private let engine: AXWindowEngine

    public init(engine: AXWindowEngine = AXWindowEngine()) {
        self.engine = engine
    }

    public func run(
        _ resolved: ResolvedWorkspace,
        onProgress: ((RunProgress) -> Void)? = nil
    ) async -> [ItemOutcome] {
        var outcomes: [ItemOutcome] = []
        let total = resolved.screens.reduce(0) { $0 + $1.items.count } + resolved.skipped.count
        let home = HomeSpace.capture()

        for screen in resolved.screens {
            outcomes.append(contentsOf: await runScreen(
                screen, completed: outcomes.count, total: total, onProgress: onProgress))
        }

        for skipped in resolved.skipped {
            outcomes.append(ItemOutcome(
                screenID: skipped.id, app: nil, status: .skipped, detail: skipped.reason))
        }

        home.restore()
        focusFirstAnchor(resolved)
        return outcomes
    }

    private func runScreen(
        _ screen: ScreenPlan, completed: Int, total: Int,
        onProgress: ((RunProgress) -> Void)?
    ) async -> [ItemOutcome] {
        var handles: [AppID: ProcessHandle] = [:]
        var launchFailures: [AppID: String] = [:]
        var results: [Int: ItemOutcome] = [:]
        var launched = 0

        for item in screen.items {
            guard handles[item.app] == nil, launchFailures[item.app] == nil else { continue }
            onProgress?(RunProgress(
                phase: .launching, app: item.app, completed: completed + launched, total: total))
            do {
                handles[item.app] = try await engine.launch(item.app)
            } catch {
                launchFailures[item.app] = String(describing: error)
            }
            launched += 1
        }

        var positionsByApp: [AppID: [Int]] = [:]
        var appOrder: [AppID] = []
        for (position, item) in screen.items.enumerated() {
            if let reason = launchFailures[item.app] {
                results[position] = ItemOutcome(
                    screenID: screen.id, app: item.app, status: .failed, detail: reason)
                continue
            }
            guard handles[item.app] != nil else { continue }
            if positionsByApp[item.app] == nil { appOrder.append(item.app) }
            positionsByApp[item.app, default: []].append(position)
        }

        var done = 0
        let tasks = appOrder.map { app -> Task<[(Int, ItemOutcome)], Never> in
            let positions = PlacementOrder.sorted(
                positionsByApp[app, default: []], in: screen.items)
            let handle = handles[app]!
            return Task { @MainActor in
                var placed: [(Int, ItemOutcome)] = []
                for position in positions {
                    let outcome = await run(
                        screen.items[position], handle: handle, screen: screen, follow: false)
                    done += 1
                    onProgress?(RunProgress(
                        phase: .placing, app: app, completed: completed + done, total: total))
                    placed.append((position, outcome))
                }
                return placed
            }
        }
        for task in tasks {
            for (position, outcome) in await task.value { results[position] = outcome }
        }

        for _ in 0..<Self.reachRounds {
            var reached = false
            for (position, item) in screen.items.enumerated() {
                guard results[position]?.status == .unreachable,
                      let handle = handles[item.app] else { continue }
                let retried = await run(item, handle: handle, screen: screen, follow: true)
                if retried.status != .unreachable { reached = true }
                results[position] = retried
            }
            guard reached, results.values.contains(where: { $0.status == .unreachable })
            else { break }
        }

        if let anchor = screen.anchor, let handle = handles[anchor] {
            AXWindow.setApplicationFrontmost(pid: handle.pid)
        }

        return screen.items.indices.compactMap { results[$0] }
    }

    private func run(
        _ item: PlannedItem, handle: ProcessHandle, screen: ScreenPlan, follow: Bool
    ) async -> ItemOutcome {
        switch item {
        case .place(let placement):
            return await apply(placement, handle: handle, screen: screen, follow: follow)
        case .tabs(let plan):
            return await applyTabs(plan, handle: handle, screen: screen, follow: follow)
        }
    }

    private func apply(
        _ placement: Placement, handle: ProcessHandle, screen: ScreenPlan, follow: Bool
    ) async -> ItemOutcome {
        if placement.selector.titleContains == nil,
           isSatisfied(placement, handle: handle, screen: screen) {
            engine.claim(pid: handle.pid, matching: placement.target)
            return ItemOutcome(
                screenID: screen.id, app: placement.app, status: .alreadySatisfied,
                expected: placement.target, detail: L10n.string("outcome.already_satisfied"))
        }

        let window: WindowHandle
        do {
            window = try await engine.waitForWindow(
                handle, selector: placement.selector, timeout: Self.windowTimeout,
                mayFollowOtherSpaces: follow, claim: true)
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
                expected: placement.target, actual: frame, detail: L10n.string("outcome.already_satisfied"))
        }

        let result = await engine.place(window, slot: placement.slot, display: screen.display)
        let wantsFullScreen = screen.mode == .fullscreen || placement.fullscreen
        guard wantsFullScreen, result.isPass else {
            return noting(
                outcome(from: result, placement: placement, screen: screen), window: window)
        }

        let fullScreenResult = await engine.fullscreen(window)
        return noting(
            outcome(from: fullScreenResult, placement: placement, screen: screen), window: window)
    }

    private func noting(_ outcome: ItemOutcome, window: WindowHandle) -> ItemOutcome {
        guard window.wasOpened else { return outcome }
        return outcome.noting(L10n.string("outcome.opened_new_window"))
    }

    private func applyTabs(
        _ plan: TabPlan, handle: ProcessHandle, screen: ScreenPlan, follow: Bool
    ) async -> ItemOutcome {
        let dialect: BrowserDialect
        do {
            dialect = try BrowserDialect.forApp(plan.app)
        } catch {
            return ItemOutcome(
                screenID: screen.id, app: plan.app, status: .failed,
                detail: String(describing: error))
        }

        if plan.tabs.isEmpty {
            guard let target = plan.target, let slot = plan.slot else {
                return ItemOutcome(
                    screenID: screen.id, app: plan.app, status: .alreadySatisfied,
                    detail: L10n.string("outcome.nothing_to_do"))
            }
            return await apply(
                Placement(app: plan.app, slot: slot, target: target),
                handle: handle, screen: screen, follow: follow)
        }

        do {
            _ = try await engine.waitForWindow(
                handle, selector: .mostRecentlyActive, timeout: Self.windowTimeout,
                mayFollowOtherSpaces: follow, claim: false)
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
            target, slot: slot, plan: plan, handle: handle, screen: screen, tabs: tabs,
            follow: follow)
    }

    private func placeBrowserWindow(
        _ target: CGRect, slot: Slot, plan: TabPlan, handle: ProcessHandle,
        screen: ScreenPlan, tabs: TabController.Result, follow: Bool
    ) async -> ItemOutcome {
        if tabs.openedCount == 0, CurrentState.isPlaced(pid: handle.pid, target: target) {
            return ItemOutcome(
                screenID: screen.id, app: plan.app, status: .alreadySatisfied,
                expected: target, detail: L10n.string("outcome.tabs_and_placement_satisfied", plan.tabs.count))
        }

        AXWindow.setApplicationFrontmost(pid: handle.pid)
        guard let window = try? await engine.waitForWindow(
            handle, selector: .mostRecentlyActive, timeout: Self.windowTimeout,
            mayFollowOtherSpaces: follow, claim: true)
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
            detail: L10n.string("outcome.tabs_added_with_placement", tabs.openedCount, placed.detail))
    }

    private func tabOutcome(
        _ result: TabController.Result, plan: TabPlan, screen: ScreenPlan
    ) -> ItemOutcome {
        guard result.openedCount > 0 else {
            return ItemOutcome(
                screenID: screen.id, app: plan.app, status: .alreadySatisfied,
                detail: L10n.string("outcome.tabs_all_open", plan.tabs.count))
        }
        return ItemOutcome(
            screenID: screen.id, app: plan.app, status: .placed,
            detail: L10n.string("outcome.tabs_added", result.openedCount))
    }

    private func status(for error: Error, pid: Int32) -> OutcomeStatus {
        if case EngineError.noWindowMatchingTitle = error { return .failed }
        if case EngineError.windowsExhausted = error { return .failed }
        return CurrentState.windowCount(pid: pid) > 0 ? .unreachable : .failed
    }

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

    private func focusFirstAnchor(_ resolved: ResolvedWorkspace) {
        guard let screen = resolved.screens.first,
              let anchor = screen.anchor,
              let bundleID = try? InstalledApps.bundleID(for: anchor),
              let app = AppLauncher.runningApplication(bundleID: bundleID) else { return }

        let pid = app.processIdentifier
        guard WindowInventory.hereCount(pid: pid) > 0 else { return }

        AXWindow.setApplicationFrontmost(pid: pid)
        (try? AXWindow.windows(ofPID: pid))?.first { $0.currentFrame != nil }?.raise()
    }
}
