/// 초안에서 담을 항목을 고른다.
///
/// 화면과 떼어 놓는 이유는 이 계산이 틀리면 사용자가 고른 것과 다른 config가 저장되는데,
/// 화면을 눌러서는 그것을 확인하기 어렵기 때문이다. 인덱스가 화면 경계를 넘어 이어지므로
/// 하나만 어긋나도 엉뚱한 항목이 빠진다.
public enum DraftSelection {
    /// 화면을 가로질러 이어지는 평탄화 목록. 인덱스는 0부터다.
    public struct Entry: Sendable, Equatable {
        public let index: Int
        public let screenID: String
        /// 이 항목이 화면 묶음의 첫 번째인지. 목록에 화면 제목을 그릴 때 쓴다.
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

    /// 제외한 인덱스를 빼고 바꾼 자리를 적용한 초안.
    ///
    /// 항목이 하나도 남지 않은 화면은 통째로 뺀다. 빈 화면이 남으면 파싱에 실패한다.
    /// 자리를 직접 고른 항목은 확신도를 지운다. 사용자가 정한 값에 물음표가 붙으면
    /// 도구가 그 선택을 의심하는 것처럼 보인다.
    public static func apply(
        excluding excluded: Set<Int>, slots: [Int: Slot] = [:], to draft: WorkspaceDraft
    ) -> WorkspaceDraft {
        var index = 0
        var screens: [ScreenDraft] = []

        for screen in draft.screens {
            var kept: [ItemDraft] = []
            for item in screen.items {
                defer { index += 1 }
                guard !excluded.contains(index) else { continue }
                guard let slot = slots[index] else {
                    kept.append(item)
                    continue
                }
                var updated = item
                updated.slot = slot
                updated.overlap = nil
                kept.append(updated)
            }
            guard !kept.isEmpty else { continue }
            screens.append(ScreenDraft(id: screen.id, display: screen.display, items: kept))
        }

        var result = draft
        result.screens = screens
        return result
    }
}
