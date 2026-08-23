public enum EngineError: Error, CustomStringConvertible {
    case accessibilityNotTrusted
    case unknownApp(AppID)
    case applicationNotFound(bundleID: String)
    case launchFailed(bundleID: String, underlying: String)
    case windowTimeout(pid: Int32, seconds: Double)
    case windowOnOtherSpace(pid: Int32, windowCount: Int)
    case axDisabled

    public var description: String {
        switch self {
        case .accessibilityNotTrusted:
            return "접근성 권한이 없습니다. 시스템 설정에서 이 터미널 앱을 승인하세요."
        case .unknownApp(let id):
            return "레지스트리에 없는 앱입니다: \(id.rawValue)"
        case .applicationNotFound(let bundleID):
            return "설치되지 않은 앱입니다: \(bundleID)"
        case .launchFailed(let bundleID, let underlying):
            return "실행 실패: \(bundleID) — \(underlying)"
        case .windowTimeout(let pid, let seconds):
            return "\(seconds)초 안에 창이 뜨지 않았습니다 (pid \(pid))"
        case .windowOnOtherSpace(let pid, let count):
            return "창 \(count)개가 다른 Space에 있어 접근할 수 없습니다 (pid \(pid))"
        case .axDisabled:
            return "AX API가 비활성 상태입니다 (kAXErrorAPIDisabled). 접근성 권한을 확인하세요."
        }
    }
}
