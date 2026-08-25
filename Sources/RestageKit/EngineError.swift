public enum EngineError: Error, CustomStringConvertible {
    case accessibilityNotTrusted
    case appNotFound(name: String, suggestions: [String])
    case ambiguousApp(name: String, candidates: [String])
    case applicationNotFound(bundleID: String)
    case launchFailed(bundleID: String, underlying: String)
    case windowTimeout(pid: Int32, seconds: Double)
    case windowOnOtherSpace(pid: Int32, windowCount: Int)
    case windowOffDisplay(pid: Int32, windowCount: Int)
    case noWindowMatchingTitle(pid: Int32, wanted: String, available: [String])
    case axDisabled
    case browserWithoutTabControl(name: String)
    case notABrowser(name: String)

    public var description: String {
        switch self {
        case .accessibilityNotTrusted:
            return L10n.string("error.engine.accessibility_not_trusted")
        case .appNotFound(let name, let suggestions):
            let hint = suggestions.isEmpty
                ? ""
                : L10n.string(
                    "error.engine.app_not_found.suggestion",
                    suggestions.joined(separator: ", "))
            return L10n.string("error.engine.app_not_found", name) + hint
        case .ambiguousApp(let name, let candidates):
            return L10n.string(
                "error.engine.ambiguous_app", name, candidates.joined(separator: ", "))
        case .applicationNotFound(let bundleID):
            return L10n.string("error.engine.application_not_found", bundleID)
        case .launchFailed(let bundleID, let underlying):
            return L10n.string("error.engine.launch_failed", bundleID, underlying)
        case .windowTimeout(let pid, let seconds):
            return L10n.string("error.engine.window_timeout", seconds)
        case .noWindowMatchingTitle(_, let wanted, let available):
            let titles = available.isEmpty
                ? L10n.string("error.engine.no_windows_open")
                : L10n.string("error.engine.windows_open", available.joined(separator: ", "))
            return L10n.string("error.engine.no_window_matching_title", wanted, titles)
        case .windowOnOtherSpace(let pid, let count):
            return L10n.string("error.engine.window_on_other_space", count)
        case .windowOffDisplay(_, let count):
            return L10n.string("error.engine.window_off_display", count)
        case .axDisabled:
            return L10n.string("error.engine.ax_disabled")
        case .browserWithoutTabControl(let name):
            return L10n.string("error.engine.browser_without_tab_control", name)
        case .notABrowser(let name):
            return L10n.string("error.engine.not_a_browser", name)
        }
    }
}
