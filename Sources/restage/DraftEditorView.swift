import AppKit
import RestageKit
import RestageKitDarwin
import SwiftUI

enum Placement: Hashable {
    case slot(Slot)
    case fullscreen
    case keepSize

    var label: String {
        switch self {
        case .slot(let slot): return SlotLabel.text(slot)
        case .fullscreen: return L10n.string("placement.fullscreen")
        case .keepSize: return L10n.string("placement.keep_size")
        }
    }
}

@MainActor
final class DraftEditor: ObservableObject {
    @Published var excluded: Set<Int> = []
    @Published var placements: [Int: Placement] = [:]
    @Published var added: [ItemDraft] = []
    @Published var tabs: [Int: [String]] = [:]
    @Published var folders: [Int: String?] = [:]
    @Published var hideOthers: Bool

    private let draft: WorkspaceDraft
    private let total: Int

    init(draft: WorkspaceDraft) {
        self.draft = draft
        self.total = draft.itemCount
        self.hideOthers = draft.hideOthers
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

    func addedTabs(at offset: Int) -> [String] {
        added.indices.contains(offset) ? added[offset].tabs : []
    }

    func setAddedTabs(_ urls: [String], at offset: Int) {
        guard added.indices.contains(offset) else { return }
        added[offset].kind = .browser(tabs: urls)
    }

    func setFolder(_ path: String?, at index: Int) {
        folders[index] = .some(path)
    }

    func setAddedFolder(_ path: String?, at offset: Int) {
        guard added.indices.contains(offset) else { return }
        added[offset].open = path
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
        var result = DraftSelection.apply(
            excluding: excluded, slots: slots, fullscreen: fullscreen, tabs: tabs,
            folders: folders, added: added, to: draft)
        result.hideOthers = hideOthers
        return result
    }
}

struct DraftEditorView: View {
    let rows: [Row]
    @ObservedObject var editor: DraftEditor

    enum AddMode: Hashable {
        case app
        case web
    }

    @State private var addMode: AddMode = .app
    @State private var newAppName = ""
    @State private var newURLRows: [String] = [""]
    @State private var newPlacement: Placement = .slot(.full)
    @State private var addError: String?
    @State private var tabsPopoverRow: Int?
    @State private var tabsPopoverAdded: Int?
    @State private var suggestions: [InstalledApp] = []
    @State private var isDropTarget = false

