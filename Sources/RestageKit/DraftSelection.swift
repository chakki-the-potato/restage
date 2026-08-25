public enum DraftSelection {
    public struct Entry: Sendable, Equatable {
        public let index: Int
        public let screenID: String
        public let startsScreen: Bool
        public let item: ItemDraft
    }

    public static func entries(in draft: WorkspaceDraft) -> [Entry] {
        var result: [Entry] = []
        var index = 0
        for screen in draft.screens {
            for (position, item) in screen.items.enumerated() {
                result.append(
                    Entry(
                        index: index, screenID: screen.id,
                        startsScreen: position == 0, item: item))
                index += 1
            }
        }
        return result
    }

    public static func apply(
        excluding excluded: Set<Int>, slots: [Int: Slot] = [:],
        fullscreen: [Int: Bool] = [:], added: [ItemDraft] = [], to draft: WorkspaceDraft
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
