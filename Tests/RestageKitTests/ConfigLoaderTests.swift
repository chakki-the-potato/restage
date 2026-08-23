import Testing
import Foundation
@testable import RestageKit

private func load(_ yaml: String) throws -> WorkspaceConfig {
    try ConfigLoader.validated(WorkspaceConfig.decode(yaml: yaml))
}

@Test func acceptsValidConfig() throws {
    let config = try load("""
    workspace: dev
    screens:
      - id: code
        anchor: cursor
        items:
          - {type: app, app: cursor, slot: left-half}
          - {type: app, app: iterm, slot: right-half}
    """)
    #expect(config.screens.count == 1)
}

@Test func rejectsEmptyScreens() {
    #expect(throws: ConfigError.self) {
        try load("""
        workspace: dev
        screens: []
        """)
    }
}

@Test func rejectsEmptyItems() {
    #expect(throws: ConfigError.self) {
        try load("""
        workspace: dev
        screens:
          - id: code
            items: []
        """)
    }
}

@Test func rejectsDuplicateScreenID() {
    #expect(throws: ConfigError.self) {
        try load("""
        workspace: dev
        screens:
          - id: code
            items: [{type: app, app: safari}]
          - id: code
            items: [{type: app, app: iterm}]
        """)
    }
}

@Test func rejectsAnchorNotInItems() {
    #expect(throws: ConfigError.self) {
        try load("""
        workspace: dev
        screens:
          - id: code
            anchor: notion
            items: [{type: app, app: safari}]
        """)
    }
}

@Test func acceptsAnchorPointingToBrowserItem() throws {
    let config = try load("""
    workspace: dev
    screens:
      - id: web
        anchor: chrome
        items:
          - type: browser
            app: chrome
            tabs: [https://example.com]
    """)
    #expect(config.screens[0].anchor == AppID("chrome"))
}

@Test func reportsMissingFile() {
    #expect(throws: ConfigError.self) {
        try ConfigLoader.load(path: "/nonexistent/path/to/workspace.yaml")
    }
}

@Test func loadsFromFile() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("restage-config-test", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("workspace.yaml")
    try """
    workspace: dev
    screens:
      - id: code
        items: [{type: app, app: safari, slot: left-half}]
    """.write(to: file, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: directory) }

    let config = try ConfigLoader.load(path: file.path)
    #expect(config.workspace == "dev")
}
