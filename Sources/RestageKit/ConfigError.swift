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
    case directoryNotFound(path: String)
    case workspaceNotFound(name: String, path: String, available: [String])
    case invalidHotkey(String, reason: String)

    public var description: String {
        switch self {
        case .fileNotFound(let path):
            return L10n.string("error.config.file_not_found", path)
        case .unreadable(let path, let underlying):
            return L10n.string("error.config.unreadable", path, underlying)
        case .malformed(let detail):
            return L10n.string("error.config.malformed", detail)
        case .unknownItemType(let type):
            return L10n.string("error.config.unknown_item_type", type)
        case .invalidDisplaySelector(let raw):
            return L10n.string("error.config.invalid_display", raw)
        case .emptyScreens:
            return L10n.string("error.config.empty_screens")
        case .emptyItems(let screenID):
            return L10n.string("error.config.empty_items", screenID)
        case .duplicateScreenID(let id):
            return L10n.string("error.config.duplicate_screen_id", id)
        case .anchorNotInItems(let screenID, let anchor):
            return L10n.string("error.config.anchor_not_in_items", screenID, anchor.rawValue)
        case .directoryNotFound(let path):
            return L10n.string("error.config.directory_not_found", path)
        case .invalidHotkey(let raw, let reason):
            return L10n.string("error.config.invalid_hotkey", raw, reason)
        case .workspaceNotFound(let name, let path, let available):
            let known = available.isEmpty
                ? L10n.string("error.config.no_workspaces")
                : L10n.string("error.config.known_workspaces", available.joined(separator: ", "))
            return L10n.string("error.config.workspace_not_found", name, path, known)
        }
    }
}
