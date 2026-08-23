import Testing
@testable import RestageKit

@Test func parsesModifiersRegardlessOfOrderAndCase() throws {
    let a = try HotkeySpec.parse("ctrl+alt+cmd+1")
    let b = try HotkeySpec.parse("CMD+Ctrl+ALT+1")
    #expect(a == b)
    #expect(a.modifiers == [.control, .option, .command])
    #expect(a.key == "1")
}

@Test func acceptsModifierAliases() throws {
    #expect(try HotkeySpec.parse("command+d").modifiers == [.command])
    #expect(try HotkeySpec.parse("cmd+d").modifiers == [.command])
    #expect(try HotkeySpec.parse("option+d").modifiers == [.option])
    #expect(try HotkeySpec.parse("opt+d").modifiers == [.option])
    #expect(try HotkeySpec.parse("alt+d").modifiers == [.option])
    #expect(try HotkeySpec.parse("control+d").modifiers == [.control])
}

@Test func acceptsSupportedKeys() throws {
    #expect(try HotkeySpec.parse("cmd+7").key == "7")
    #expect(try HotkeySpec.parse("cmd+z").key == "z")
    #expect(try HotkeySpec.parse("cmd+f12").key == "f12")
    #expect(try HotkeySpec.parse("cmd+space").key == "space")
    #expect(try HotkeySpec.parse("cmd+return").key == "return")
    #expect(try HotkeySpec.parse("cmd+tab").key == "tab")
}

@Test func rejectsMissingModifier() {
    #expect(throws: ConfigError.self) { try HotkeySpec.parse("1") }
    #expect(throws: ConfigError.self) { try HotkeySpec.parse("") }
}

@Test func rejectsUnknownModifier() {
    #expect(throws: ConfigError.self) { try HotkeySpec.parse("hyper+1") }
}

@Test func rejectsUnknownKey() {
    #expect(throws: ConfigError.self) { try HotkeySpec.parse("cmd+f13") }
    #expect(throws: ConfigError.self) { try HotkeySpec.parse("cmd+backspace") }
}

@Test func errorMessageNamesTheOffendingInput() {
    do {
        _ = try HotkeySpec.parse("hyper+1")
        Issue.record("오류가 나지 않음")
    } catch {
        #expect("\(error)".contains("hyper"))
    }
}

@Test func displayStringUsesMacOSOrder() throws {
    #expect(try HotkeySpec.parse("cmd+alt+ctrl+1").displayString == "⌃⌥⌘1")
    #expect(try HotkeySpec.parse("shift+cmd+d").displayString == "⇧⌘D")
    #expect(try HotkeySpec.parse("ctrl+alt+shift+cmd+f5").displayString == "⌃⌥⇧⌘F5")
}
