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
        var placements: [Placement] = []
        var unsupported: [UnsupportedItem] = []

        for item in screen.items {
            switch item {
            case .app(let app):
                let target = SlotGeometry.frame(
                    for: app.slot, in: display.visibleFrame, primaryMaxY: display.primaryMaxY)
                placements.append(Placement(app: app.app, slot: app.slot, target: target))
            case .browser(let browser):
                unsupported.append(UnsupportedItem(
                    app: browser.app, reason: "브라우저 탭 제어는 아직 구현되지 않았습니다"))
            }
        }

        return ScreenPlan(
            id: screen.id, display: display, mode: screen.mode,
            anchor: screen.anchor, placements: placements, unsupported: unsupported)
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
