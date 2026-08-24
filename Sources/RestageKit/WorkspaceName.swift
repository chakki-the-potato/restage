/// 워크스페이스 이름 규칙.
///
/// 이름은 곧 파일 이름이 되고, `WorkspaceRegistry.resolve`가 인자를 이름과 경로로 가르는
/// 기준이기도 하다. 슬래시나 점이 들어오면 그쪽이 경로로 해석해 엉뚱한 파일을 연다.
/// 만드는 곳이 CLI와 메뉴 두 군데라 규칙을 한곳에 둔다.
public enum WorkspaceName {
    public static let maxLength = 64

    /// 통과하면 nil, 아니면 사용자에게 보여줄 사유.
    public static func validate(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            return L10n.string("error.name.empty")
        }
        if trimmed.count > maxLength {
            return L10n.string("error.name.too_long", maxLength)
        }
        if trimmed.contains("/") {
            return L10n.string("error.name.slash")
        }
        if trimmed.contains(".") {
            return L10n.string("error.name.dot")
        }
        if trimmed.contains(where: \.isNewline) {
            return L10n.string("error.name.newline")
        }
        if trimmed.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7F }) {
            return L10n.string("error.name.invalid")
        }
        return nil
    }

    /// 앞뒤 공백을 털어낸 저장용 이름.
    public static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespaces)
    }
}
