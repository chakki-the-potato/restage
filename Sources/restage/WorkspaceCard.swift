import RestageKit
import SwiftUI

/// 워크스페이스 하나를 나타내는 카드.
///
/// 카드 전체가 실행 버튼이다. 편집과 더보기는 마우스를 올렸을 때만 나타난다. 매일 누르는
/// 것은 실행이고 관리는 가끔이므로, 관리 버튼이 늘 보이면 실행을 누를 자리가 좁아진다.
///
/// 더보기 메뉴는 카드가 아니라 패널이 그린다. 카드 안에 그리면 다음 카드에 가려지고
/// 카드 높이도 늘어나 목록이 밀린다. 카드는 버튼 위치만 올려보낸다.
struct WorkspaceCard: View {
    let item: PanelStore.Item
    let isRunning: Bool
    let isBusy: Bool
    let progress: RunProgress?
    let message: String?

    let onRun: () -> Void
    let onEdit: () -> Void
    let onSetHotkey: () -> Void
    let onToggleActions: () -> Void
    let onDismissMessage: () -> Void

    @State private var isHovering = false

    private var isEnabled: Bool { item.isRunnable && !isBusy }
    private var isHighlighted: Bool { isHovering && isEnabled }

    private var missing: [AppID] {
        item.summary.map { WorkspaceIcons.missingApps(among: $0.apps) } ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onRun) {
                header
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)

            ForEach(missing, id: \.rawValue) { app in
                noteRow(L10n.string("panel.app_not_installed", app.rawValue))
            }
            if let warning = item.hotkeyWarning {
                noteRow(warning)
            }
            if let message {
                noteRow(message, onRetry: onRun, onDismiss: onDismissMessage)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHighlighted ? PanelPalette.hoverTint : PanelPalette.cardBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isHighlighted ? PanelPalette.hoverBorder : PanelPalette.cardBorder,
                    lineWidth: 1))
        .onHover { isHovering = $0 }
        .help(item.error ?? "")
    }

    private var header: some View {
        HStack(spacing: 11) {
            AppIconStack(apps: item.summary?.apps ?? [], isDimmed: !item.isRunnable)
                .frame(height: 21)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(item.isRunnable ? .primary : .secondary)
                if isRunning {
                    running
                } else {
                    subtitle
                }
            }

            Spacer(minLength: 4)
            if !isRunning { trailing }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var subtitle: some View {
        HStack(spacing: 5) {
            if let summary = item.summary {
                LayoutGlyph(shape: summary.shape)
            }
            Text(item.subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    /// 실행 중에는 부제 자리에 어디까지 갔는지를 적는다. 도는 표시만으로는 멈춘 것인지
    /// 알 수 없고, 앱을 여는 데 몇 초가 걸린다.
    private var running: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(progressText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            progressBar
        }
    }

    /// 막대를 직접 그린다. `ProgressView`는 AppKit 컨트롤이라 3pt 높이도, 카드 안의
    /// 색도 우리가 정한 대로 나오지 않는다.
    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.10))
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: 3)
    }

    private var progressText: String {
        guard let progress, let app = progress.app else { return "" }
        let key = progress.phase == .launching
            ? "panel.progress.launching" : "panel.progress.placing"
        return L10n.string(key, app.rawValue, progress.completed + 1, progress.total)
    }

    private var fraction: Double {
        guard let progress, progress.total > 0 else { return 0 }
        return Double(progress.completed) / Double(progress.total)
    }

    @ViewBuilder
    private var trailing: some View {
        if isHovering {
            HStack(spacing: 3) {
                hotkeyChip
                iconButton("pencil", L10n.string("card.menu.edit"), onEdit)
                iconButton("ellipsis", L10n.string("card.menu.more"), onToggleActions)
                    .menuAnchor(item.name)
            }
            .foregroundStyle(.secondary)
        } else if let hotkey = item.hotkey {
            chip(hotkey)
        }
    }

    /// 마우스를 올렸을 때만 점선 자리를 보여준다. 늘 보이면 미지정 카드가 많은 목록에서
    /// 점선만 반복된다. 이미 지정된 칩은 올려도 그대로 둔다. 확인하려고 올렸는데 사라지면
    /// 곤란하다.
    @ViewBuilder
    private var hotkeyChip: some View {
        if let hotkey = item.hotkey {
            chip(hotkey)
        } else {
            Button(action: onSetHotkey) {
                Text(L10n.string("panel.hotkey.placeholder"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(
                                Color.primary.opacity(0.20),
                                style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
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
        _ text: String, onRetry: (() -> Void)? = nil, onDismiss: (() -> Void)? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(PanelPalette.warning)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let onRetry {
                Button(action: onRetry) {
                    Text(L10n.string("panel.retry"))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.accentColor)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
            }
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(L10n.string("panel.dismiss"))
            }
        }
        .padding(.horizontal, 11)
        .padding(.bottom, 9)
    }
}
