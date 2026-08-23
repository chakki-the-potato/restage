import Testing
import Foundation
@testable import RestageKit

private func makeTemporaryDirectory() throws -> String {
    let path = FileManager.default.temporaryDirectory
        .appendingPathComponent("restage-registry-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
    return path.path
}

private func write(_ yaml: String, to directory: String, as fileName: String) throws {
    try yaml.write(
        toFile: directory + "/" + fileName, atomically: true, encoding: .utf8)
}

private let validConfig = """
workspace: dev
screens:
  - id: main
    items:
      - {type: app, app: safari, slot: left-half}
      - {type: app, app: notion, slot: right-half}
"""

private let twoScreenConfig = """
workspace: split
screens:
  - id: main
    items:
      - {type: app, app: safari, slot: left-half}
  - id: side
    display: external-1
    items:
      - {type: app, app: iterm, slot: full}
"""

@Test func resolvesBareNameToDirectoryFile() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(atPath: directory) }
    try write(validConfig, to: directory, as: "dev.yaml")

    let registry = WorkspaceRegistry(directory: directory)
    #expect(try registry.resolve("dev") == directory + "/dev.yaml")
}

@Test func treatsArgumentWithSlashAsPath() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(atPath: directory) }
    try write(validConfig, to: directory, as: "dev.yaml")

    let registry = WorkspaceRegistry(directory: directory)
    #expect(try registry.resolve(directory + "/dev.yaml") == directory + "/dev.yaml")
}

@Test func treatsYAMLSuffixAsPath() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(atPath: directory) }
    let registry = WorkspaceRegistry(directory: directory)
    #expect(try registry.resolve("dev.yaml") == "dev.yaml")
    #expect(try registry.resolve("dev.yml") == "dev.yml")
}

@Test func expandsTildeInPath() throws {
    let registry = WorkspaceRegistry(directory: "/tmp/unused")
    let resolved = try registry.resolve("~/somewhere/dev.yaml")
    #expect(!resolved.hasPrefix("~"))
    #expect(resolved.hasSuffix("/somewhere/dev.yaml"))
}

@Test func reportsMissingDirectory() {
    let registry = WorkspaceRegistry(directory: "/nonexistent/restage-dir")
    #expect(throws: ConfigError.self) { try registry.resolve("dev") }
}

@Test func reportsMissingWorkspaceWithAvailableNames() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(atPath: directory) }
    try write(validConfig, to: directory, as: "dev.yaml")
    try write(twoScreenConfig, to: directory, as: "split.yaml")

    let registry = WorkspaceRegistry(directory: directory)
    do {
        _ = try registry.resolve("devv")
        Issue.record("오류가 나지 않음")
    } catch let error as ConfigError {
        let text = "\(error)"
        #expect(text.contains("devv"))
        #expect(text.contains("dev"))
        #expect(text.contains("split"))
    }
}

@Test func listsEntriesSortedByName() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(atPath: directory) }
    try write(twoScreenConfig, to: directory, as: "split.yaml")
    try write(validConfig, to: directory, as: "dev.yaml")

    let entries = try WorkspaceRegistry(directory: directory).list()
    #expect(entries.map(\.name) == ["dev", "split"])
}

@Test func listCountsScreensAndItems() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(atPath: directory) }
    try write(validConfig, to: directory, as: "dev.yaml")
    try write(twoScreenConfig, to: directory, as: "split.yaml")

    let entries = try WorkspaceRegistry(directory: directory).list()
    #expect(entries[0].screenCount == 1)
    #expect(entries[0].itemCount == 2)
    #expect(entries[1].screenCount == 2)
    #expect(entries[1].itemCount == 2)
    #expect(entries.allSatisfy { $0.error == nil })
}

@Test func listKeepsBrokenConfigsWithError() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(atPath: directory) }
    try write(validConfig, to: directory, as: "dev.yaml")
    try write("""
    workspace: broken
    screens:
      - id: a
        items: [{type: app, app: safari, slot: nonsense}]
    """, to: directory, as: "broken.yaml")

    let entries = try WorkspaceRegistry(directory: directory).list()
    #expect(entries.map(\.name) == ["broken", "dev"])
    #expect(entries[0].error != nil)
    #expect(entries[0].screenCount == nil)
    #expect(entries[0].itemCount == nil)
    #expect(entries[1].error == nil)
}

@Test func listRecognizesBothYAMLExtensions() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(atPath: directory) }
    try write(validConfig, to: directory, as: "a.yaml")
    try write(validConfig, to: directory, as: "b.yml")

    let entries = try WorkspaceRegistry(directory: directory).list()
    #expect(entries.map(\.name) == ["a", "b"])
}

@Test func listIgnoresNonYAMLFiles() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(atPath: directory) }
    try write(validConfig, to: directory, as: "dev.yaml")
    try write("not yaml", to: directory, as: "README.md")

    let entries = try WorkspaceRegistry(directory: directory).list()
    #expect(entries.map(\.name) == ["dev"])
}

@Test func listIsEmptyForEmptyDirectory() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(atPath: directory) }
    #expect(try WorkspaceRegistry(directory: directory).list().isEmpty)
}

@Test func listReportsMissingDirectory() {
    #expect(throws: ConfigError.self) {
        try WorkspaceRegistry(directory: "/nonexistent/restage-dir").list()
    }
}
