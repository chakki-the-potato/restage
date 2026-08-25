import Foundation

public struct WorkspaceEntry: Sendable {
    public let name: String
    public let path: String
    public let summary: WorkspaceSummary?
    public let error: String?

    public init(
        name: String, path: String, summary: WorkspaceSummary?, error: String?
    ) {
        self.name = name
        self.path = path
        self.summary = summary
        self.error = error
    }
}

public struct WorkspaceRegistry {
    public static let defaultDirectory =
        NSHomeDirectory() + "/.config/restage"

    private static let extensions = ["yaml", "yml"]

    private let directory: String

    public init(directory: String = WorkspaceRegistry.defaultDirectory) {
        self.directory = directory
    }

    public func resolve(_ argument: String) throws -> String {
        if looksLikePath(argument) {
            return (argument as NSString).expandingTildeInPath
        }

        guard FileManager.default.fileExists(atPath: directory) else {
            throw ConfigError.directoryNotFound(path: directory)
        }

        for ext in Self.extensions {
            let candidate = "\(directory)/\(argument).\(ext)"
            if FileManager.default.fileExists(atPath: candidate) { return candidate }
        }

        let available = (try? list().map(\.name)) ?? []
        throw ConfigError.workspaceNotFound(
            name: argument,
            path: "\(directory)/\(argument).\(Self.extensions[0])",
            available: available)
    }

    public func list() throws -> [WorkspaceEntry] {
        guard FileManager.default.fileExists(atPath: directory) else {
            throw ConfigError.directoryNotFound(path: directory)
        }
        let names = try FileManager.default.contentsOfDirectory(atPath: directory)

        return names
            .filter { Self.extensions.contains(($0 as NSString).pathExtension.lowercased()) }
            .sorted()
            .map { fileName in
                let path = "\(directory)/\(fileName)"
                let name = (fileName as NSString).deletingPathExtension
                do {
                    let config = try ConfigLoader.load(path: path)
                    return WorkspaceEntry(
                        name: name, path: path,
                        summary: WorkspaceSummary(config: config), error: nil)
                } catch {
                    return WorkspaceEntry(
                        name: name, path: path, summary: nil,
                        error: String(describing: error))
                }
            }
    }

    private func looksLikePath(_ argument: String) -> Bool {
        if argument.contains("/") { return true }
        return Self.extensions.contains((argument as NSString).pathExtension.lowercased())
    }
}
