import Foundation

public enum ConfigError: Error, CustomStringConvertible {
    case fileNotFound(path: String)
    case unreadable(path: String, underlying: String)
    case malformed(detail: String)
    case unknownItemType(String)
    case invalidDisplaySelector(String)
    case emptyScreens
    case emptyItems(screenID: String)
    case duplicateScreenID(String)
    case anchorNotInItems(screenID: String, anchor: AppID)

    public var description: String {
        switch self {
        case .fileNotFound(let path):
            return "config 파일을 찾을 수 없습니다: \(path)"
        case .unreadable(let path, let underlying):
            return "config 파일을 읽을 수 없습니다: \(path) — \(underlying)"
        case .malformed(let detail):
            return "config 형식이 올바르지 않습니다. \(detail)"
        case .unknownItemType(let type):
            return "알 수 없는 항목 type입니다: \(type). 가능한 값: app, browser"
        case .invalidDisplaySelector(let raw):
            return "알 수 없는 display입니다: \(raw). 가능한 값: builtin, any, external-1 이상"
        case .emptyScreens:
            return "screens가 비어 있습니다. 화면을 하나 이상 선언하세요"
        case .emptyItems(let screenID):
            return "화면 '\(screenID)'의 items가 비어 있습니다"
        case .duplicateScreenID(let id):
            return "화면 id가 중복됩니다: \(id)"
        case .anchorNotInItems(let screenID, let anchor):
            return "화면 '\(screenID)'의 anchor '\(anchor.rawValue)'가 그 화면의 items에 없습니다"
        }
    }
}
