import Foundation
import Testing

@testable import RestageKit

private func makeConfigDirectory() throws -> String {
    let path = NSTemporaryDirectory() + "restage-backups-" + UUID().uuidString
    try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    return path
}

@Test func snapshotCopiesTheCurrentFile() throws {
    let directory = try makeConfigDirectory()
    defer { try? FileManager.default.removeItem(atPath: directory) }
    let path = directory + "/dev.yaml"
    try "workspace: dev\n".write(toFile: path, atomically: true, encoding: .utf8)

    let backup = WorkspaceBackups.snapshot(path: path)

    #expect(backup?.hasPrefix(directory + "/.backups/dev.") == true)
    #expect(try String(contentsOfFile: backup!, encoding: .utf8) == "workspace: dev\n")
}

@Test func snapshotOfMissingFileDoesNothing() throws {
    let directory = try makeConfigDirectory()
    defer { try? FileManager.default.removeItem(atPath: directory) }

    #expect(WorkspaceBackups.snapshot(path: directory + "/none.yaml") == nil)
    #expect(!FileManager.default.fileExists(atPath: directory + "/.backups"))
}

@Test func pruneKeepsOnlyTheNewestPerName() throws {
    let directory = try makeConfigDirectory()
    defer { try? FileManager.default.removeItem(atPath: directory) }
    let path = directory + "/dev.yaml"
    try "workspace: dev\n".write(toFile: path, atomically: true, encoding: .utf8)

    let base = Date(timeIntervalSince1970: 1_700_000_000)
    for second in 0..<5 {
        _ = WorkspaceBackups.snapshot(
            path: path, keep: 3, now: base.addingTimeInterval(Double(second)))
    }
    try "workspace: other\n".write(
        toFile: directory + "/other.yaml", atomically: true, encoding: .utf8)
    _ = WorkspaceBackups.snapshot(path: directory + "/other.yaml", keep: 3, now: base)

    let backups = try FileManager.default.contentsOfDirectory(atPath: directory + "/.backups")
    #expect(backups.filter { $0.hasPrefix("dev.") }.count == 3)
    #expect(backups.filter { $0.hasPrefix("other.") }.count == 1)
}

@Test func backupsDirectoryStaysOutOfTheRegistryListing() throws {
    let directory = try makeConfigDirectory()
    defer { try? FileManager.default.removeItem(atPath: directory) }
    let path = directory + "/dev.yaml"
    try "workspace: dev\nscreens:\n  - id: main\n    items:\n      - {type: app, app: safari, slot: full}\n"
        .write(toFile: path, atomically: true, encoding: .utf8)
    _ = WorkspaceBackups.snapshot(path: path)

    let names = try WorkspaceRegistry(directory: directory).list().map(\.name)
    #expect(names == ["dev"])
}
