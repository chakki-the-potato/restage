import Foundation
import RestageKit

@MainActor
enum ListCommand {
    static func run() -> Int32 {
        let entries: [WorkspaceEntry]
        do {
            entries = try WorkspaceRegistry().list()
        } catch {
            print(error)
            return 2
        }

        guard !entries.isEmpty else {
            print("등록된 워크스페이스가 없습니다: \(WorkspaceRegistry.defaultDirectory)")
            return 0
        }

        print(pad("NAME", 16) + padLeft("SCREENS", 8) + padLeft("ITEMS", 7) + "  STATUS")
        print(String(repeating: "-", count: 80))
        for entry in entries {
            print(
                pad(entry.name, 16)
                + padLeft(entry.summary.map { String($0.screenCount) } ?? "-", 8)
                + padLeft(entry.summary.map { String($0.itemCount) } ?? "-", 7)
                + "  " + (entry.error ?? "ok"))
        }
        return entries.contains { $0.error != nil } ? 1 : 0
    }

    private static func pad(_ text: String, _ width: Int) -> String {
        text + String(repeating: " ", count: max(1, width - text.count))
    }

    private static func padLeft(_ text: String, _ width: Int) -> String {
        String(repeating: " ", count: max(1, width - text.count)) + text
    }
}
