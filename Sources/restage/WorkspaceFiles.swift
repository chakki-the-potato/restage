import AppKit
import RestageKit

@MainActor
enum WorkspaceFiles {
    typealias Failure = String?

    static func path(for name: String) -> String? {
        try? WorkspaceRegistry().resolve(name)
    }

    static func moveToTrash(_ name: String) -> Failure {
        guard let path = path(for: name) else {
            return L10n.string("error.file.not_found", name)
        }
        do {
            try FileManager.default.trashItem(
                at: URL(fileURLWithPath: path), resultingItemURL: nil)
            return nil
        } catch {
            return L10n.string("error.file.trash_failed", error.localizedDescription)
        }
    }

    static func rename(_ name: String, to newName: String) -> Failure {
        if let reason = WorkspaceName.validate(newName) { return reason }
        let target = WorkspaceName.normalize(newName)
        guard target != name else { return nil }

        guard let source = path(for: name) else {
            return L10n.string("error.file.not_found", name)
        }
        let directory = (source as NSString).deletingLastPathComponent
        let extensionName = (source as NSString).pathExtension
        let destination = "\(directory)/\(target).\(extensionName)"

        guard !FileManager.default.fileExists(atPath: destination) else {
            return L10n.string("error.file.name_taken", target)
        }
        do {
            try FileManager.default.moveItem(atPath: source, toPath: destination)
            return nil
        } catch {
            return L10n.string("error.file.rename_failed", error.localizedDescription)
        }
    }

    static func revealInFinder(_ name: String) -> Failure {
        guard let path = path(for: name) else {
            return L10n.string("error.file.not_found", name)
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

    static func setHotkey(_ hotkey: String?, for name: String) -> Failure {
        guard let path = path(for: name) else {
            return L10n.string("error.file.not_found", name)
        }
        do {
            let original = try String(contentsOfFile: path, encoding: .utf8)
            let updated = HotkeyLine.apply(hotkey, to: original)
            guard updated != original else { return nil }
            try updated.write(toFile: path, atomically: true, encoding: .utf8)
            return nil
        } catch {
            return L10n.string("error.file.hotkey_save_failed", error.localizedDescription)
        }
    }

    static func exists(_ name: String) -> Bool {
        path(for: name) != nil
    }

    static func save(_ draft: WorkspaceDraft) -> Failure {
        let directory = WorkspaceRegistry.defaultDirectory
        let path = "\(directory)/\(draft.name).yaml"
        do {
            try FileManager.default.createDirectory(
                atPath: directory, withIntermediateDirectories: true)
            try ConfigWriter.yaml(for: draft).write(
                toFile: path, atomically: true, encoding: .utf8)
        } catch {
            return L10n.string("error.file.save_failed", error.localizedDescription)
        }
        do {
            _ = try ConfigLoader.load(path: path)
            return nil
        } catch {
            return L10n.string("error.file.saved_but_unreadable", path, "\(error)")
        }
    }
}
