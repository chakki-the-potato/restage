import SwiftUI

/// 워크스페이스 하나를 나타내는 카드.
///
/// 카드 전체가 실행 버튼이다. 편집·삭제는 마우스를 올렸을 때만 나타난다. 매일 누르는 것은
/// 실행이고 관리는 가끔이므로, 관리 버튼이 늘 보이면 실행을 누를 자리가 좁아진다.
struct WorkspaceCard: View {
    let item: PanelStore.Item
    let isRunning: Bool
    let isBusy: Bool
    let message: String?

    let onRun: () -> Void
    let onEdit: () -> Void
    let onRename: () -> Void
    let onSetHotkey: () -> Void
    let onReveal: () -> Void
    let onDelete: () -> Void
    let onDismissMessage: () -> Void

    @State private var isHovering = false

    private var isEnabled: Bool { item.isRunnable && !isBusy }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onRun) {
                header
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)

            if let warning = item.hotkeyWarning {
                noteRow(warning, symbol: "exclamationmark.triangle.fill", tint: .orange)
            }
            if let message {
                noteRow(message, symbol: "exclamationmark.circle.fill", tint: .orange,
                        onDismiss: onDismissMessage)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor)))
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor.opacity(isHovering && isEnabled ? 0.10 : 0)))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1))
        .onHover { isHovering = $0 }
        .help(item.error ?? "")
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: item.isRunnable ? "square.split.2x1" : "exclamationmark.triangle")
                .font(.system(size: 14))
                .foregroundStyle(item.isRunnable ? Color.accentColor : Color.orange)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(item.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)
            trailing
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var trailing: some View {
        if isRunning {
            ProgressView()
                .controlSize(.small)
        } else if isHovering {
            HStack(spacing: 2) {
                iconButton("pencil", "편집", onEdit)
                Menu {
                    Button("단축키 설정…", action: onSetHotkey)
                    Button("이름 바꾸기…", action: onRename)
                    Button("Finder에서 보기", action: onReveal)
                    Divider()
                    Button("삭제…", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12))
                        .frame(width: 22, height: 22)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 22)
            }
            .foregroundStyle(.secondary)
        } else if let hotkey = item.hotkey {
            Text(hotkey)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.08)))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
        }
    }

    private func iconButton(
        _ symbol: String, _ label: String, _ action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
    }

    /// 실패 사유는 알림 창 대신 카드 안에 붙인다. 모달은 흐름을 끊고, 어느 워크스페이스의
    /// 문제인지도 제목으로만 알 수 있다.
    private func noteRow(
        _ text: String, symbol: String, tint: Color, onDismiss: (() -> Void)? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("닫기")
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
}
