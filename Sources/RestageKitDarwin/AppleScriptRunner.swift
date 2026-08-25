import Foundation
import RestageKit

enum AppleScriptError: Error, CustomStringConvertible {
    case permissionDenied(applicationName: String)
    case compilationFailed(String)
    case executionFailed(code: Int, message: String)

    var description: String {
        switch self {
        case .permissionDenied(let name):
            return L10n.string("error.applescript.permission_denied", name)
        case .compilationFailed(let message):
            return L10n.string("error.applescript.compile_failed", message)
        case .executionFailed(let code, let message):
            return L10n.string("error.applescript.execute_failed", Int(code), message)
        }
    }
}

@MainActor
enum AppleScriptRunner {
    private static let permissionDeniedCode = -1743

    static func run(_ source: String, applicationName: String) throws -> String {
        guard let script = NSAppleScript(source: source) else {
            throw AppleScriptError.compilationFailed(source)
        }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)

        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? 0
            let message = error[NSAppleScript.errorMessage] as? String ?? L10n.string("error.applescript.unknown")
            if code == permissionDeniedCode {
                throw AppleScriptError.permissionDenied(applicationName: applicationName)
            }
            throw AppleScriptError.executionFailed(code: code, message: message)
        }
        return result.stringValue ?? ""
    }
}
