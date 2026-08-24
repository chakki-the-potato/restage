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
        title: String, body: String, confirmTitle: String, destructive: Bool = true
    ) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.alertStyle = .warning
        let confirm = alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: "취소")
        if destructive {
            confirm.hasDestructiveAction = true
            alert.window.defaultButtonCell = nil
        }
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

    enum Choice {
        case confirmed
        case alternate
        case cancelled
    }

    /// 임의의 뷰를 붙인 확인 창. 체크박스 목록처럼 고를 것이 있을 때 쓴다.
    ///
    /// `alternateTitle`을 주면 버튼이 셋이 된다. 저장도 취소도 아닌 제3의 선택을 위한 것이다.
    static func confirm(
        title: String, body: String, accessory: NSView, confirmTitle: String,
        alternateTitle: String? = nil
    ) -> Choice {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.addButton(withTitle: confirmTitle)
        if let alternateTitle { alert.addButton(withTitle: alternateTitle) }
        alert.addButton(withTitle: "취소")
        alert.accessoryView = accessory

        switch alert.runModal() {
        case .alertFirstButtonReturn: return .confirmed
        case .alertSecondButtonReturn: return alternateTitle == nil ? .cancelled : .alternate
        default: return .cancelled
        }
    }

}
