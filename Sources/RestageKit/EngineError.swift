public enum EngineError: Error, CustomStringConvertible {
    case accessibilityNotTrusted
    case appNotFound(name: String, suggestions: [String])
    case ambiguousApp(name: String, candidates: [String])
    case applicationNotFound(bundleID: String)
    case launchFailed(bundleID: String, underlying: String)
    case windowTimeout(pid: Int32, seconds: Double)
    case windowOnOtherSpace(pid: Int32, windowCount: Int)
    case noWindowMatchingTitle(pid: Int32, wanted: String, available: [String])
    case axDisabled
    case browserWithoutTabControl(name: String)
    case notABrowser(name: String)

    public var description: String {
        switch self {
        case .accessibilityNotTrusted:
            return "접근성 권한이 없습니다. 시스템 설정에서 이 터미널 앱을 승인하세요."
        case .appNotFound(let name, let suggestions):
            let hint = suggestions.isEmpty
                ? ""
                : " 혹시 이건가요: \(suggestions.joined(separator: ", "))"
            return "'\(name)'이라는 이름의 앱이 설치되어 있지 않습니다.\(hint)"
        case .ambiguousApp(let name, let candidates):
            return "'\(name)'에 해당하는 앱이 여럿입니다: \(candidates.joined(separator: ", "))"
        case .applicationNotFound(let bundleID):
            return "설치되지 않은 앱입니다: \(bundleID)"
        case .launchFailed(let bundleID, let underlying):
            return "실행 실패: \(bundleID) — \(underlying)"
        case .windowTimeout(let pid, let seconds):
            return "\(seconds)초 안에 창이 뜨지 않았습니다 (pid \(pid))"
        case .noWindowMatchingTitle(_, let wanted, let available):
            let titles = available.isEmpty
                ? "열린 창이 없습니다"
                : "열린 창: \(available.joined(separator: ", "))"
            return "제목에 '\(wanted)'를 포함한 창을 찾지 못했습니다. \(titles)"
        case .windowOnOtherSpace(let pid, let count):
            return "창 \(count)개가 다른 Space에 있어 접근할 수 없습니다 (pid \(pid))"
        case .axDisabled:
            return "AX API가 비활성 상태입니다 (kAXErrorAPIDisabled). 접근성 권한을 확인하세요."
        case .browserWithoutTabControl(let name):
            return "\(name)은 탭 제어를 지원하지 않습니다. 창 배치는 되지만 tabs는 열 수 없습니다."
        case .notABrowser(let name):
            return "\(name)은 브라우저가 아닙니다. type을 app으로 바꾸세요."
        }
    }
}
