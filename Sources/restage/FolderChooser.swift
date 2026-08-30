import AppKit
import RestageKit

@MainActor
enum FolderChooser {
    static func choose(startingAt current: String?) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = L10n.string("common.choose")
        if let current {
            panel.directoryURL = URL(fileURLWithPath: (current as NSString).expandingTildeInPath)
        }
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return (url.path as NSString).abbreviatingWithTildeInPath
    }

    static func label(_ path: String?) -> String {
        guard let path, !path.isEmpty else { return L10n.string("draft.folder_none") }
        return (path as NSString).lastPathComponent
    }
}
