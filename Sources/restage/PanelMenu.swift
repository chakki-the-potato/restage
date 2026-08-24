import AppKit

/// 패널에서 띄우는 macOS 메뉴.
///
/// SwiftUI로 흉내 내지 않고 진짜 `NSMenu`를 쓰는 이유는 패널 밖으로 떠올라야 하기
/// 때문이다. 패널 안에 그리면 아래쪽에서 잘리거나, 잘리지 않게 패널을 늘려야 해서
/// 목록이 밀린다. 시스템 메뉴는 창 경계와 무관하게 뜬다.
///
/// 대신 메뉴가 열려 있는 동안 클릭을 독차지하는 문제가 따라온다. 화면 다른 곳을 눌러도
/// 메뉴만 닫히고 패널이 남는다. 그래서 항목을 고르지 않고 닫혔으면 바깥을 누른 것으로
/// 보고 패널까지 닫는다.
@MainActor
final class PanelMenu: NSObject, NSMenuDelegate {
    struct Item {
        let title: String
        let symbol: String
        var isChecked = false
        var isDestructive = false
        /// true면 고른 뒤에도 패널을 닫지 않는다. 켜고 끄는 항목에 쓴다.
        var keepsPanelOpen = false
        let action: () -> Void
    }

    /// 항목을 고르지 않고 닫혔을 때. 바깥을 누른 것으로 본다.
    private var onDismissWithoutSelection: (() -> Void)?
    private var didSelect = false
    private var menu: NSMenu?
    /// 메뉴가 떠 있는 동안 true. 우리 메뉴가 키를 가져가는 것을 바깥 전환으로 오해하면
    /// 메뉴를 여는 순간 패널이 닫힌다.
    private(set) var isShowing = false

    /// 화면 좌표 한 점에서 메뉴를 연다. 그 점이 메뉴의 왼쪽 위가 된다.
    func show(
        items: [Item], at screenPoint: CGPoint, onDismissWithoutSelection: @escaping () -> Void
    ) {
        self.onDismissWithoutSelection = onDismissWithoutSelection
        didSelect = false

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        for item in items {
            menu.addItem(menuItem(for: item))
        }
        self.menu = menu
        isShowing = true
        menu.popUp(positioning: nil, at: screenPoint, in: nil)
    }

    /// 제목이 비면 구분선으로 만든다.
    static func separator() -> Item {
        Item(title: "", symbol: "", action: {})
    }

    private func menuItem(for item: Item) -> NSMenuItem {
        guard !item.title.isEmpty else { return .separator() }

        let entry = NSMenuItem(title: item.title, action: #selector(fire(_:)), keyEquivalent: "")
        entry.target = self
        entry.representedObject = Payload(item: item)
        entry.state = item.isChecked ? .on : .off
        if !item.symbol.isEmpty {
            entry.image = NSImage(systemSymbolName: item.symbol, accessibilityDescription: nil)
        }
        if item.isDestructive {
            entry.attributedTitle = NSAttributedString(
                string: item.title,
                attributes: [.foregroundColor: NSColor.systemRed])
        }
        return entry
    }

    private final class Payload: NSObject {
        let item: Item
        init(item: Item) { self.item = item }
    }

    @objc private func fire(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? Payload else { return }
        didSelect = true
        if payload.item.keepsPanelOpen {
            onDismissWithoutSelection = nil
        }
        payload.item.action()
    }

    func menuDidClose(_ menu: NSMenu) {
        isShowing = false
        guard !didSelect else { return }
        // 항목을 고르지 않고 닫혔다. 어디를 눌렀는지는 호출자가 판단한다.
        // 지연 없이 부른다. 한 박자 뒤에 패널이 닫히면 메뉴와 따로 노는 것처럼 보인다.
        let dismiss = onDismissWithoutSelection
        onDismissWithoutSelection = nil
        dismiss?()
    }
}
