import Foundation
import RestageKit
import RestageKitDarwin

@MainActor
enum WorkspaceCapture {
    struct Result {
        let draft: WorkspaceDraft
        let browsersWithoutTabs: [SkippedBrowser]
        let browsersWithoutURLs: [String]
        let onOtherSpaceCount: Int
        let hasSharedFullScreen: Bool
        let byOrder: [String: Int]
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
        var withoutURLs: [String] = []

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
                tabsByApp: &tabsByApp, withoutTabs: &withoutTabs, withoutURLs: &withoutURLs)
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
            browsersWithoutURLs: Array(Set(withoutURLs)).sorted(),
            onOtherSpaceCount: windows.filter { !$0.isOnCurrentSpace }.count,
            hasSharedFullScreen: windows.contains { $0.isSharedFullScreen },
            byOrder: selection.byOrderByApp)
    }

    private static func draft(
        for window: CapturedWindow, slot: Slot?, overlap: Double?, title: String?,
        tabsByApp: inout [String: [CapturedBrowserWindow]], withoutTabs: inout [String: String],
        withoutURLs: inout [String]
    ) -> ItemDraft {
        var asApp = ItemDraft.app(
            window.appName, slot: slot ?? .full, title: title,
            overlap: window.isFullScreen ? nil : overlap,
            wasOnCurrentSpace: window.isOnCurrentSpace,
            fullscreen: window.isFullScreen)
        asApp.sourceFrame = window.frame
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
                ?? L10n.string("error.capture.window_not_in_browser", window.title)
            return asApp
        }

        let tabs = entry.tabs.filter(URLNormalizer.isSavable)
        if tabs.isEmpty { withoutURLs.append(window.appName) }
        var browser = ItemDraft.browser(
            window.appName, slot: slot, tabs: tabs, overlap: overlap,
            wasOnCurrentSpace: window.isOnCurrentSpace)
        browser.sourceFrame = window.frame
        return browser
    }

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
