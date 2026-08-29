import RestageKit
import SwiftUI

struct WorkspaceCard: View {
    let item: PanelStore.Item
    let isRunning: Bool
    let isBusy: Bool
    let progress: RunProgress?
    let message: String?

    let onRun: () -> Void
    let onEdit: () -> Void
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
        .help(item.error ?? item.subtitle)
    }

    private var header: some View {
        HStack(spacing: 11) {
            AppIconStack(apps: item.summary?.apps ?? [], isDimmed: !item.isRunnable)
                .frame(height: 21)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    if item.isLastOpened {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                            .help(L10n.string("card.last_opened"))
                    }
                    Text(item.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(item.isRunnable ? .primary : .secondary)
                }
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

    private var running: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(progressText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            progressBar
        }
    }

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
                iconButton("pencil", L10n.string("card.menu.edit"), onEdit)
                iconButton("ellipsis", L10n.string("card.menu.more"), onToggleActions)
                    .menuAnchor(item.name)
            }
            .foregroundStyle(.secondary)
        } else if let hotkey = item.hotkey {
            chip(hotkey)
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
