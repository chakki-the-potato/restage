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
            return "이름을 입력하세요"
        }
        if trimmed.count > maxLength {
            return "이름이 너무 깁니다. \(maxLength)자 이하로 적으세요"
        }
        if trimmed.contains("/") {
            return "이름에 / 는 쓸 수 없습니다"
        }
        if trimmed.contains(".") {
            return "이름에 . 은 쓸 수 없습니다. 확장자는 자동으로 붙습니다"
        }
        if trimmed.contains(where: \.isNewline) {
            return "이름에 줄바꿈은 쓸 수 없습니다"
        }
        if trimmed.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7F }) {
            return "이름에 쓸 수 없는 문자가 있습니다"
        }
        return nil
    }

    /// 앞뒤 공백을 털어낸 저장용 이름.
    public static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespaces)
    }
}
