import Foundation
import RestageKit
import RestageKitDarwin

/// 지금 열려 있는 창을 워크스페이스 초안으로 옮긴다.
///
/// 좌표를 그대로 담지 않고 `SlotClassifier`로 slot을 고른다. 좌표를 저장하면 모니터가
/// 바뀔 때마다 config를 고쳐야 하고, 그것이 이 도구가 없애려는 문제다.
@MainActor
enum WorkspaceCapture {
    struct Result {
        let draft: WorkspaceDraft
        /// 브라우저인데 탭을 읽지 못한 앱과 그 사유.
        let browsersWithoutTabs: [SkippedBrowser]
        /// 다른 데스크탑에 있어 실행 시 접근하지 못할 수 있는 항목의 개수.
        let onOtherSpaceCount: Int
        /// 창을 골라낼 수 없어 담지 않은 개수. 앱 이름별로 센다.
        let indistinguishable: [String: Int]
    }

    struct SkippedBrowser {
        let app: String
        let reason: String
    }

    static func capture(name: String, displays: DisplayList) -> Result {
        let all = WindowSnapshot.current()
        let selection = WindowIdentity.select(
            all.map { WindowIdentity.Candidate(app: $0.appName, title: $0.title) })
        let windows = selection.kept.map { all[$0] }
        let needsTitle = Set(selection.kept.enumerated().compactMap { position, original in
            selection.needsTitle.contains(original) ? position : nil
        })

        var tabsByApp: [String: [CapturedBrowserWindow]] = [:]
        var itemsByScreen: [String: [ItemDraft]] = [:]
        var order: [DisplaySelector] = []
        var withoutTabs: [String: String] = [:]

        for (position, window) in windows.enumerated() {
            let selector = displays.selector(containing: window.frame)
            guard let display = displays.info(for: selector) else { continue }
            let key = screenID(for: selector)
            if itemsByScreen[key] == nil {
                itemsByScreen[key] = []
                order.append(selector)
            }

            let match = SlotClassifier.classify(frame: window.frame, in: display)
            let item = draft(
                for: window, slot: match?.slot, overlap: match?.overlap,
                title: needsTitle.contains(position) ? window.title : nil,
                tabsByApp: &tabsByApp, withoutTabs: &withoutTabs)
            itemsByScreen[key]?.append(item)
        }

        let screens = order.sorted { rank($0) < rank($1) }.map { selector in
            ScreenDraft(
                id: screenID(for: selector), display: selector,
                items: itemsByScreen[screenID(for: selector)] ?? [])
        }
        return Result(
            draft: WorkspaceDraft(name: name, screens: screens),
            browsersWithoutTabs: withoutTabs.sorted { $0.key < $1.key }
                .map { SkippedBrowser(app: $0.key, reason: $0.value) },
            onOtherSpaceCount: windows.filter { !$0.isOnCurrentSpace }.count,
            indistinguishable: selection.droppedByApp)
    }

    /// 브라우저면 열린 탭까지 담고, 아니면 창 위치만 담는다.
    ///
    /// 브라우저 창과 창 목록을 좌표로 맞춘다. 둘 사이에 공통된 식별자가 없기 때문이다.
    private static func draft(
        for window: CapturedWindow, slot: Slot?, overlap: Double?, title: String?,
        tabsByApp: inout [String: [CapturedBrowserWindow]], withoutTabs: inout [String: String]
    ) -> ItemDraft {
        let asApp = ItemDraft.app(
            window.appName, slot: slot ?? .full, title: title,
            overlap: window.isFullScreen ? nil : overlap,
            wasOnCurrentSpace: window.isOnCurrentSpace,
            fullscreen: window.isFullScreen)
        guard InstalledApps.isBrowser(bundleID: window.bundleID) else { return asApp }

        if tabsByApp[window.appName] == nil {
            do {
                tabsByApp[window.appName] = try BrowserSnapshot.windows(of: AppID(window.appName))
            } catch {
                tabsByApp[window.appName] = []
                withoutTabs[window.appName] = String(describing: error)
            }
        }
        guard let index = BrowserSnapshot.index(
                matching: window.frame, in: tabsByApp[window.appName] ?? []),
              let entry = tabsByApp[window.appName]?.remove(at: index) else {
            withoutTabs[window.appName] = withoutTabs[window.appName]
                ?? "'\(window.title)' 창을 브라우저 쪽 목록에서 찾지 못했습니다"
            return asApp
        }

        let tabs = entry.tabs.filter(URLNormalizer.isSavable)
        guard !tabs.isEmpty else {
            withoutTabs[window.appName] = withoutTabs[window.appName]
                ?? "담을 만한 주소가 없습니다. 시작 페이지나 새 탭만 열려 있습니다"
            return asApp
        }
        return .browser(
            window.appName, slot: slot, tabs: tabs, overlap: overlap,
            wasOnCurrentSpace: window.isOnCurrentSpace)
    }

    /// 주 디스플레이를 먼저, 외장은 번호 순으로. 창을 만난 순서에 따라 목록이 뒤바뀌지 않게 한다.
    private static func rank(_ selector: DisplaySelector) -> Int {
        switch selector {
        case .builtin, .any: return 0
        case .external(let index): return index
        }
    }

    static func screenID(for selector: DisplaySelector) -> String {
        switch selector {
        case .builtin, .any: return "main"
        case .external(let index): return "external-\(index)"
        }
    }
}
