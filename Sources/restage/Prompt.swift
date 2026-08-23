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

    /// 여러 줄을 고정폭으로 보여주고 저장 여부를 묻는다.
    ///
    /// 목록을 `informativeText`에 그대로 넣지 않는 이유는 비례 글꼴이라 자리 이름이 세로로
    /// 어긋나기 때문이다. 무엇이 어느 자리에 가는지 한눈에 보이지 않으면 확인하는 의미가 없다.
    static func confirmList(
        title: String, body: String, lines: [String], footer: String?, confirmTitle: String
    ) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = footer.map { "\(body)\n\n\($0)" } ?? body
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: "취소")
        alert.accessoryView = monospacedBox(lines)
        return alert.runModal() == .alertFirstButtonReturn
    }

    private static func monospacedBox(_ lines: [String]) -> NSView {
        let text = NSTextField(labelWithString: lines.joined(separator: "\n"))
        text.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        text.lineBreakMode = .byClipping
        text.sizeToFit()

        let width = max(text.frame.width, 260)
        let height = min(text.frame.height, 260)
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        scroll.hasVerticalScroller = text.frame.height > height
        scroll.drawsBackground = false
        text.frame = NSRect(x: 0, y: 0, width: width, height: text.frame.height)
        scroll.documentView = text
        return scroll
    }
}
