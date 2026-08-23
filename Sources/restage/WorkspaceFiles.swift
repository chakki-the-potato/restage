import AppKit
import RestageKit

/// 워크스페이스 config 파일을 다루는 동작.
///
/// 메뉴가 파일을 직접 만지지 않게 여기로 모은다. 삭제와 이름 바꾸기는 되돌릴 수 없는
/// 동작이라 실패 사유를 반드시 돌려준다.
@MainActor
enum WorkspaceFiles {
    /// 성공하면 nil, 실패하면 사용자에게 보여줄 사유.
    typealias Failure = String?

    static func path(for name: String) -> String? {
        try? WorkspaceRegistry().resolve(name)
    }

    /// 휴지통으로 보낸다. 지우지 않는 이유는 사용자가 되돌릴 수 있어야 하기 때문이다.
    /// 손으로 쓴 config가 며칠치 작업일 수 있다.
    static func moveToTrash(_ name: String) -> Failure {
        guard let path = path(for: name) else {
            return "'\(name)' 파일을 찾을 수 없습니다"
        }
        do {
            try FileManager.default.trashItem(
                at: URL(fileURLWithPath: path), resultingItemURL: nil)
            return nil
        } catch {
            return "휴지통으로 보내지 못했습니다: \(error.localizedDescription)"
        }
    }

    static func rename(_ name: String, to newName: String) -> Failure {
        if let reason = WorkspaceName.validate(newName) { return reason }
        let target = WorkspaceName.normalize(newName)
        guard target != name else { return nil }

        guard let source = path(for: name) else {
            return "'\(name)' 파일을 찾을 수 없습니다"
        }
        let directory = (source as NSString).deletingLastPathComponent
        let extensionName = (source as NSString).pathExtension
        let destination = "\(directory)/\(target).\(extensionName)"

        guard !FileManager.default.fileExists(atPath: destination) else {
            return "'\(target)'이라는 워크스페이스가 이미 있습니다"
        }
        do {
            try FileManager.default.moveItem(atPath: source, toPath: destination)
            return nil
        } catch {
            return "이름을 바꾸지 못했습니다: \(error.localizedDescription)"
        }
    }

    /// 기본 편집기로 연다. 확장자 연결이 없으면 TextEdit으로 넘어간다.
    static func openInEditor(_ name: String) -> Failure {
        guard let path = path(for: name) else {
            return "'\(name)' 파일을 찾을 수 없습니다"
        }
        return NSWorkspace.shared.open(URL(fileURLWithPath: path))
            ? nil : "편집기를 열지 못했습니다"
    }

    static func revealInFinder(_ name: String) -> Failure {
        guard let path = path(for: name) else {
            return "'\(name)' 파일을 찾을 수 없습니다"
        }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        return nil
    }

    static func revealConfigFolder() {
        let directory = WorkspaceRegistry.defaultDirectory
        try? FileManager.default.createDirectory(
            atPath: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(URL(fileURLWithPath: directory))
    }

    static func exists(_ name: String) -> Bool {
        path(for: name) != nil
    }

    /// 초안을 저장한다. 저장 뒤 다시 읽어 실제로 열리는지 확인한다.
    static func save(_ draft: WorkspaceDraft) -> Failure {
        let directory = WorkspaceRegistry.defaultDirectory
        let path = "\(directory)/\(draft.name).yaml"
        do {
            try FileManager.default.createDirectory(
                atPath: directory, withIntermediateDirectories: true)
            try ConfigWriter.yaml(for: draft).write(
                toFile: path, atomically: true, encoding: .utf8)
        } catch {
            return "저장하지 못했습니다: \(error.localizedDescription)"
        }
        do {
            _ = try ConfigLoader.load(path: path)
            return nil
        } catch {
            return "저장은 됐지만 다시 읽지 못했습니다. 파일을 확인하세요: \(path)\n\(error)"
        }
    }
}
