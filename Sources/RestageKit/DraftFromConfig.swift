public enum DraftFromConfig {
    public static func draft(from config: WorkspaceConfig) -> WorkspaceDraft {
        WorkspaceDraft(
            name: config.workspace,
            hotkey: config.hotkey,
            hideOthers: config.hideOthers,
            screens: config.screens.map { screen in
                ScreenDraft(
                    id: screen.id,
                    display: screen.display,
                    items: screen.items.map(item(from:)))
            })
    }

    private static func item(from config: ItemConfig) -> ItemDraft {
        switch config {
        case .app(let app):
            return ItemDraft(
                app: app.app.rawValue, slot: app.slot, kind: .app(title: app.title),
                fullscreen: app.fullscreen, open: app.open)
        case .browser(let browser):
            return ItemDraft(
                app: browser.app.rawValue, slot: browser.slot,
                kind: .browser(tabs: browser.tabs), fullscreen: browser.fullscreen)
        }
    }
}
