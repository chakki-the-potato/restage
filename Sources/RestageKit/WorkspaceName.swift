public enum WorkspaceName {
    public static let maxLength = 64

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

    public static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespaces)
    }
}
