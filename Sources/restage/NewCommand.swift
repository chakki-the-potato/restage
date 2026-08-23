import Foundation
import RestageKit
import RestageKitDarwin

/// 현재 창 배치를 읽어 워크스페이스 config를 만든다.
///
/// 폼을 채우게 하지 않고 이미 만들어둔 배치에서 출발하는 이유는, 창을 끌어다 놓는 일은
/// 누구나 이미 할 줄 알기 때문이다. 대신 분류가 애매하면 반드시 되묻는다.
@MainActor
enum NewCommand {
    private struct Position {
        let screen: Int
        let item: Int
    }

    static func run(name: String) -> Int32 {
        if let reason = WorkspaceName.validate(name) {
            print(reason)
            return 2
        }
        guard AccessibilityPermission.isTrusted() else {
            print(AccessibilityPermission.onboardingMessage)
            return 1
        }
        guard !ScreenLock.isLocked() else {
            print(ScreenLock.message)
            return 1
        }
        guard let displays = DisplayCatalog.current() else {
            print("디스플레이 정보를 조회할 수 없습니다")
            return 1
        }

        let captured: WorkspaceCapture.Result
        do {
            captured = try WorkspaceCapture.capture(name: name, displays: displays)
        } catch {
            print("창 목록을 읽지 못했습니다: \(error)")
            return 1
        }

        var draft = captured.draft
        printIntro(captured)
        return edit(&draft)
    }

    private static func printIntro(_ captured: WorkspaceCapture.Result) {
        print("현재 창 배치를 읽었습니다.")
        print("다른 Space에 있거나 전체화면인 창은 보이지 않습니다.")
        for skipped in captured.browsersWithoutTabs {
            print("\(skipped.app)의 탭을 읽지 못해 창 위치만 담았습니다: \(skipped.reason)")
        }
    }

    // MARK: - 편집 루프

    private static func edit(_ draft: inout WorkspaceDraft) -> Int32 {
        while true {
            print("")
            print(render(draft))
            print("[Enter] 저장   [숫자] 자리 바꾸기   [-숫자] 제외   [+] 앱 추가"
                + "   [w] 웹 추가   [q] 취소")

            guard let raw = Console.ask("> ") else {
                print("입력이 끝나 취소했습니다. 저장하려면 빈 줄을 입력하세요")
                return 1
            }
            let command = raw.trimmingCharacters(in: .whitespaces)

            switch command {
            case "":
                return save(draft)
            case "q":
                print("취소했습니다")
                return 1
            case "+":
                addApp(&draft)
            case "w":
                addWeb(&draft)
            default:
                apply(command, to: &draft)
            }
        }
    }

    private static func apply(_ command: String, to draft: inout WorkspaceDraft) {
        if command.hasPrefix("-"), let number = Int(command.dropFirst()) {
            guard let position = position(number, in: draft) else { return warnRange(number) }
            let removed = draft.screens[position.screen].items.remove(at: position.item)
            if draft.screens[position.screen].items.isEmpty {
                draft.screens.remove(at: position.screen)
            }
            print("제외했습니다: \(removed.app)")
            return
        }
        guard let number = Int(command) else {
            print("모르는 입력입니다: \(command)")
            return
        }
        guard let position = position(number, in: draft) else { return warnRange(number) }
        changeSlot(at: position, in: &draft)
    }

    private static func changeSlot(at position: Position, in draft: inout WorkspaceDraft) {
        let item = draft.screens[position.screen].items[position.item]
        print("\(item.app)의 자리를 고르세요.")
        print(SlotLabel.picker())
        guard let raw = Console.ask("자리 번호> "),
              let choice = Int(raw.trimmingCharacters(in: .whitespaces)),
              let slot = SlotLabel.slot(atChoice: choice) else {
            print("자리를 바꾸지 않았습니다")
            return
        }
        draft.screens[position.screen].items[position.item].slot = slot
        draft.screens[position.screen].items[position.item].overlap = nil
        print("\(item.app) → \(SlotLabel.text(slot))")
    }

    // MARK: - 항목 추가

    private static func addApp(_ draft: inout WorkspaceDraft) {
        guard let name = askInstalledApp("앱 이름> ") else { return }
        guard let slot = askSlot(for: name) else { return }
        guard let screen = askScreen(in: &draft) else { return }
        draft.screens[screen].items.append(.app(name, slot: slot))
        print("추가했습니다: \(name) \(SlotLabel.text(slot))")
    }

    private static func addWeb(_ draft: inout WorkspaceDraft) {
        guard let name = askInstalledApp("브라우저 이름> ") else { return }
        print("URL을 한 줄에 하나씩 입력하세요. 빈 줄이면 끝냅니다.")
        var tabs: [String] = []
        while let line = Console.ask("url> ") {
            let url = line.trimmingCharacters(in: .whitespaces)
            if url.isEmpty { break }
            tabs.append(url)
        }
        guard !tabs.isEmpty else {
            print("URL이 없어 추가하지 않았습니다")
            return
        }
        guard let screen = askScreen(in: &draft) else { return }
        let slot = askOptionalSlot(for: name)
        draft.screens[screen].items.append(.browser(name, slot: slot, tabs: tabs))
        print("추가했습니다: \(name) 탭 \(tabs.count)개")
    }

