import AppKit
import RestageKit

@MainActor
enum Prompt {
    static func message(_ title: String, _ body: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.alertStyle = .warning
        alert.runModal()
    }

    static func confirmDestructive(
        title: String, body: String, confirmTitle: String, destructive: Bool = true
    ) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.alertStyle = .warning
        let confirm = alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: L10n.string("common.cancel"))
        if destructive {
            confirm.hasDestructiveAction = true
            alert.window.defaultButtonCell = nil
        }
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func text(
        title: String, body: String, initial: String = "", confirmTitle: String = L10n.string("common.ok")
    ) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: L10n.string("common.cancel"))

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = initial
        field.placeholderString = L10n.string("common.name")
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return field.stringValue
    }

    enum Choice {
        case confirmed
        case alternate
        case cancelled
    }

    static func confirm(
        title: String, body: String, accessory: NSView, confirmTitle: String,
        alternateTitle: String? = nil
    ) -> Choice {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.addButton(withTitle: confirmTitle)
        if let alternateTitle { alert.addButton(withTitle: alternateTitle) }
        alert.addButton(withTitle: L10n.string("common.cancel"))
        alert.accessoryView = accessory

        switch alert.runModal() {
        case .alertFirstButtonReturn: return .confirmed
        case .alertSecondButtonReturn: return alternateTitle == nil ? .cancelled : .alternate
        default: return .cancelled
        }
    }

}
