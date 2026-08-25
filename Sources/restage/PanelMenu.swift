import AppKit

@MainActor
final class PanelMenu: NSObject, NSMenuDelegate {
    struct Item {
        let title: String
        let symbol: String
        var isChecked = false
        var isDestructive = false
        var isHeader = false
        var keepsPanelOpen = false
        let action: () -> Void
    }

    private var onDismissWithoutSelection: (() -> Void)?
    private var didSelect = false
    private var menu: NSMenu?
    private(set) var isShowing = false

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

    static func separator() -> Item {
        Item(title: "", symbol: "", action: {})
    }

    static func header(_ title: String) -> Item {
        Item(title: title, symbol: "", isHeader: true, action: {})
    }

    private func menuItem(for item: Item) -> NSMenuItem {
        guard !item.title.isEmpty else { return .separator() }
        if item.isHeader { return header(item.title) }

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

    private func header(_ title: String) -> NSMenuItem {
        if #available(macOS 14.0, *) { return .sectionHeader(title: title) }
        let entry = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        entry.isEnabled = false
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
        let dismiss = onDismissWithoutSelection
        onDismissWithoutSelection = nil
        dismiss?()
    }
}
