import RestageKit
import SwiftUI

/// 고른 언어를 들고 있다가 화면에 다시 그리라고 알린다.
///
/// `L10n`이 값을 저장하고 뷰는 이 객체를 본다. 저장만으로는 이미 그려진 화면이 바뀌지
/// 않으므로 알림을 낼 자리가 하나 필요하다.
@MainActor
final class LanguageSetting: ObservableObject {
    @Published private(set) var current: AppLanguage = L10n.language

    /// 화면에서 켜둘 칸. 고르지 않았으면 시스템이 고른 언어가 켜져 있다.
    var effective: AppLanguage { L10n.effective }

    func select(_ language: AppLanguage) {
        guard language != current else { return }
        L10n.language = language
        current = language
    }
}

/// 한국어와 English를 고르는 작은 컨트롤.
///
/// '자동' 칸을 따로 두지 않는다. 고르지 않았으면 시스템이 고른 쪽이 켜져 있으므로 자동은
/// 이미 두 칸 중 하나로 보인다. 세 번째 칸은 무엇이 켜져 있는지만 흐리게 만든다.
///
/// 언어 이름은 그 언어로 적는다. 자기 언어를 찾는 사람이 읽을 수 있어야 한다.
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
