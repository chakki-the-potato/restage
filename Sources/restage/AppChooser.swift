import AppKit
import RestageKit
import RestageKitDarwin
import UniformTypeIdentifiers

@MainActor
enum AppChooser {
    static let suggestionLimit = 6

    private static let applicationsDirectory = "/Applications"

    static func suggestions(for query: String, browsersOnly: Bool) -> [InstalledApp] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return [] }
        return InstalledApps.all()
            .filter { $0.name.lowercased().contains(needle)
                || $0.fileName.lowercased().contains(needle) }
            .filter { !browsersOnly || InstalledApps.isBrowser(bundleID: $0.bundleID) }
            .prefix(suggestionLimit)
            .map { $0 }
    }

    static func chooseFile() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: applicationsDirectory)
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return name(ofBundleAt: url)
    }

    static func appName(fromPath path: String) -> String? {
        let trimmed = path.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasSuffix(".app") || trimmed.contains("/") else { return nil }
        let candidates = trimmed.hasPrefix("/") ? [trimmed] : [trimmed, "/" + trimmed]
        for candidate in candidates {
            if let name = name(ofBundleAt: URL(fileURLWithPath: candidate)) { return name }
        }
        return nil
    }

    static func name(ofBundleAt url: URL) -> String? {
        guard url.pathExtension.lowercased() == "app",
              let bundleID = Bundle(url: url)?.bundleIdentifier else { return nil }
        return InstalledApps.displayName(bundleID: bundleID)
            ?? url.deletingPathExtension().lastPathComponent
    }

    static func acceptDrop(
        _ providers: [NSItemProvider], add: @escaping @MainActor @Sendable (String) -> Void
    ) -> Bool {
        let identifier = UTType.fileURL.identifier
        var accepted = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(identifier) {
            accepted = true
            provider.loadDataRepresentation(forTypeIdentifier: identifier) { data, _ in
                guard let data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in
                    guard let name = name(ofBundleAt: url) else { return }
                    add(name)
                }
            }
        }
        return accepted
    }
}
