import CoreGraphics

public enum WorkspaceResolver {
    /// config와 사용 가능한 디스플레이로 구체적 목표를 계산한다.
    /// 요청한 디스플레이가 없는 화면은 건너뛰고 사유를 남긴다. 나머지 화면은 그대로 진행한다.
    public static func resolve(
        _ config: WorkspaceConfig, displays: DisplayList
    ) -> ResolvedWorkspace {
        var plans: [ScreenPlan] = []
        var skipped: [SkippedScreen] = []

        for screen in config.screens {
            guard let display = display(for: screen.display, in: displays) else {
                skipped.append(SkippedScreen(
                    id: screen.id, reason: reason(forMissing: screen.display)))
                continue
            }
            plans.append(plan(for: screen, on: display))
        }

        return ResolvedWorkspace(workspace: config.workspace, screens: plans, skipped: skipped)
    }

    private static func plan(for screen: ScreenConfig, on display: DisplayInfo) -> ScreenPlan {
        let items = screen.items.map { item -> PlannedItem in
            switch item {
            case .app(let app):
                let target = SlotGeometry.frame(
                    for: app.slot, in: display.visibleFrame, primaryMaxY: display.primaryMaxY)
                return .place(Placement(app: app.app, slot: app.slot, target: target))
            case .browser(let browser):
                let target = browser.slot.map {
                    SlotGeometry.frame(
                        for: $0, in: display.visibleFrame, primaryMaxY: display.primaryMaxY)
                }
                return .tabs(TabPlan(
                    app: browser.app, window: browser.window, slot: browser.slot,
                    target: target, tabs: browser.tabs.map(URLNormalizer.normalize)))
            }
        }

        return ScreenPlan(
            id: screen.id, display: display, mode: screen.mode,
            anchor: screen.anchor, items: items)
    }

    private static func display(
        for selector: DisplaySelector, in displays: DisplayList
    ) -> DisplayInfo? {
        switch selector {
        case .builtin, .any:
            return displays.primary
        case .external(let index):
            let position = index - 1
            guard displays.externals.indices.contains(position) else { return nil }
            return displays.externals[position]
        }
    }

    private static func reason(forMissing selector: DisplaySelector) -> String {
        switch selector {
        case .builtin, .any:
            return "주 디스플레이를 찾을 수 없습니다"
        case .external(let index):
            return "외장 디스플레이 \(index)번이 연결되어 있지 않습니다"
        }
    }
}
