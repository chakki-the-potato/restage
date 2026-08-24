import AppKit

/// 메뉴에서 띄우는 알림 창. AppKit 호출을 한곳에 모아 화면을 부르는 쪽이 흩어지지 않게 한다.
@MainActor
enum Prompt {
    static func message(_ title: String, _ body: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.alertStyle = .warning
        alert.runModal()
    }

    /// 되돌릴 수 없는 동작 앞에서 확인을 받는다. 기본 선택은 항상 취소다.
    static func confirmDestructive(
        title: String, body: String, confirmTitle: String
    ) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.alertStyle = .warning
        let confirm = alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: "취소")
        confirm.hasDestructiveAction = true
        alert.window.defaultButtonCell = nil
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// 한 줄을 입력받는다. 취소하면 nil이다.
    static func text(
        title: String, body: String, initial: String = "", confirmTitle: String = "확인"
    ) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: "취소")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = initial
        field.placeholderString = "이름"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return field.stringValue
    }

    /// 임의의 뷰를 붙인 확인 창. 체크박스 목록처럼 고를 것이 있을 때 쓴다.
    static func confirm(
        title: String, body: String, accessory: NSView, confirmTitle: String
    ) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: "취소")
        alert.accessoryView = accessory
        return alert.runModal() == .alertFirstButtonReturn
    }

}
