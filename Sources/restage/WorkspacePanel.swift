import AppKit
import RestageKit
import RestageKitDarwin
import SwiftUI

/// 메뉴바 아이콘을 누르면 뜨는 패널.
struct WorkspacePanel: View {
    @ObservedObject var store: PanelStore
    @StateObject private var language = LanguageSetting()

    /// 창을 여는 동작 전에 패널을 닫는다. 알림 창이 패널 뒤에 가리면 눌 수 없다.
    let dismiss: () -> Void
    /// 창을 닫은 뒤 패널을 다시 여는 길.
    let reopen: () -> Void
    /// 시스템 메뉴를 띄우는 길. 두 번째 인자는 버튼의 창 좌표다.
    let presentMenu: ([PanelMenu.Item], CGRect) -> Void
    let onQuit: () -> Void

    /// 각 카드의 더보기 버튼 위치. 그 자리에 메뉴를 띄운다.
    @State private var anchors: [String: CGRect] = [:]
    private var isBusy: Bool { store.runningName != nil }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 320)
        // 팝오버 기본 재질을 그대로 두면 앱이 비활성일 때 어두워진다. 다른 창을 클릭했을
        // 뿐인데 패널 색이 바뀌면 무언가 꺼진 것처럼 보인다. 불투명 배경으로 덮는다.
        .background(Color(nsColor: .windowBackgroundColor))
        .onPreferenceChange(MenuAnchorKey.self) { anchors = $0 }
        .onExitCommand { dismiss() }
    }

    private static let optionsAnchor = "__options"

    /// 카드의 더보기 메뉴 항목.
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
                    isChecked: AppearanceSetting.current == appearance, keepsPanelOpen: true
                ) {
                    AppearanceSetting.current = appearance
                })
        }
        items.append(PanelMenu.separator())
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

    // MARK: - 머리말

    /// 설정을 머리말 오른쪽으로 올린다. 꼬리말에 버튼 하나만 두면 구분선과 여백까지
    /// 38pt를 그 하나에 쓴다.
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.split.2x1")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.accentColor)
            Text("restage")
                .font(.system(size: 13, weight: .semibold))
            Text("v\(Bundle.main.shortVersion)")
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

    // MARK: - 본문

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !store.accessibilityGranted { permissionBanner }
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

    /// 처음 여는 사람이 보는 화면. 무엇이 없는지만 알리면 다음에 무엇을 해야 하는지
    /// 알 수 없다.
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

    /// 배너 전체를 누르게 두면 눌러도 되는지 알 수 없다. 버튼을 따로 두고 왜 필요한지를
    /// 한 줄로 적는다.
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

    // MARK: - 동작

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

    /// 패널을 닫고 동작을 실행한다. 실패하면 사유를 알린다.
    private func act(_ operation: @escaping () -> String?) {
        dismiss()
        DispatchQueue.main.async {
            if let failure = operation() {
                Prompt.message(L10n.string("dialog.failed.title"), failure)
            }
            store.reload()
            // 창이 끝나면 패널을 다시 연다. 이름을 바꾸고 단축키도 정하려면 매번 메뉴바를
            // 다시 눌러야 하는데, 한 번에 하나만 하라는 뜻이 아니다.
            reopen()
        }
    }

    /// 저장된 config를 설정 창으로 불러와 고친다.
    ///
    /// 파일을 편집기로 여는 방식이었을 때는 자리 이름을 외워야 했고, 자리가 애매하다는
    /// 표시를 봐도 그 자리에서 고칠 수 없었다.
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

    /// 새 버전이 있는지 GitHub에 물어본다. 사용자가 누를 때만 부른다.
    private func checkForUpdate() {
        dismiss()
        Task { @MainActor in
            switch await UpdateChecker.check(current: Bundle.main.shortVersion) {
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

    /// 새 버전을 알린다. 받는 방법이 설치 경로마다 달라 문구도 갈린다.
    private func announce(latest: SemanticVersion, page: String) {
        let title = L10n.string("update.available.title", "\(latest)")
        let current = Bundle.main.shortVersion

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

    private func delete(_ name: String) -> String? {
        guard Prompt.confirmDestructive(
            title: L10n.string("dialog.delete.title", name),
            body: L10n.string("dialog.delete.body"),
            confirmTitle: L10n.string("card.menu.delete"))
        else { return nil }
        return WorkspaceFiles.moveToTrash(name)
    }
}

extension Bundle {
    var shortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}
