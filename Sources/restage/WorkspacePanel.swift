import AppKit
import RestageKit
import RestageKitDarwin
import SwiftUI

/// 메뉴바 아이콘을 누르면 뜨는 패널.
struct WorkspacePanel: View {
    @ObservedObject var store: PanelStore

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
            Divider()
            footer
        }
        .frame(width: 320)
        // 배경은 PanelChrome이 그린다. 여기서 덮으면 둥근 모서리와 화살표가 가려진다.
        .onPreferenceChange(MenuAnchorKey.self) { anchors = $0 }
        .onExitCommand { dismiss() }
    }

    private static let optionsAnchor = "__options"

    /// 카드의 더보기 메뉴 항목.
    private func cardMenuItems(_ item: PanelStore.Item) -> [PanelMenu.Item] {
        [
            PanelMenu.Item(title: "이름 변경", symbol: "pencil.line") {
                act { rename(item.name) }
            },
            PanelMenu.Item(title: "단축키 변경", symbol: "keyboard") {
                act { setHotkey(for: item) }
            },
            PanelMenu.Item(title: "파일로 열기", symbol: "doc.text") {
                act { WorkspaceFiles.revealInFinder(item.name) }
            },
            PanelMenu.separator(),
            PanelMenu.Item(title: "삭제", symbol: "trash", isDestructive: true) {
                act { delete(item.name) }
            },
        ]
    }

    private var optionsMenuItems: [PanelMenu.Item] {
        var items: [PanelMenu.Item] = []
        if store.loginItemSupported {
            items.append(
                PanelMenu.Item(
                    title: "로그인 시 자동 실행", symbol: "arrow.up.forward.app",
                    isChecked: store.loginItemEnabled, keepsPanelOpen: true
                ) {
                    store.toggleLoginItem()
                })
        }
        items.append(
            PanelMenu.Item(title: "업데이트 확인", symbol: "arrow.down.circle") {
                checkForUpdate()
            })
        items.append(
            PanelMenu.Item(title: "config 폴더 열기", symbol: "folder") {
                act { WorkspaceFiles.revealConfigFolder(); return nil }
            })
        items.append(PanelMenu.separator())
        items.append(PanelMenu.Item(title: "종료", symbol: "power") { onQuit() })
        return items
    }

    // MARK: - 머리말

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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - 본문

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !store.accessibilityGranted { permissionBanner }
            if let listError = store.listError {
                notice(listError, symbol: "exclamationmark.triangle")
            } else if store.items.isEmpty {
                notice("등록된 워크스페이스가 없습니다", symbol: "tray")
            } else {
                sectionLabel("워크스페이스")
                ForEach(store.items) { item in card(item) }
            }
            createButton
        }
        .padding(14)
    }

    private func card(_ item: PanelStore.Item) -> some View {
        WorkspaceCard(
            item: item,
            isRunning: store.runningName == item.name,
            isBusy: isBusy,
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
        Button {
            act {
                NewWorkspaceDialog.run()
                return nil
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 18)
                Text("현재 창 배치로 새로 만들기")
                    .font(.system(size: 12))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    Color.primary.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        .disabled(isBusy)
    }

    private var permissionBanner: some View {
        Button {
            act {
                _ = AccessibilityPermission.requestIfNeeded()
                if let url = URL(string: AccessibilityPermission.settingsDeepLink) {
                    NSWorkspace.shared.open(url)
                }
                return nil
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text("접근성 권한이 필요합니다")
                        .font(.system(size: 12, weight: .medium))
                    Text("눌러서 시스템 설정 열기")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.12)))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 2)
    }

    private func notice(_ text: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    // MARK: - 꼬리말

    private var footer: some View {
        HStack {
            Spacer()
            Button {
                guard let anchor = anchors[Self.optionsAnchor] else { return }
                presentMenu(optionsMenuItems, anchor)
            } label: {
                HStack(spacing: 3) {
                    Text("Options")
                        .font(.system(size: 11))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .menuAnchor(Self.optionsAnchor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    /// 패널을 닫고 동작을 실행한다. 실패하면 사유를 알린다.
    private func act(_ operation: @escaping () -> String?) {
        dismiss()
        DispatchQueue.main.async {
            if let failure = operation() {
                Prompt.message("처리하지 못했습니다", failure)
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
            return "'\(name)'을 읽지 못했습니다: \(error)"
        }

        guard case .saved(let edited) = DraftDialog.edit(
            existing, title: "'\(name)' 편집", notes: [])
        else { return nil }
        return WorkspaceFiles.save(edited)
    }

    /// 새 버전이 있는지 GitHub에 물어본다. 사용자가 누를 때만 부른다.
    private func checkForUpdate() {
        dismiss()
        Task { @MainActor in
            switch await UpdateChecker.check(current: Bundle.main.shortVersion) {
            case .upToDate(let version):
                Prompt.message("최신 버전입니다", "v\(version)을 쓰고 있습니다.")
            case .available(let latest, let url):
                if Prompt.confirmDestructive(
                    title: "새 버전 v\(latest)이 있습니다",
                    body: "지금 쓰는 것은 v\(Bundle.main.shortVersion)입니다.\n"
                        + "받는 방법은 릴리스 페이지에 있습니다.",
                    confirmTitle: "릴리스 페이지 열기", destructive: false),
                   let page = URL(string: url) {
                    NSWorkspace.shared.open(page)
                }
            case .failed(let reason):
                Prompt.message("업데이트를 확인하지 못했습니다", reason)
            }
            reopen()
        }
    }

    private func rename(_ name: String) -> String? {
        guard let typed = Prompt.text(
            title: "이름 바꾸기", body: "'\(name)'의 새 이름을 정하세요.", initial: name)
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
            title: "'\(name)'을 삭제할까요?",
            body: "휴지통으로 보냅니다. 필요하면 거기서 되돌릴 수 있습니다.",
            confirmTitle: "삭제")
        else { return nil }
        return WorkspaceFiles.moveToTrash(name)
    }
}

extension Bundle {
    var shortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}