    /// 설치된 앱 이름을 받아 표시 이름으로 정규화한다. 못 찾으면 사유를 보여주고 nil이다.
    private static func askInstalledApp(_ prompt: String) -> String? {
        guard let raw = Console.ask(prompt) else { return nil }
        let typed = raw.trimmingCharacters(in: .whitespaces)
        guard !typed.isEmpty else { return nil }
        do {
            let bundleID = try InstalledApps.resolve(name: typed)
            return InstalledApps.displayName(bundleID: bundleID) ?? typed
        } catch {
            print(error)
            return nil
        }
    }

    private static func askSlot(for app: String) -> Slot? {
        print("\(app)의 자리를 고르세요.")
        print(SlotLabel.picker())
        guard let raw = Console.ask("자리 번호> "),
              let choice = Int(raw.trimmingCharacters(in: .whitespaces)),
              let slot = SlotLabel.slot(atChoice: choice) else {
            print("자리를 고르지 않아 추가하지 않았습니다")
            return nil
        }
        return slot
    }

    /// 브라우저는 자리를 비워둘 수 있다. 비우면 창 크기를 건드리지 않는다.
    private static func askOptionalSlot(for app: String) -> Slot? {
        print("\(app)의 자리를 고르세요. 그냥 Enter를 누르면 창 크기를 건드리지 않습니다.")
        print(SlotLabel.picker())
        guard let raw = Console.ask("자리 번호> "),
              let choice = Int(raw.trimmingCharacters(in: .whitespaces)) else { return nil }
        return SlotLabel.slot(atChoice: choice)
    }

    /// 화면이 하나면 묻지 않는다. 화면이 아예 없으면 주 디스플레이로 하나 만든다.
    private static func askScreen(in draft: inout WorkspaceDraft) -> Int? {
        if draft.screens.isEmpty {
            draft.screens.append(ScreenDraft(id: "main", display: .builtin, items: []))
            return 0
        }
        if draft.screens.count == 1 { return 0 }

        print("어느 화면인가요?")
        for (index, screen) in draft.screens.enumerated() {
            print("  \(index + 1) \(screen.id)")
        }
        guard let raw = Console.ask("화면 번호> "),
              let choice = Int(raw.trimmingCharacters(in: .whitespaces)),
              draft.screens.indices.contains(choice - 1) else {
            print("화면을 고르지 않아 추가하지 않았습니다")
            return nil
        }
        return choice - 1
    }

    // MARK: - 표시

    private static func render(_ draft: WorkspaceDraft) -> String {
        guard draft.itemCount > 0 else {
            return "담긴 항목이 없습니다. [+]로 앱을, [w]로 웹을 추가하세요."
        }
        var lines = DraftSummary.lines(draft, numbered: true)
        if DraftSummary.hasUncertainItem(draft) {
            lines.append("")
            lines.append("  \(DraftSummary.uncertaintyNote) 번호를 눌러 직접 고르세요.")
        }
        return lines.joined(separator: "\n")
    }

    private static func warnRange(_ number: Int) {
        print("\(number)번 항목이 없습니다")
    }

    private static func position(_ number: Int, in draft: WorkspaceDraft) -> Position? {
        var remaining = number - 1
        guard remaining >= 0 else { return nil }
        for (screenIndex, screen) in draft.screens.enumerated() {
            if remaining < screen.items.count {
                return Position(screen: screenIndex, item: remaining)
            }
            remaining -= screen.items.count
        }
        return nil
    }

    // MARK: - 저장

    private static func save(_ draft: WorkspaceDraft) -> Int32 {
        guard draft.itemCount > 0 else {
            print("담긴 항목이 없어 저장하지 않았습니다")
            return 1
        }
        let path = "\(WorkspaceRegistry.defaultDirectory)/\(draft.name).yaml"

        if FileManager.default.fileExists(atPath: path) {
            guard Console.confirm("\(path)가 이미 있습니다. 덮어쓸까요?") else {
                print("저장하지 않았습니다")
                return 1
            }
        }

        // 저장 뒤 다시 읽어 실제로 열리는지 확인한다. 확인 없이 성공을 알리지 않는다.
        if let reason = WorkspaceFiles.save(draft) {
            print(reason)
            return 1
        }

        print("저장했습니다: \(path)")
        print("실행하려면: restage open \(draft.name)")
        return 0
    }

}

extension String {
    /// 목록을 세로로 맞추기 위한 자리 채움. 한글은 폭이 넓어 글자 수로만 맞추면 어긋나므로
    /// 한글과 한자를 두 칸으로 센다.
    func padded(to width: Int) -> String {
        let displayWidth = reduce(0) { $0 + ($1.isWideInTerminal ? 2 : 1) }
        guard displayWidth < width else { return self + " " }
        return self + String(repeating: " ", count: width - displayWidth)
    }
}

extension Character {
    var isWideInTerminal: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        switch scalar.value {
        case 0x1100...0x115F, 0x2E80...0xA4CF, 0xAC00...0xD7A3,
             0xF900...0xFAFF, 0xFE30...0xFE6F, 0xFF00...0xFF60, 0xFFE0...0xFFE6:
            return true
        default:
            return false
        }
    }
}
