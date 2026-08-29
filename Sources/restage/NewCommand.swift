import Foundation
import RestageKit
import RestageKitDarwin

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
            print(L10n.string("error.display.unavailable"))
            return 1
        }

        let captured = WorkspaceCapture.capture(name: name, displays: displays)
        var draft = captured.draft
        printIntro(captured)
        return edit(&draft)
    }

    private static func printIntro(_ captured: WorkspaceCapture.Result) {
        print(L10n.string("new.read_layout"))
        if captured.onOtherSpaceCount > 0 {
            print(L10n.string("new.on_other_space", captured.onOtherSpaceCount))
        }
        for (app, count) in captured.byOrder.sorted(by: { $0.key < $1.key }) {
            print(L10n.string("new.by_order_windows", app, count))
        }
        for skipped in captured.browsersWithoutTabs {
            print(L10n.string("new.tabs_unreadable", "\(skipped.app)", skipped.reason))
        }
        for app in captured.browsersWithoutURLs {
            print(L10n.string("new.browser_no_urls", app))
        }
    }

    private static func edit(_ draft: inout WorkspaceDraft) -> Int32 {
        while true {
            print("")
            print(render(draft))
            print(L10n.string("new.commands"))

            guard let raw = Console.ask("> ") else {
                print(L10n.string("new.input_closed"))
                return 1
            }
            let command = raw.trimmingCharacters(in: .whitespaces)

            switch command {
            case "":
                return save(draft)
            case "q":
                print(L10n.string("common.cancelled"))
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
            print(L10n.string("new.removed", "\(removed.app)"))
            return
        }
        guard let number = Int(command) else {
            print(L10n.string("new.unknown_input", command))
            return
        }
        guard let position = position(number, in: draft) else { return warnRange(number) }
        changeSlot(at: position, in: &draft)
    }

    private static func changeSlot(at position: Position, in draft: inout WorkspaceDraft) {
        let item = draft.screens[position.screen].items[position.item]
        print(L10n.string("new.pick_slot", "\(item.app)"))
        print(SlotLabel.picker())
        guard let raw = Console.ask(L10n.string("new.prompt.slot_number")),
              let choice = Int(raw.trimmingCharacters(in: .whitespaces)),
              let slot = SlotLabel.slot(atChoice: choice) else {
            print(L10n.string("new.slot_unchanged"))
            return
        }
        draft.screens[position.screen].items[position.item].slot = slot
        draft.screens[position.screen].items[position.item].overlap = nil
        print("\(item.app) → \(SlotLabel.text(slot))")
    }

    private static func addApp(_ draft: inout WorkspaceDraft) {
        guard let name = askInstalledApp(L10n.string("new.prompt.app_name")) else { return }
        guard let slot = askSlot(for: name) else { return }
        guard let screen = askScreen(in: &draft) else { return }
        draft.screens[screen].items.append(.app(name, slot: slot))
        print(L10n.string("new.added_app", name, SlotLabel.text(slot)))
    }

    private static func addWeb(_ draft: inout WorkspaceDraft) {
        guard let name = askInstalledApp(L10n.string("new.prompt.browser_name")) else { return }
        print(L10n.string("new.enter_urls"))
        var tabs: [String] = []
        while let line = Console.ask("url> ") {
            let url = line.trimmingCharacters(in: .whitespaces)
            if url.isEmpty { break }
            tabs.append(url)
        }
        guard !tabs.isEmpty else {
            print(L10n.string("new.no_urls"))
            return
        }
        guard let screen = askScreen(in: &draft) else { return }
        let slot = askOptionalSlot(for: name)
        draft.screens[screen].items.append(.browser(name, slot: slot, tabs: tabs))
        print(L10n.string("new.added_browser", name, tabs.count))
    }

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
        print(L10n.string("new.pick_slot", app))
        print(SlotLabel.picker())
        guard let raw = Console.ask(L10n.string("new.prompt.slot_number")),
              let choice = Int(raw.trimmingCharacters(in: .whitespaces)),
              let slot = SlotLabel.slot(atChoice: choice) else {
            print(L10n.string("new.no_slot"))
            return nil
        }
        return slot
    }

    private static func askOptionalSlot(for app: String) -> Slot? {
        print(L10n.string("new.pick_slot_optional", app))
        print(SlotLabel.picker())
        guard let raw = Console.ask(L10n.string("new.prompt.slot_number")),
              let choice = Int(raw.trimmingCharacters(in: .whitespaces)) else { return nil }
        return SlotLabel.slot(atChoice: choice)
    }

    private static func askScreen(in draft: inout WorkspaceDraft) -> Int? {
        if draft.screens.isEmpty {
            draft.screens.append(ScreenDraft(id: "main", display: .builtin, items: []))
            return 0
        }
        if draft.screens.count == 1 { return 0 }

        print(L10n.string("new.which_screen"))
        for (index, screen) in draft.screens.enumerated() {
            print("  \(index + 1) \(screen.id)")
        }
        guard let raw = Console.ask(L10n.string("new.prompt.screen_number")),
              let choice = Int(raw.trimmingCharacters(in: .whitespaces)),
              draft.screens.indices.contains(choice - 1) else {
            print(L10n.string("new.no_screen"))
            return nil
        }
        return choice - 1
    }

    private static func render(_ draft: WorkspaceDraft) -> String {
        guard draft.itemCount > 0 else {
            return L10n.string("new.empty_draft")
        }
        var lines = DraftSummary.lines(draft, numbered: true)
        if DraftSummary.hasUncertainItem(draft) {
            lines.append("")
            lines.append("  " + L10n.string("new.uncertainty_hint", DraftSummary.uncertaintyNote))
        }
        return lines.joined(separator: "\n")
    }

    private static func warnRange(_ number: Int) {
        print(L10n.string("new.no_such_item", number))
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

    private static func save(_ draft: WorkspaceDraft) -> Int32 {
        guard draft.itemCount > 0 else {
            print(L10n.string("new.nothing_to_save"))
            return 1
        }
        let path = "\(WorkspaceRegistry.defaultDirectory)/\(draft.name).yaml"

        if FileManager.default.fileExists(atPath: path) {
            guard Console.confirm(L10n.string("new.overwrite_confirm", path)) else {
                print(L10n.string("new.not_saved"))
                return 1
            }
        }

        if let reason = WorkspaceFiles.save(draft) {
            print(reason)
            return 1
        }

        print(L10n.string("new.saved", path))
        print(L10n.string("new.run_hint", draft.name))
        return 0
    }

}

extension String {
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
