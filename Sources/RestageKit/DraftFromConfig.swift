/// 저장된 config를 편집용 초안으로 되돌린다.
///
/// 기존 워크스페이스를 고칠 때 필요하다. 새로 만들 때는 창을 읽어 초안을 만들지만,
/// 편집은 이미 저장된 내용에서 출발해야 한다. 그러지 않으면 편집이 곧 재캡처가 되어
/// 사용자가 손으로 맞춰둔 자리가 날아간다.
public enum DraftFromConfig {
    public static func draft(from config: WorkspaceConfig) -> WorkspaceDraft {
        WorkspaceDraft(
            name: config.workspace,
            hotkey: config.hotkey,
            screens: config.screens.map { screen in
                ScreenDraft(
                    id: screen.id,
                    display: screen.display,
                    items: screen.items.map(item(from:)))
            })
    }

    /// 저장된 항목은 사용자가 이미 정한 값이므로 확신도를 붙이지 않는다.
    /// 물음표가 뜨면 자기가 고른 자리를 도구가 의심하는 것처럼 보인다.
    private static func item(from config: ItemConfig) -> ItemDraft {
        switch config {
        case .app(let app):
            return ItemDraft(
                app: app.app.rawValue, slot: app.slot, kind: .app(title: app.title),
                fullscreen: app.fullscreen)
        case .browser(let browser):
            return ItemDraft(
                app: browser.app.rawValue, slot: browser.slot,
                kind: .browser(tabs: browser.tabs))
        }
    }
}
