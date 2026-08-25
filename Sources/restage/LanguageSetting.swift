import RestageKit
import SwiftUI

@MainActor
final class LanguageSetting: ObservableObject {
    @Published private(set) var current: AppLanguage = L10n.language

    var effective: AppLanguage { L10n.effective }

    func select(_ language: AppLanguage) {
        guard language != current else { return }
        L10n.language = language
        current = language
    }
}

struct LanguagePill: View {
    @ObservedObject var setting: LanguageSetting

    var body: some View {
        HStack(spacing: 2) {
            segment(.korean, "한국어")
            segment(.english, "English")
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.06)))
    }

    private func segment(_ language: AppLanguage, _ label: String) -> some View {
        let isSelected = setting.effective == language
        return Button {
            setting.select(language)
        } label: {
            Text(label)
                .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isSelected ? PanelPalette.cardBackground : .clear)
                .shadow(color: .black.opacity(isSelected ? 0.14 : 0), radius: 1, y: 1))
    }
}
