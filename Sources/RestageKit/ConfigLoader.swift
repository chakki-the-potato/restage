import Foundation

public enum ConfigLoader {
    public static func load(path: String) throws -> WorkspaceConfig {
        guard FileManager.default.fileExists(atPath: path) else {
            throw ConfigError.fileNotFound(path: path)
        }
        let text: String
        do {
            text = try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            throw ConfigError.unreadable(path: path, underlying: error.localizedDescription)
        }
        return try validated(WorkspaceConfig.decode(yaml: text))
    }

    /// 스키마 디코딩이 잡지 못하는 의미 규칙을 검사한다.
    public static func validated(_ config: WorkspaceConfig) throws -> WorkspaceConfig {
        guard !config.screens.isEmpty else { throw ConfigError.emptyScreens }

        var seenIDs = Set<String>()
        for screen in config.screens {
            guard seenIDs.insert(screen.id).inserted else {
                throw ConfigError.duplicateScreenID(screen.id)
            }
            guard !screen.items.isEmpty else {
                throw ConfigError.emptyItems(screenID: screen.id)
            }
            if let anchor = screen.anchor {
                let declared = screen.items.map(\.appID)
                guard declared.contains(anchor) else {
                    throw ConfigError.anchorNotInItems(screenID: screen.id, anchor: anchor)
                }
            }
        }
        return config
    }
}
