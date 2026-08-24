import AppKit
import RestageKit
import RestageKitDarwin
import SwiftUI

/// 항목 하나를 어디에 놓을지. 자리와 전체화면은 서로 배타적이라 한 값으로 묶는다.
enum Placement: Hashable {
    case slot(Slot)
    case fullscreen
    /// 브라우저에서만 쓴다. 창 크기를 건드리지 않는다.
    case keepSize

    var label: String {
        switch self {
        case .slot(let slot): return SlotLabel.text(slot)
        case .fullscreen: return "전체 화면"
        case .keepSize: return "크기 유지"
        }
    }
}

/// 초안을 고치는 상태. 알림 창이 모달로 도는 동안 뷰가 여기에 표시를 남긴다.
@MainActor
final class DraftEditor: ObservableObject {
    @Published var excluded: Set<Int> = []
    @Published var placements: [Int: Placement] = [:]
    /// 목록에 없던 앱을 직접 넣은 것.
    @Published var added: [ItemDraft] = []

    private let draft: WorkspaceDraft
    private let total: Int

    init(draft: WorkspaceDraft) {
        self.draft = draft
        self.total = draft.itemCount
    }

    var keptCount: Int { total - excluded.count + added.count }

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

    func add(_ item: ItemDraft) {
        added.append(item)
    }

    func removeAdded(at offset: Int) {
        guard added.indices.contains(offset) else { return }
        added.remove(at: offset)
    }

    var result: WorkspaceDraft {
        var slots: [Int: Slot] = [:]
        var fullscreen: [Int: Bool] = [:]
        for (index, placement) in placements {
            switch placement {
            case .slot(let slot):
                slots[index] = slot
                fullscreen[index] = false
            case .fullscreen:
                fullscreen[index] = true
            case .keepSize:
                break
            }
        }
        return DraftSelection.apply(
            excluding: excluded, slots: slots, fullscreen: fullscreen,
            added: added, to: draft)
    }
}

/// 담을 항목과 자리를 고르는 목록.
///
/// 새로 만들 때와 기존 것을 고칠 때 같은 화면을 쓴다.
struct DraftEditorView: View {
    let rows: [Row]
    @ObservedObject var editor: DraftEditor

    @State private var newAppName = ""
    @State private var newPlacement: Placement = .slot(.full)
    @State private var addError: String?

    struct Row: Identifiable {
        let id: Int
        let screenID: String
        let startsScreen: Bool
        let app: String
        let tabCount: Int
        let placement: Placement
        /// 자리 분류에 확신이 없는 항목. 사용자가 고르면 사라진다.
        let isUncertain: Bool
        let isOnOtherSpace: Bool
        let allowsKeepSize: Bool
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
                    if !editor.added.isEmpty {
                        screenLabel("직접 추가")
                        ForEach(Array(editor.added.enumerated()), id: \.offset) { offset, item in
                            addedLine(offset, item)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            Divider()
            addSection
        }
        .frame(width: 460, height: 340)
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
            if row.isUncertain && editor.placements[row.id] == nil {
                Text("?")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.orange)
                    .help("자리가 애매합니다. 골라주세요.")
            }
            picker(for: row)
        }
        .opacity(isKept ? 1 : 0.45)
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
    }

    private func picker(for row: Row) -> some View {
        Picker("", selection: Binding(
            get: { editor.placements[row.id] ?? row.placement },
            set: { editor.placements[row.id] = $0 })
        ) {
            ForEach(Slot.allCases, id: \.self) { slot in
                Text(SlotLabel.text(slot)).tag(Placement.slot(slot))
            }
            Divider()
            Text("전체 화면").tag(Placement.fullscreen)
            if row.allowsKeepSize {
                Text("크기 유지").tag(Placement.keepSize)
            }
        }
        .labelsHidden()
        .frame(width: 120)
    }

    private func addedLine(_ offset: Int, _ item: ItemDraft) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(Color.accentColor)
                .frame(width: 16)
            Text(item.app)
                .font(.system(size: 12))
            Spacer(minLength: 0)
            Text(item.fullscreen ? "전체 화면" : (item.slot.map(SlotLabel.text) ?? "크기 유지"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Button {
                editor.removeAdded(at: offset)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
    }

    /// 지금 안 켜둔 앱도 넣을 수 있게 한다. 캡처만으로는 켜져 있는 것만 담긴다.
    private var addSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                TextField("앱 이름 (예: Figma)", text: $newAppName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit { addApp() }
                Picker("", selection: $newPlacement) {
                    ForEach(Slot.allCases, id: \.self) { slot in
                        Text(SlotLabel.text(slot)).tag(Placement.slot(slot))
                    }
                    Divider()
                    Text("전체 화면").tag(Placement.fullscreen)
                }
                .labelsHidden()
                .frame(width: 120)
                Button("추가", action: addApp)
                    .disabled(newAppName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let addError {
                Text(addError)
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func addApp() {
        let typed = newAppName.trimmingCharacters(in: .whitespaces)
        guard !typed.isEmpty else { return }
        do {
            let bundleID = try InstalledApps.resolve(name: typed)
            let name = InstalledApps.displayName(bundleID: bundleID) ?? typed
            switch newPlacement {
            case .slot(let slot):
                editor.add(.app(name, slot: slot))
            case .fullscreen:
                editor.add(.app(name, slot: .full, fullscreen: true))
            case .keepSize:
                editor.add(.app(name, slot: .full))
            }
            newAppName = ""
            addError = nil
        } catch {
            addError = "\(error)"
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
                placement: placement(of: entry.item),
                isUncertain: !entry.item.isConfident,
                isOnOtherSpace: !entry.item.wasOnCurrentSpace,
                allowsKeepSize: entry.item.slot == nil)
        }
    }

    private static func placement(of item: ItemDraft) -> Placement {
        if item.fullscreen { return .fullscreen }
        guard let slot = item.slot else { return .keepSize }
        return .slot(slot)
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
