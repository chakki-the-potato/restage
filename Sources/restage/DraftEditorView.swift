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
        case .fullscreen: return L10n.string("placement.fullscreen")
        case .keepSize: return L10n.string("placement.keep_size")
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
        /// 창과 고른 자리가 얼마나 겹치는지. 물음표를 설명할 때 쓴다.
        let overlap: Double?
        let isOnOtherSpace: Bool
        let allowsKeepSize: Bool

        /// 물음표에 마우스를 올렸을 때 보여줄 설명.
        ///
        /// "애매하다"만 적으면 무엇이 애매한지 알 수 없다. 어느 자리와 얼마나 어긋나는지를
        /// 보여줘야 그대로 둘지 다른 자리를 고를지 판단할 수 있다.
        var uncertaintyDetail: String {
            let percent = overlap.map { Int(($0 * 100).rounded()) }
            let match = percent.map { L10n.string("draft.overlap_percent", $0) }
                ?? L10n.string("draft.overlap_poor")
            return L10n.string("draft.uncertainty_detail", placement.label, match)
        }
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
                        screenLabel(L10n.string("draft.added_by_hand"))
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
            Text(L10n.string("draft.keep_count", editor.keptCount))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Button(L10n.string("draft.select_all")) { editor.setAll(kept: true) }
                .buttonStyle(.link)
                .font(.system(size: 11))
            Button(L10n.string("draft.select_none")) { editor.setAll(kept: false) }
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
                            Text(L10n.string("summary.tabs", row.tabCount))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        if row.isOnOtherSpace {
                            Text(L10n.string("draft.other_desktop"))
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
                    .frame(width: 12)
                    .contentShape(Rectangle())
                    .help(row.uncertaintyDetail)
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
            Text(L10n.string("placement.fullscreen")).tag(Placement.fullscreen)
            if row.allowsKeepSize {
                Text(L10n.string("placement.keep_size")).tag(Placement.keepSize)
            }
        }
        .labelsHidden()
        .frame(width: 120)
        .help(L10n.string("draft.placement_help"))
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
            Text(item.fullscreen
                ? L10n.string("placement.fullscreen")
                : (item.slot.map(SlotLabel.text) ?? L10n.string("placement.keep_size")))
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
                TextField(L10n.string("draft.app_name_placeholder"), text: $newAppName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit { addApp() }
                Picker("", selection: $newPlacement) {
                    ForEach(Slot.allCases, id: \.self) { slot in
                        Text(SlotLabel.text(slot)).tag(Placement.slot(slot))
                    }
                    Divider()
                    Text(L10n.string("placement.fullscreen")).tag(Placement.fullscreen)
                }
                .labelsHidden()
                .frame(width: 120)
                Button(L10n.string("common.add"), action: addApp)
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
                overlap: entry.item.overlap,
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
