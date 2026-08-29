import RestageKit
import RestageKitDarwin

enum HideOthers {
    @MainActor
    static func run(_ config: WorkspaceConfig, _ resolved: ResolvedWorkspace) async -> [String] {
        guard config.hideOthers else { return [] }
        return await OtherAppsHider.hide(keeping: resolved.screens.flatMap { $0.items.map(\.app) })
    }

    static func note(_ hidden: [String]) -> String? {
        guard !hidden.isEmpty else { return nil }
        return L10n.string("outcome.hid_others", hidden.count, hidden.joined(separator: ", "))
    }
}
