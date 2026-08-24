import AppKit
import RestageKit
import SwiftUI

/// 담을 항목을 고르는 상태. 알림 창이 모달로 도는 동안 뷰가 여기에 표시를 남긴다.
@MainActor
final class CaptureSelection: ObservableObject {
    /// 제외한 항목의 평탄화 인덱스. 기본은 전부 담기다.
    @Published var excluded: Set<Int> = []

    private let total: Int

    init(total: Int) {
        self.total = total
    }

    var keptCount: Int { total - excluded.count }

    func toggle(_ index: Int) {
        if excluded.contains(index) {
            excluded.remove(index)
        } else {
            excluded.insert(index)
        }
    }

    func setAll(kept: Bool) {
        excluded = kept ? [] : Set(0..<total)
    }
}

/// 담을 항목 목록. 체크를 풀면 그 창은 config에 들어가지 않는다.
///
/// 터미널의 `restage new`에는 `-번호`로 빼는 방법이 있는데 창에는 없었다. 그래서 원하는
/// 것만 담으려면 다른 앱을 미리 닫아야 했다. 그건 도구가 사용자에게 시킬 일이 아니다.
struct CaptureSelectionView: View {
    let rows: [Row]
    @ObservedObject var selection: CaptureSelection

    struct Row: Identifiable {
        let id: Int
        let screenID: String
        /// 이 행이 화면 묶음의 첫 항목이면 제목을 그린다.
        let startsScreen: Bool
        let app: String
        let detail: String
        let isUncertain: Bool
        let isOnOtherSpace: Bool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(rows) { row in
                        if row.startsScreen { screenLabel(row.screenID) }
                        line(row)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(width: 380, height: 260)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("\(selection.keptCount)개 담기")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Button("전체 선택") { selection.setAll(kept: true) }
                .buttonStyle(.link)
                .font(.system(size: 11))
            Button("전체 해제") { selection.setAll(kept: false) }
                .buttonStyle(.link)
                .font(.system(size: 11))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func screenLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 2)
    }

    private func line(_ row: Row) -> some View {
        Toggle(isOn: Binding(
            get: { !selection.excluded.contains(row.id) },
            set: { _ in selection.toggle(row.id) })
        ) {
            HStack(spacing: 6) {
                Text(row.app)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Text(row.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if row.isUncertain { tag("자리 애매", .orange) }
                if row.isOnOtherSpace { tag("다른 데스크탑", .secondary) }
                Spacer(minLength: 0)
            }
        }
        .toggleStyle(.checkbox)
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
    }

    private func tag(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 9))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color.opacity(0.14)))
    }
}

extension CaptureSelectionView {
    /// 초안을 행 목록으로 편다. 인덱스는 화면을 가로질러 이어진다.
    static func rows(for draft: WorkspaceDraft) -> [Row] {
        var rows: [Row] = []
        var index = 0
        for screen in draft.screens {
            for (position, item) in screen.items.enumerated() {
                rows.append(
                    Row(
                        id: index,
                        screenID: screen.id,
                        startsScreen: position == 0,
                        app: label(for: item),
                        detail: detail(for: item),
                        isUncertain: !item.isConfident,
                        isOnOtherSpace: !item.wasOnCurrentSpace))
                index += 1
            }
        }
        return rows
    }

    /// 제외한 항목을 뺀 초안. 항목이 하나도 남지 않은 화면은 통째로 뺀다.
    static func apply(_ excluded: Set<Int>, to draft: WorkspaceDraft) -> WorkspaceDraft {
        var result = draft
        var index = 0
        result.screens = draft.screens.compactMap { screen in
            var kept: [ItemDraft] = []
            for item in screen.items {
                defer { index += 1 }
                guard !excluded.contains(index) else { continue }
                kept.append(item)
            }
            guard !kept.isEmpty else { return nil }
            var updated = screen
            updated.items = kept
            return updated
        }
        return result
    }

    private static func label(for item: ItemDraft) -> String {
        guard let title = item.titleHint, !title.isEmpty else { return item.app }
        return "\(item.app) · \(title.count > 20 ? String(title.prefix(20)) + "…" : title)"
    }

    private static func detail(for item: ItemDraft) -> String {
        var text = item.slot.map(SlotLabel.text) ?? "크기 유지"
        if case .browser(let urls) = item.kind, !urls.isEmpty {
            text += " · 탭 \(urls.count)개"
        }
        return text
    }
}
