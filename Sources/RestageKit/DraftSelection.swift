public enum DraftSelection {
    public struct Entry: Sendable, Equatable {
        public let index: Int
        public let screenID: String
        public let startsScreen: Bool
        public let item: ItemDraft
        public let ordinal: Int?
    }

    public static func entries(in draft: WorkspaceDraft) -> [Entry] {
        var unnamedCounts: [String: Int] = [:]
        for screen in draft.screens {
            for item in screen.items where !item.hasIdentity {
                unnamedCounts[item.app, default: 0] += 1
            }
        }

        var result: [Entry] = []
        var index = 0
        var seen: [String: Int] = [:]
        for screen in draft.screens {
            for (position, item) in screen.items.enumerated() {
                var ordinal: Int?
                if !item.hasIdentity, unnamedCounts[item.app, default: 0] > 1 {
                    seen[item.app, default: 0] += 1
                    ordinal = seen[item.app]
                }
                result.append(
                    Entry(
                        index: index, screenID: screen.id,
                        startsScreen: position == 0, item: item, ordinal: ordinal))
                index += 1
            }
        }
        return result
    }

    public static func label(for entry: Entry, titleLimit: Int = 24) -> String {
        if let title = entry.item.titleHint, !title.isEmpty {
            let short = title.count > titleLimit ? String(title.prefix(titleLimit)) + "…" : title
            return "\(entry.item.app) · \(short)"
        }
        if let ordinal = entry.ordinal { return "\(entry.item.app) \(ordinal)" }
        return entry.item.app
    }

    public static func apply(
        excluding excluded: Set<Int>, slots: [Int: Slot] = [:],
        fullscreen: [Int: Bool] = [:], tabs: [Int: [String]] = [:],
        added: [ItemDraft] = [], to draft: WorkspaceDraft
    ) -> WorkspaceDraft {
        var index = 0
        var screens: [ScreenDraft] = []

        for screen in draft.screens {
            var kept: [ItemDraft] = []
            for item in screen.items {
                defer { index += 1 }
                guard !excluded.contains(index) else { continue }
                var updated = item
                if let slot = slots[index] {
                    updated.slot = slot
                    updated.overlap = nil
                }
                if let wantsFullScreen = fullscreen[index] {
                    updated.fullscreen = wantsFullScreen
                    updated.overlap = nil
                }
                if let urls = tabs[index], updated.isBrowser {
                    updated.kind = .browser(tabs: urls)
                }
                kept.append(updated)
            }
            guard !kept.isEmpty else { continue }
            screens.append(ScreenDraft(id: screen.id, display: screen.display, items: kept))
        }

        var result = draft
        result.screens = screens
        guard !added.isEmpty else { return result }

        if result.screens.isEmpty {
            result.screens = [ScreenDraft(id: "main", display: .builtin, items: added)]
        } else {
            result.screens[0].items.append(contentsOf: added)
        }
        return result
    }
}
