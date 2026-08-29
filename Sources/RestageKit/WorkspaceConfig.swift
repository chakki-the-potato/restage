import Foundation
import Yams

public struct WorkspaceConfig: Decodable, Sendable {
    public let workspace: String
    public let hotkey: String?
    public let hideOthers: Bool
    public let screens: [ScreenConfig]

    private enum Keys: String, CodingKey {
        case workspace, hotkey, hideOthers, screens
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        workspace = try container.decode(String.self, forKey: .workspace)
        hotkey = try container.decodeIfPresent(String.self, forKey: .hotkey)
        hideOthers = try container.decodeIfPresent(Bool.self, forKey: .hideOthers) ?? false
        screens = try container.decode([ScreenConfig].self, forKey: .screens)
    }

    public static func decode(yaml: String) throws -> WorkspaceConfig {
        do {
            return try YAMLDecoder().decode(WorkspaceConfig.self, from: yaml)
        } catch let error as ConfigError {
            throw error
        } catch {
            throw ConfigError.malformed(detail: String(describing: error))
        }
    }
}

public struct ScreenConfig: Decodable, Sendable {
    public let id: String
    public let display: DisplaySelector
    public let mode: ScreenMode
    public let anchor: AppID?
    public let whenMissing: MissingDisplayPolicy
    public let items: [ItemConfig]

    private enum Keys: String, CodingKey {
        case id, display, mode, anchor, items, whenMissing
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        id = try container.decode(String.self, forKey: .id)
        display = try container.decodeIfPresent(DisplaySelector.self, forKey: .display) ?? .any
        mode = try container.decodeIfPresent(ScreenMode.self, forKey: .mode) ?? .desktop
        anchor = try container.decodeIfPresent(AppID.self, forKey: .anchor)
        whenMissing = try container.decodeIfPresent(
            MissingDisplayPolicy.self, forKey: .whenMissing) ?? .skip
        items = try container.decode([ItemConfig].self, forKey: .items)
    }
}

public enum ScreenMode: String, Decodable, Sendable {
    case fullscreen
    case desktop
}

public enum MissingDisplayPolicy: String, Decodable, Sendable {
    case skip
    case fullscreen
}

public enum DisplaySelector: Decodable, Sendable, Equatable {
    case builtin
    case external(index: Int)
    case any

    private static let externalPrefix = "external-"

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "builtin": self = .builtin
        case "any": self = .any
        default:
            guard raw.hasPrefix(Self.externalPrefix),
                  let index = Int(raw.dropFirst(Self.externalPrefix.count)),
                  index >= 1 else {
                throw ConfigError.invalidDisplaySelector(raw)
            }
            self = .external(index: index)
        }
    }
}

public enum ItemConfig: Sendable, Equatable {
    case app(AppItem)
    case browser(BrowserItem)

    public var appID: AppID {
        switch self {
        case .app(let item): return item.app
        case .browser(let item): return item.app
        }
    }
}

public struct AppItem: Sendable, Equatable {
    public let app: AppID
    public let slot: Slot
    public let title: String?
    public let fullscreen: Bool
}

public enum BrowserWindowMode: String, Decodable, Sendable {
    case separate
    case shared
}

public struct BrowserItem: Sendable, Equatable {
    public let app: AppID
    public let window: BrowserWindowMode
    public let slot: Slot?
    public let tabs: [String]
}

extension ItemConfig: Decodable {
    private enum Keys: String, CodingKey {
        case type, app, slot, tabs, window, title, fullscreen
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        let type = try container.decode(String.self, forKey: .type)
        let app = try container.decode(AppID.self, forKey: .app)

        switch type {
        case "app":
            let slot = try container.decodeIfPresent(Slot.self, forKey: .slot) ?? .full
            let title = try container.decodeIfPresent(String.self, forKey: .title)
            let fullscreen = try container.decodeIfPresent(Bool.self, forKey: .fullscreen) ?? false
            self = .app(AppItem(app: app, slot: slot, title: title, fullscreen: fullscreen))
        case "browser":
            let tabs = try container.decodeIfPresent([String].self, forKey: .tabs) ?? []
            let window = try container.decodeIfPresent(
                BrowserWindowMode.self, forKey: .window) ?? .separate
            let slot = try container.decodeIfPresent(Slot.self, forKey: .slot)
            self = .browser(BrowserItem(app: app, window: window, slot: slot, tabs: tabs))
        default:
            throw ConfigError.unknownItemType(type)
        }
    }
}

extension AppID: Decodable {}
extension Slot: Decodable {}

extension DisplaySelector {
    public var yamlValue: String {
        switch self {
        case .builtin: return "builtin"
        case .any: return "any"
        case .external(let index): return "\(Self.externalPrefix)\(index)"
        }
    }
}
