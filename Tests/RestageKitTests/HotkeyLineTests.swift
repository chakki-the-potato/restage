import Testing
@testable import RestageKit

private let config = """
    workspace: dev
    screens:
      - id: main
        display: builtin
        items:
          - {type: app, app: Safari, slot: left-half}
    """

@Test func insertsHotkeyBelowWorkspace() {
    let updated = HotkeyLine.apply("ctrl+alt+cmd+1", to: config)
    let lines = updated.components(separatedBy: "\n")
    #expect(lines[0] == "workspace: dev")
    #expect(lines[1] == #"hotkey: "ctrl+alt+cmd+1""#)
    #expect(lines[2] == "screens:")
}

@Test func replacesExistingHotkeyInPlace() {
    let withHotkey = HotkeyLine.apply("ctrl+alt+cmd+1", to: config)
    let updated = HotkeyLine.apply("shift+cmd+9", to: withHotkey)
    #expect(updated.components(separatedBy: "\n")[1] == #"hotkey: "shift+cmd+9""#)
    #expect(!updated.contains("ctrl+alt+cmd+1"))
}

@Test func removesHotkeyWhenNil() {
    let withHotkey = HotkeyLine.apply("ctrl+alt+cmd+1", to: config)
    #expect(HotkeyLine.apply(nil, to: withHotkey) == config)
}

@Test func removingAbsentHotkeyChangesNothing() {
    #expect(HotkeyLine.apply(nil, to: config) == config)
}

@Test func preservesCommentsAndFormatting() {
    let handWritten = """
        # 아침 작업용
        workspace: dev

        screens:
          - id: main        # 내장 화면
            display: builtin
            items:
              - {type: app, app: Safari, slot: left-half}
        """
    let updated = HotkeyLine.apply("ctrl+alt+cmd+1", to: handWritten)
    #expect(updated.contains("# 아침 작업용"))
    #expect(updated.contains("# 내장 화면"))
    #expect(updated.contains(#"hotkey: "ctrl+alt+cmd+1""#))
    #expect(HotkeyLine.apply(nil, to: updated) == handWritten)
}

@Test func ignoresIndentedHotkeyKeys() {
    let nested = """
        workspace: dev
        screens:
          - id: main
            hotkey: not-a-top-level-key
        """
    let updated = HotkeyLine.apply("cmd+1", to: nested)
    #expect(updated.contains("    hotkey: not-a-top-level-key"))
    #expect(updated.components(separatedBy: "\n")[1] == #"hotkey: "cmd+1""#)
}

@Test func writtenHotkeyParsesBack() throws {
    let updated = HotkeyLine.apply("ctrl+alt+cmd+1", to: config)
    let parsed = try WorkspaceConfig.decode(yaml: updated)
    #expect(parsed.hotkey == "ctrl+alt+cmd+1")
}

@Test func configStringIsParseableBack() throws {
    let spec = HotkeySpec(modifiers: [.command, .shift], key: "9")
    #expect(spec.configString == "shift+cmd+9")
    #expect(try HotkeySpec.parse(spec.configString) == spec)
}

@Test func configStringOrdersModifiersConsistently() {
    let spec = HotkeySpec(modifiers: [.command, .option, .control], key: "1")
    #expect(spec.configString == "ctrl+alt+cmd+1")
}

@Test func plainKeyIsNotUsableAsGlobalHotkey() {
    #expect(!HotkeySpec(modifiers: [], key: "a").isUsableAsGlobalHotkey)
    #expect(HotkeySpec(modifiers: [.command], key: "a").isUsableAsGlobalHotkey)
    #expect(!HotkeySpec(modifiers: [.command], key: "f13").isUsableAsGlobalHotkey)
}
