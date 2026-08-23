import AppKit
import RestageKit

/// 메뉴에서 고를 수 있는 동작들. AppKit이 셀렉터를 요구하므로 대상과 함께 넘긴다.
@MainActor
struct MenuActions {
    let target: AnyObject
    let run: Selector
    let edit: Selector
    let rename: Selector
    let reveal: Selector
    let delete: Selector
    let newWorkspace: Selector
    let toggleLogin: Selector
    let openConfigFolder: Selector
    let permission: Selector
    let quit: Selector
}

/// `NSMenu` 조립. 메뉴 구성 로직을 상태 항목 수명 관리와 분리한다.
///
/// 워크스페이스 항목에 하위 메뉴를 달지 않는다. macOS는 하위 메뉴가 붙은 항목의 액션을
/// 무시하므로, 달면 클릭 한 번으로 실행되던 것이 두 번이 된다. 실제로 겪고 되돌렸다.
/// 편집과 삭제는 따로 관리 메뉴에 둔다. 매일 쓰는 것은 실행이고 관리는 가끔이다.
@MainActor
enum WorkspaceMenu {
    private enum Symbol {
        static let workspace = "square.split.2x1"
        static let broken = "exclamationmark.triangle"
        static let permission = "exclamationmark.triangle.fill"
        static let new = "plus"
        static let manage = "slider.horizontal.3"
        static let folder = "folder"
    }

    static func build(
        into menu: NSMenu,
        entries: [MenuEntry],
        hotkeyLabel: (String) -> String?,
        hotkeyTooltip: (String) -> String?,
        isBusy: Bool,
        loginItemState: NSControl.StateValue?,
        actions: MenuActions
    ) {
        menu.removeAllItems()

        if entries.contains(.permissionNeeded) {
            menu.addItem(permissionItem(actions))
            menu.addItem(.separator())
        }

        let workspaces = entries.filter { $0 != .permissionNeeded }
        menu.addItem(sectionHeader("워크스페이스"))
        for entry in workspaces {
            menu.addItem(
                item(
                    for: entry, hotkeyLabel: hotkeyLabel, hotkeyTooltip: hotkeyTooltip,
                    isBusy: isBusy, actions: actions))
        }

        menu.addItem(.separator())
        menu.addItem(
            action("새 워크스페이스 만들기…", actions.newWorkspace, actions.target,
                   symbol: Symbol.new, enabled: !isBusy, keyEquivalent: "n"))
        if let manage = manageMenu(for: workspaces, actions: actions) {
            let item = NSMenuItem(title: "워크스페이스 관리", action: nil, keyEquivalent: "")
            item.image = symbol(Symbol.manage)
            item.submenu = manage
            menu.addItem(item)
        }

        menu.addItem(.separator())
        if let loginItemState {
            let login = NSMenuItem(
                title: "로그인 시 자동 실행", action: actions.toggleLogin, keyEquivalent: "")
            login.target = actions.target
            login.state = loginItemState
            menu.addItem(login)
        }
        menu.addItem(
            action("config 폴더 열기", actions.openConfigFolder, actions.target,
                   symbol: Symbol.folder))
        menu.addItem(action("종료", actions.quit, actions.target, keyEquivalent: "q"))
    }

    // MARK: - 워크스페이스 항목

    private static func item(
        for entry: MenuEntry,
        hotkeyLabel: (String) -> String?,
        hotkeyTooltip: (String) -> String?,
        isBusy: Bool,
        actions: MenuActions
    ) -> NSMenuItem {
        switch entry {
        case .notice(let text):
            let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
            item.isEnabled = false
            return item

        case .workspace(let name):
            let item = NSMenuItem(title: name, action: actions.run, keyEquivalent: "")
            item.target = actions.target
            item.representedObject = name
            item.image = symbol(Symbol.workspace)
            item.isEnabled = !isBusy
            if let label = hotkeyLabel(name) { item.title = "\(name)   \(label)" }
            item.toolTip = hotkeyTooltip(name)
            return item

        case .brokenWorkspace(let name, let reason):
            let item = NSMenuItem(title: name, action: nil, keyEquivalent: "")
            item.representedObject = name
            item.image = symbol(Symbol.broken)
            item.toolTip = reason
            item.isEnabled = false
            return item

        case .permissionNeeded:
            return permissionItem(actions)
        }
    }

    private static func permissionItem(_ actions: MenuActions) -> NSMenuItem {
        let item = NSMenuItem(
            title: MenuEntry.permissionNeeded.title, action: actions.permission, keyEquivalent: "")
        item.target = actions.target
        item.image = symbol(Symbol.permission)
        return item
    }

    // MARK: - 관리

    /// 워크스페이스마다 편집·이름 바꾸기·삭제를 모은다. 하나도 없으면 nil이다.
    ///
    /// 깨진 config도 넣는다. 고치거나 지우려면 오히려 깨졌을 때 더 필요하다.
    private static func manageMenu(for entries: [MenuEntry], actions: MenuActions) -> NSMenu? {
        let names: [String] = entries.compactMap { entry in
            switch entry {
            case .workspace(let name), .brokenWorkspace(let name, _): return name
            case .notice, .permissionNeeded: return nil
            }
        }
        guard !names.isEmpty else { return nil }

        let menu = NSMenu()
        for name in names {
            let item = NSMenuItem(title: name, action: nil, keyEquivalent: "")
            item.submenu = operations(for: name, actions: actions)
            menu.addItem(item)
        }
        return menu
    }

    private static func operations(for name: String, actions: MenuActions) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(operation("편집…", actions.edit, name, actions.target))
        menu.addItem(operation("이름 바꾸기…", actions.rename, name, actions.target))
        menu.addItem(operation("Finder에서 보기", actions.reveal, name, actions.target))
        menu.addItem(.separator())
        menu.addItem(operation("삭제…", actions.delete, name, actions.target))
        return menu
    }

    private static func operation(
        _ title: String, _ selector: Selector, _ name: String, _ target: AnyObject
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = target
        item.representedObject = name
        return item
    }

    // MARK: - 꾸미기

    private static func action(
        _ title: String, _ selector: Selector, _ target: AnyObject,
        symbol name: String? = nil, enabled: Bool = true, keyEquivalent: String = ""
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: keyEquivalent)
        item.target = target
        item.isEnabled = enabled
        if let name { item.image = symbol(name) }
        return item
    }

    /// 구역 제목. 전용 API는 macOS 14부터라 배포 타겟(13)에서는 비활성 항목으로 흉내 낸다.
    private static func sectionHeader(_ title: String) -> NSMenuItem {
        if #available(macOS 14.0, *) {
            return NSMenuItem.sectionHeader(title: title)
        }
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor,
            ])
        return item
    }

    private static func symbol(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }
}
