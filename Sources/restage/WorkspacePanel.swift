import AppKit
import RestageKit
import RestageKitDarwin
import SwiftUI

struct WorkspacePanel: View {
    @ObservedObject var store: PanelStore
    @StateObject private var language = LanguageSetting()

    let dismiss: () -> Void
    let reopen: () -> Void
    let presentMenu: ([PanelMenu.Item], CGRect) -> Void
    let onQuit: () -> Void

    @State private var anchors: [String: CGRect] = [:]
    private var isBusy: Bool { store.runningName != nil }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
        .onPreferenceChange(MenuAnchorKey.self) { anchors = $0 }
        .onExitCommand { dismiss() }
    }

    private static let optionsAnchor = "__options"

    private func cardMenuItems(_ item: PanelStore.Item) -> [PanelMenu.Item] {
        [
            PanelMenu.Item(title: L10n.string("card.menu.rename"), symbol: "pencil.line") {
                act { rename(item.name) }
            },
            PanelMenu.Item(title: L10n.string("card.menu.change_shortcut"), symbol: "keyboard") {
                act { setHotkey(for: item) }
            },
            PanelMenu.Item(title: L10n.string("card.menu.reveal"), symbol: "doc.text") {
                act { WorkspaceFiles.revealInFinder(item.name) }
            },
            PanelMenu.separator(),
            PanelMenu.Item(
                title: L10n.string("card.menu.delete"), symbol: "trash", isDestructive: true
            ) {
                act { delete(item.name) }
            },
        ]
    }

    private var optionsMenuItems: [PanelMenu.Item] {
        var items: [PanelMenu.Item] = []
        if store.loginItemSupported {
            items.append(
                PanelMenu.Item(
                    title: L10n.string("options.open_at_login"), symbol: "arrow.up.forward.app",
                    isChecked: store.loginItemEnabled, keepsPanelOpen: true
                ) {
                    store.toggleLoginItem()
                })
        }
        items.append(PanelMenu.separator())
        items.append(PanelMenu.header(L10n.string("options.appearance")))
        for appearance in AppAppearance.allCases {
            items.append(
                PanelMenu.Item(
                    title: L10n.string(appearance.titleKey), symbol: appearance.symbol,
                    isChecked: AppearanceSetting.current == appearance, isEnabled: !isBusy,
                    keepsPanelOpen: true
                ) {
                    AppearanceSetting.current = appearance
                })
        }
        items.append(PanelMenu.separator())
        items.append(
            PanelMenu.Item(
                title: L10n.string("options.cycle_hotkey"),
                symbol: "arrow.triangle.2.circlepath", isEnabled: !isBusy
            ) {
                act { setCycleHotkey() }
            })
        items.append(
            PanelMenu.Item(
                title: L10n.string("options.check_updates"), symbol: "arrow.down.circle"
            ) {
                checkForUpdate()
            })
        items.append(
            PanelMenu.Item(title: L10n.string("options.open_config_folder"), symbol: "folder") {
                act { WorkspaceFiles.revealConfigFolder(); return nil }
            })
        items.append(PanelMenu.separator())
        items.append(
            PanelMenu.Item(title: L10n.string("options.quit"), symbol: "power") { onQuit() })
        return items
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.split.2x1")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.accentColor)
            Text("restage")
                .font(.system(size: 13, weight: .semibold))
            Text("v\(AppVersion.current)")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
            Button {
                guard let anchor = anchors[Self.optionsAnchor] else { return }
                presentMenu(optionsMenuItems, anchor)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .menuAnchor(Self.optionsAnchor)
            .help(L10n.string("panel.settings"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !store.accessibilityGranted { permissionBanner }
            if let cycleWarning = store.cycleWarning { notice(cycleWarning) }
            if let listError = store.listError {
                notice(listError)
            } else if store.items.isEmpty {
                emptyState
            } else {
                ForEach(store.items) { item in card(item) }
                createButton
            }
            languageRow
        }
        .padding(12)
    }

    private func card(_ item: PanelStore.Item) -> some View {
        WorkspaceCard(
            item: item,
            isRunning: store.runningName == item.name,
            isBusy: isBusy,
            progress: store.runningName == item.name ? store.progress : nil,
            message: store.messages[item.name],
            onRun: { store.run(item.name) },
            onEdit: { act { editWorkspace(item.name) } },
            onToggleActions: {
                guard let anchor = anchors[item.name] else { return }
                presentMenu(cardMenuItems(item), anchor)
            },
            onDismissMessage: { store.dismissMessage(for: item.name) })
    }

    private var createButton: some View {
        Button(action: create) {
            HStack(spacing: 11) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 21)
                    .foregroundStyle(.secondary)
                Text(L10n.string("panel.new_from_current"))
                    .font(.system(size: 12))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    Color.primary.opacity(0.20), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .padding(.top, 2))
        .disabled(isBusy)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            LayoutGlyph(shape: .leftRight)
                .scaleEffect(2.6)
                .frame(width: 46, height: 34)
                .padding(.bottom, 4)
            VStack(spacing: 3) {
                Text(L10n.string("panel.empty.title"))
                    .font(.system(size: 12, weight: .semibold))
                Text(L10n.string("panel.empty.body"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button(action: create) {
                Text(L10n.string("panel.empty.button"))
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private var permissionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(PanelPalette.warning)
            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.string("panel.permission.title"))
                    .font(.system(size: 12, weight: .semibold))
                Text(L10n.string("panel.permission.body"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button(action: openAccessibilitySettings) {
                Text(L10n.string("panel.permission.button"))
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PanelPalette.warning.opacity(0.12)))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(PanelPalette.warning.opacity(0.28), lineWidth: 1))
    }

    private var languageRow: some View {
        HStack {
            Spacer()
            LanguagePill(setting: language)
                .disabled(isBusy)
        }
        .padding(.top, 2)
    }

    private func notice(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    private func create() {
        act {
            NewWorkspaceDialog.run()
            return nil
        }
    }

    private func openAccessibilitySettings() {
        act {
            _ = AccessibilityPermission.requestIfNeeded()
            if let url = URL(string: AccessibilityPermission.settingsDeepLink) {
                NSWorkspace.shared.open(url)
            }
            return nil
        }
    }

    private func act(_ operation: @escaping () -> String?) {
        dismiss()
        DispatchQueue.main.async {
            if let failure = operation() {
                Prompt.message(L10n.string("dialog.failed.title"), failure)
            }
            store.reload()
            reopen()
        }
    }

    private func editWorkspace(_ name: String) -> String? {
        let existing: WorkspaceDraft
        do {
            let path = try WorkspaceRegistry().resolve(name)
            existing = DraftFromConfig.draft(from: try ConfigLoader.load(path: path))
        } catch {
            return L10n.string("error.read_failed", name, "\(error)")
        }

        guard case .saved(let edited) = DraftDialog.edit(
            existing, title: L10n.string("dialog.edit.title", name), notes: [])
        else { return nil }
        return WorkspaceFiles.save(edited)
    }

    private func checkForUpdate() {
        dismiss()
        Task { @MainActor in
            switch await UpdateChecker.check(current: AppVersion.current) {
            case .upToDate(let version):
                Prompt.message(
                    L10n.string("update.current.title"),
                    L10n.string("update.current.body", "\(version)"))
            case .available(let latest, let url):
                announce(latest: latest, page: url)
            case .failed(let reason):
                Prompt.message(L10n.string("update.failed.title"), reason)
            }
            reopen()
        }
    }

    private func announce(latest: SemanticVersion, page: String) {
        let title = L10n.string("update.available.title", "\(latest)")
        let current = AppVersion.current

        guard InstallSource.current == .elsewhere else {
            Prompt.message(
                title,
                L10n.string("update.available.body.homebrew", current, InstallSource.formula))
            return
        }
        if Prompt.confirmDestructive(
            title: title,
            body: L10n.string("update.available.body", current),
            confirmTitle: L10n.string("update.available.confirm"), destructive: false),
           let url = URL(string: page) {
            NSWorkspace.shared.open(url)
        }
    }

    private func rename(_ name: String) -> String? {
        guard let typed = Prompt.text(
            title: L10n.string("dialog.rename.title"),
            body: L10n.string("dialog.rename.body", name), initial: name)
        else { return nil }
        return WorkspaceFiles.rename(name, to: typed)
    }

    private func setHotkey(for item: PanelStore.Item) -> String? {
        switch HotkeyRecorder.record(workspace: item.name, current: item.hotkeySpec) {
        case .set(let spec):
            return WorkspaceFiles.setHotkey(spec.configString, for: item.name)
        case .cleared:
            return WorkspaceFiles.setHotkey(nil, for: item.name)
        case .cancelled:
            return nil
        }
    }

    private func setCycleHotkey() -> String? {
        switch HotkeyRecorder.record(
            workspace: L10n.string("options.cycle_hotkey_title"), current: CycleSettings.spec
        ) {
        case .set(let spec):
            CycleSettings.hotkey = spec.configString
        case .cleared:
            CycleSettings.hotkey = nil
        case .cancelled:
            break
        }
        return nil
    }

    private func delete(_ name: String) -> String? {
        guard Prompt.confirmDestructive(
            title: L10n.string("dialog.delete.title", name),
            body: L10n.string("dialog.delete.body"),
            confirmTitle: L10n.string("card.menu.delete"))
        else { return nil }
        return WorkspaceFiles.moveToTrash(name)
    }
}
