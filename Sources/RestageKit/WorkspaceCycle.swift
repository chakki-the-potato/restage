public enum WorkspaceCycle {
    public static func next(after last: String?, in names: [String]) -> String? {
        guard let first = names.first else { return nil }
        guard let last, let index = names.firstIndex(of: last) else { return first }
        return names[(index + 1) % names.count]
    }
}
