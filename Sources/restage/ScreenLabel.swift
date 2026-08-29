import RestageKit

enum ScreenLabel {
    static func text(_ display: DisplaySelector) -> String {
        switch display {
        case .builtin, .any:
            return L10n.string("screen.primary")
        case .external(let index):
            return L10n.string("screen.monitor", index + 1)
        }
    }
}
