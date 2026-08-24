import AppKit
import RestageKit
import SwiftUI

/// 초안을 고치는 상태. 알림 창이 모달로 도는 동안 뷰가 여기에 표시를 남긴다.
@MainActor
final class DraftEditor: ObservableObject {
    /// 담지 않을 항목의 인덱스. 기본은 전부 담기다.
    @Published var excluded: Set<Int> = []
    /// 사용자가 직접 고른 자리. 비어 있으면 원래 값을 쓴다.
    @Published var slots: [Int: Slot] = [:]

    private let draft: WorkspaceDraft
    private let total: Int

    init(draft: WorkspaceDraft) {
        self.draft = draft
        self.total = draft.itemCount
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

    var result: WorkspaceDraft {
        DraftSelection.apply(excluding: excluded, slots: slots, to: draft)
    }
}

/// 담을 항목과 자리를 고르는 목록.
///
/// 새로 만들 때와 기존 것을 고칠 때 같은 화면을 쓴다. 편집이 YAML 파일을 여는 것이었을
/// 때는 자리 이름을 외워야 했고, 자리가 애매하다고 표시해도 여기서 고칠 수 없었다.
struct DraftEditorView: View {
    let rows: [Row]
    @ObservedObject var editor: DraftEditor

    struct Row: Identifiable {
        let id: Int
        let screenID: String
        /// 이 행이 화면 묶음의 첫 항목이면 제목을 그린다.
        let startsScreen: Bool
        let app: String
        let tabCount: Int
        let slot: Slot?
        /// 자리 분류에 확신이 없는 항목. 사용자가 고르면 사라진다.
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
        .frame(width: 440, height: 300)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("\(editor.keptCount)개 담기")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Button("전체 선택") { editor.setAll(kept: true) }
                .buttonStyle(.link)
                .font(.system(size: 11))
            Button("전체 해제") { editor.setAll(kept: false) }
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
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    private func line(_ row: Row) -> some View {
        let isKept = !editor.excluded.contains(row.id)
        return HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { isKept },
                set: { _ in editor.toggle(row.id) }))
                .toggleStyle(.checkbox)
                .labelsHidden()

            VStack(alignment: .leading, spacing: 1) {
                Text(row.app)
                    .font(.system(size: 12))
                    .lineLimit(1)
                if row.tabCount > 0 || row.isOnOtherSpace {
                    HStack(spacing: 5) {
                        if row.tabCount > 0 {
                            Text("탭 \(row.tabCount)개")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        if row.isOnOtherSpace {
                            Text("다른 데스크탑")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer(minLength: 4)
            slotPicker(row)
        }
        .opacity(isKept ? 1 : 0.45)
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
    }

    /// 자리를 여기서 바로 고른다. 확신이 없던 항목은 고르는 즉시 표시가 사라진다.
    private func slotPicker(_ row: Row) -> some View {
        let current = editor.slots[row.id] ?? row.slot
        let unresolved = row.isUncertain && editor.slots[row.id] == nil
        return Picker("", selection: Binding(
            get: { current },
            set: { editor.slots[row.id] = $0 })
        ) {
            ForEach(Slot.allCases, id: \.self) { slot in
                Text(SlotLabel.text(slot)).tag(Optional(slot))
            }
            if row.slot == nil {
                Text("크기 유지").tag(Optional<Slot>.none)
            }
        }
        .labelsHidden()
        .frame(width: 116)
        .overlay(alignment: .leading) {
            if unresolved {
                Text("?")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.orange)
                    .offset(x: -10)
                    .help("자리가 애매합니다. 골라주세요.")
            }
        }
    }
}

extension DraftEditorView {
    static func rows(for draft: WorkspaceDraft) -> [Row] {
        DraftSelection.entries(in: draft).map { entry in
            Row(
                id: entry.index,
                screenID: entry.screenID,
                startsScreen: entry.startsScreen,
                app: label(for: entry.item),
                tabCount: tabCount(of: entry.item),
                slot: entry.item.slot,
                isUncertain: !entry.item.isConfident,
                isOnOtherSpace: !entry.item.wasOnCurrentSpace)
        }
    }

    private static func label(for item: ItemDraft) -> String {
        guard let title = item.titleHint, !title.isEmpty else { return item.app }
        let short = title.count > 24 ? String(title.prefix(24)) + "…" : title
        return "\(item.app) · \(short)"
    }

    private static func tabCount(of item: ItemDraft) -> Int {
        if case .browser(let urls) = item.kind { return urls.count }
        return 0
    }
}