    struct Row: Identifiable {
        let id: Int
        let screenName: String
        let startsScreen: Bool
        let app: String
        let sourceApp: String
        let sourceFrame: CGRect?
        let isBrowser: Bool
        let tabs: [String]
        let open: String?
        let placement: Placement
        let isUncertain: Bool
        let overlap: Double?
        let isOnOtherSpace: Bool
        let allowsKeepSize: Bool

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
                        if row.startsScreen { screenLabel(row.screenName) }
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
            Toggle(L10n.string("draft.hide_others"), isOn: $editor.hideOthers)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
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
                nameLabel(row)
                HStack(spacing: 5) {
                    if row.isBrowser { tabsButton(row) } else { folderButton(row) }
                    if row.isOnOtherSpace {
                            Text(L10n.string("draft.other_desktop"))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
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

    @ViewBuilder
    private func nameLabel(_ row: Row) -> some View {
        if let frame = row.sourceFrame, !row.isOnOtherSpace {
            Button {
                WindowReveal.raise(app: row.sourceApp, frame: frame)
            } label: {
                Text(row.app)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L10n.string("draft.reveal_help"))
        } else {
            Text(row.app)
                .font(.system(size: 12))
                .lineLimit(1)
        }
    }

    private func tabsButton(_ row: Row) -> some View {
        let tabs = editor.tabs[row.id] ?? row.tabs
        return tabsLabel(count: tabs.count) { tabsPopoverRow = row.id }
            .popover(isPresented: Binding(
                get: { tabsPopoverRow == row.id },
                set: { shown in
                    guard !shown else { return }
                    editor.tabs[row.id] = DraftTabs.cleaned(editor.tabs[row.id] ?? row.tabs)
                    tabsPopoverRow = nil
                })
            ) {
                DraftTabsPopover(urls: Binding(
                    get: { editor.tabs[row.id] ?? row.tabs },
                    set: { editor.tabs[row.id] = $0 }))
            }
    }

    private func folderButton(_ row: Row) -> some View {
        let current = editor.folders[row.id] ?? row.open
        return folderLabel(current) { path in editor.setFolder(path, at: row.id) }
    }

    private func addedFolderButton(_ offset: Int, _ item: ItemDraft) -> some View {
        folderLabel(item.open) { path in editor.setAddedFolder(path, at: offset) }
    }

    private func folderLabel(_ current: String?, set: @escaping (String?) -> Void) -> some View {
        HStack(spacing: 3) {
            Button {
                if let chosen = FolderChooser.choose(startingAt: current) { set(chosen) }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "folder")
                        .font(.system(size: 9))
                    Text(FolderChooser.label(current))
                        .font(.system(size: 10))
                        .lineLimit(1)
                }
                .foregroundStyle(current == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(current ?? L10n.string("draft.choose_folder"))
            if current != nil {
                Button {
                    set(nil)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(L10n.string("draft.clear_folder"))
            }
        }
    }

    private func addedTabsButton(_ offset: Int) -> some View {
        tabsLabel(count: editor.addedTabs(at: offset).count) { tabsPopoverAdded = offset }
            .popover(isPresented: Binding(
                get: { tabsPopoverAdded == offset },
                set: { shown in
                    guard !shown else { return }
                    editor.setAddedTabs(
                        DraftTabs.cleaned(editor.addedTabs(at: offset)), at: offset)
                    tabsPopoverAdded = nil
                })
            ) {
                DraftTabsPopover(urls: Binding(
                    get: { editor.addedTabs(at: offset) },
                    set: { editor.setAddedTabs($0, at: offset) }))
            }
    }

    private func tabsLabel(count: Int, open: @escaping () -> Void) -> some View {
        Button(action: open) {
            Text(count == 0
                ? L10n.string("summary.no_tabs")
                : L10n.string("summary.tabs", count))
                .font(.system(size: 10))
                .foregroundStyle(count == 0 ? Color.orange : Color.accentColor)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(L10n.string("draft.tabs_help"))
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
            if item.isBrowser { addedTabsButton(offset) } else { addedFolderButton(offset, item) }
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

    private var addSection: some View {
        VStack(alignment: .leading, spacing: Self.rowSpacing) {
            HStack(spacing: Self.columnSpacing) {
                Picker("", selection: $addMode) {
                    Text(L10n.string("draft.add_mode.app")).tag(AddMode.app)
                    Text(L10n.string("draft.add_mode.web")).tag(AddMode.web)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: Self.modeWidth)
                .onChange(of: addMode) { mode in
                    suggestions = []
                    if mode == .app { newURLRows = [""] }
                }
                nameField
                Picker("", selection: $newPlacement) {
                    ForEach(Slot.allCases, id: \.self) { slot in
                        Text(SlotLabel.text(slot)).tag(Placement.slot(slot))
                    }
                    Divider()
                    Text(L10n.string("placement.fullscreen")).tag(Placement.fullscreen)
                }
                .labelsHidden()
                .frame(width: 120)
                Button(L10n.string("common.add"), action: add)
                    .disabled(!canAdd)
                    .frame(width: Self.addButtonWidth)
            }
            if addMode == .web { urlRow }
            if let addError {
                Text(addError)
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            AppChooser.acceptDrop(providers) { name in addResolved(name) }
        }
    }

    private static let modeWidth: CGFloat = 90
    private static let addButtonWidth: CGFloat = 54
    private static let columnSpacing: CGFloat = 6
    private static let rowSpacing: CGFloat = 8

    private var urlRow: some View {
        URLRowsField(
            rows: $newURLRows, leadingInset: Self.modeWidth,
            trailingWidth: Self.addButtonWidth, spacing: Self.columnSpacing)
    }

    private var nameField: some View {
        AppNameField(
            text: $newAppName,
            placeholder: L10n.string(addMode == .app
                ? "draft.app_name_placeholder" : "draft.browser_name_placeholder"),
            isDropTarget: isDropTarget,
            onChooseFile: chooseFile)
            .onSubmit { add() }
            .onChange(of: newAppName) { typed in
                suggestions = AppChooser.suggestions(for: typed, browsersOnly: addMode == .web)
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTarget) { providers in
                AppChooser.acceptDrop(providers) { name in addResolved(name) }
            }
            .popover(
                isPresented: Binding(
                    get: { !suggestions.isEmpty },
                    set: { shown in if !shown { suggestions = [] } }),
                attachmentAnchor: .rect(.bounds), arrowEdge: .top
            ) {
                suggestionList
            }
    }

    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions, id: \.bundleID) { app in
                Button {
                    newAppName = app.name
                    suggestions = []
                    addError = nil
                } label: {
                    Text(app.name)
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .frame(width: 220)
    }

    private func chooseFile() {
        guard let name = AppChooser.chooseFile() else { return }
        newAppName = name
        suggestions = []
        addError = nil
    }

    private func addResolved(_ name: String) {
        guard addMode == .app else {
            newAppName = name
            suggestions = []
            addError = nil
            return
        }
        switch newPlacement {
        case .slot(let slot):
            editor.add(.app(name, slot: slot))
        case .fullscreen:
            editor.add(.app(name, slot: .full, fullscreen: true))
        case .keepSize:
            editor.add(.app(name, slot: .full))
        }
        newAppName = ""
        suggestions = []
        addError = nil
    }

    private var canAdd: Bool {
        let hasName = !newAppName.trimmingCharacters(in: .whitespaces).isEmpty
        guard addMode == .web else { return hasName }
        return hasName && !parsedURLs.isEmpty
    }

    private var parsedURLs: [String] {
        newURLRows
            .flatMap { $0.split(whereSeparator: { $0.isWhitespace || $0.isNewline }) }
            .map(String.init)
            .filter { !$0.isEmpty }
            .map(URLNormalizer.normalize)
    }

    private func add() {
        let typed = newAppName.trimmingCharacters(in: .whitespaces)
        guard !typed.isEmpty else { return }
        guard let name = resolvedName(typed) else { return }

        switch addMode {
        case .app:
            addResolved(name)
            return
        case .web:
            let urls = parsedURLs
            guard !urls.isEmpty else {
                addError = L10n.string("draft.no_urls")
                return
            }
            let slot: Slot?
            if case .slot(let chosen) = newPlacement { slot = chosen } else { slot = nil }
            editor.add(
                .browser(
                    name, slot: slot, tabs: urls, fullscreen: newPlacement == .fullscreen))
            newURLRows = [""]
        }
        newAppName = ""
        suggestions = []
        addError = nil
    }

    private func resolvedName(_ typed: String) -> String? {
        if let fromPath = AppChooser.appName(fromPath: typed) { return fromPath }
        do {
            let bundleID = try InstalledApps.resolve(name: typed)
            return InstalledApps.displayName(bundleID: bundleID) ?? typed
        } catch {
            addError = "\(error)"
            return nil
        }
    }
}

extension DraftEditorView {
    static func rows(for draft: WorkspaceDraft) -> [Row] {
        DraftSelection.entries(in: draft).map { entry in
            Row(
                id: entry.index,
                screenName: ScreenLabel.text(entry.display),
                startsScreen: entry.startsScreen,
                app: DraftSelection.label(for: entry),
                sourceApp: entry.item.app,
                sourceFrame: entry.item.sourceFrame,
                isBrowser: entry.item.isBrowser,
                tabs: entry.item.tabs,
                open: entry.item.open,
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

}
