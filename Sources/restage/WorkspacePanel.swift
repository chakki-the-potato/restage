import RestageKit
import RestageKitDarwin
import SwiftUI

/// 메뉴바 아이콘을 누르면 뜨는 패널.
struct WorkspacePanel: View {
    @ObservedObject var store: PanelStore

    /// 창을 여는 동작 전에 패널을 닫는다. 알림 창이 패널 뒤에 가리면 눌 수 없다.
    let dismiss: () -> Void
    let onQuit: () -> Void

    /// 펼쳐진 카드의 이름. 한 번에 하나만 펼친다.
    @State private var expandedCard: String?
    @State private var showsOptions = false

    private var isBusy: Bool { store.runningName != nil }

    private func collapseAll() {
        expandedCard = nil
        showsOptions = false
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 320)
        // 팝오버 기본 재질을 그대로 두면 앱이 비활성일 때 어두워진다. 다른 창을 클릭했을
        // 뿐인데 패널 색이 바뀌면 무언가 꺼진 것처럼 보인다. 불투명 배경으로 덮는다.
        .background(Color(nsColor: .windowBackgroundColor))
        .onExitCommand { collapseAll() }
    }

    // MARK: - 머리말

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.split.2x1")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.accentColor)
            Text("restage")
                .font(.system(size: 13, weight: .semibold))
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
            isExpanded: expandedCard == item.name,
            onRun: { store.run(item.name) },
            onEdit: { act { editWorkspace(item.name) } },
            onToggleActions: {
                showsOptions = false
                expandedCard = expandedCard == item.name ? nil : item.name
            },
            onRename: { act { rename(item.name) } },
            onSetHotkey: { act { setHotkey(for: item) } },
            onReveal: { act { WorkspaceFiles.revealInFinder(item.name) } },
            onDelete: { act { delete(item.name) } },
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

    @ViewBuilder
    private var footer: some View {
        if showsOptions { optionRows }
        HStack {
            Text("restage \(Bundle.main.shortVersion)")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
            Button {
                expandedCard = nil
                showsOptions.toggle()
            } label: {
                HStack(spacing: 3) {
                    Text("Options")
                        .font(.system(size: 11))
                    Image(systemName: showsOptions ? "chevron.down" : "chevron.up")
                        .font(.system(size: 8, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    /// Options도 `Menu`로 만들지 않는다. macOS 메뉴가 열려 있으면 화면 다른 곳을 눌러도
    /// 메뉴만 닫히고 패널이 남는다. 패널 안에서 펼치면 그 클릭이 패널까지 닿는다.
    private var optionRows: some View {
        VStack(spacing: 0) {
            if store.loginItemSupported {
                Button {
                    store.toggleLoginItem()
                } label: {
                    optionLabel(
                        "로그인 시 자동 실행",
                        symbol: store.loginItemEnabled ? "checkmark.square.fill" : "square")
                }
                .buttonStyle(HighlightRowStyle())
            }
            Button {
                act { WorkspaceFiles.revealConfigFolder(); return nil }
            } label: {
                optionLabel("config 폴더 열기", symbol: "folder")
            }
            .buttonStyle(HighlightRowStyle())
            Button(action: onQuit) {
                optionLabel("종료", symbol: "power")
            }
            .buttonStyle(HighlightRowStyle())
            Divider()
        }
    }

    private func optionLabel(_ title: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .frame(width: 16)
            Text(title)
                .font(.system(size: 12))
            Spacer(minLength: 0)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }

    /// 패널을 닫고 동작을 실행한다. 실패하면 사유를 알린다.
    private func act(_ operation: @escaping () -> String?) {
        collapseAll()
        dismiss()
        DispatchQueue.main.async {
            if let failure = operation() {
                Prompt.message("처리하지 못했습니다", failure)
            }
            store.reload()
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

        guard let edited = DraftDialog.edit(
            existing, title: "'\(name)' 편집", notes: [])
        else { return nil }
        return WorkspaceFiles.save(edited)
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
