import Foundation

enum AppleScriptError: Error, CustomStringConvertible {
    case permissionDenied(applicationName: String)
    case compilationFailed(String)
    case executionFailed(code: Int, message: String)

    var description: String {
        switch self {
        case .permissionDenied(let name):
            return """
                \(name) 자동화 권한이 없습니다. 시스템 설정 > 개인정보 보호 및 보안 > \
                자동화에서 restage가 \(name)을(를) 제어하도록 허용하세요
                """
        case .compilationFailed(let message):
            return "AppleScript 컴파일 실패: \(message)"
        case .executionFailed(let code, let message):
            return "AppleScript 실행 실패(\(code)): \(message)"
        }
    }
}

@MainActor
enum AppleScriptRunner {
    /// Apple Events 권한 거부. 사용자가 팝업에서 거부했거나 설정에서 껐을 때 온다.
    private static let permissionDeniedCode = -1743

    static func run(_ source: String, applicationName: String) throws -> String {
        guard let script = NSAppleScript(source: source) else {
            throw AppleScriptError.compilationFailed(source)
        }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)

        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? 0
            let message = error[NSAppleScript.errorMessage] as? String ?? "알 수 없는 오류"
            if code == permissionDeniedCode {
                throw AppleScriptError.permissionDenied(applicationName: applicationName)
            }
            throw AppleScriptError.executionFailed(code: code, message: message)
        }
        return result.stringValue ?? ""
    }
}
