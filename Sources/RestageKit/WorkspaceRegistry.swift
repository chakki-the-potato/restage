import Foundation

public struct WorkspaceEntry: Sendable {
    public let name: String
    public let path: String
    /// 파싱에 실패하면 nil이다.
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

/// 이름으로 워크스페이스 config를 찾는다.
///
/// 디렉토리를 주입받는 이유는 단위 테스트가 사용자 홈 디렉토리를 건드리지 않게 하기 위해서다.
public struct WorkspaceRegistry {
    public static let defaultDirectory =
        NSHomeDirectory() + "/.config/restage"

    private static let extensions = ["yaml", "yml"]

    private let directory: String

    public init(directory: String = WorkspaceRegistry.defaultDirectory) {
        self.directory = directory
    }

    /// 인자를 이름 또는 경로로 해석해 실제 파일 경로를 돌려준다.
    ///
    /// `/`를 포함하거나 yaml 확장자로 끝나면 경로로 본다. 그래야 기존
    /// `restage open examples/dev.yaml` 사용법이 그대로 동작한다.
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

    /// 디렉토리의 워크스페이스 목록. 파싱에 실패한 것도 오류와 함께 남긴다.
    ///
    /// 목록에서 빼면 사용자는 파일이 없는 줄 알고 엉뚱한 곳을 찾는다.
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
