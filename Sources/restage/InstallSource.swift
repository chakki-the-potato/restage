import Foundation

enum InstallSource {
    case homebrew
    case elsewhere

    static var current: InstallSource {
        from(path: Bundle.main.bundleURL.resolvingSymlinksInPath().path)
    }

    static func from(path: String) -> InstallSource {
        path.contains("/Cellar/restage/") ? .homebrew : .elsewhere
    }

    static let formula = "chakki-the-potato/tap/restage"
}
