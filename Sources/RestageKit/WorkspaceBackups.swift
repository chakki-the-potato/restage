import Foundation

public enum WorkspaceBackups {
    public static let keepCount = 10

    public static func directory(of configDirectory: String) -> String {
        configDirectory + "/.backups"
    }

    @discardableResult
    public static func snapshot(
        path: String, keep: Int = keepCount, now: Date = Date()
    ) -> String? {
        let manager = FileManager.default
        guard manager.fileExists(atPath: path) else { return nil }

        let name = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        let backups = directory(of: (path as NSString).deletingLastPathComponent)
        let stamp = Self.stampFormatter.string(from: now)
        let destination = "\(backups)/\(name).\(stamp).yaml"

        do {
            try manager.createDirectory(atPath: backups, withIntermediateDirectories: true)
            if manager.fileExists(atPath: destination) {
                try manager.removeItem(atPath: destination)
            }
            try manager.copyItem(atPath: path, toPath: destination)
        } catch {
            return nil
        }
        prune(name: name, in: backups, keep: keep)
        return destination
    }

    static func prune(name: String, in backups: String, keep: Int) {
        let manager = FileManager.default
        guard let entries = try? manager.contentsOfDirectory(atPath: backups) else { return }
        let mine = entries.filter { entry in
            entry.hasPrefix(name + ".") && entry.hasSuffix(".yaml")
                && stamp(of: entry, name: name) != nil
        }.sorted()
        guard mine.count > keep else { return }
        for entry in mine.prefix(mine.count - keep) {
            try? manager.removeItem(atPath: "\(backups)/\(entry)")
        }
    }

    private static func stamp(of entry: String, name: String) -> String? {
        let middle = entry.dropFirst(name.count + 1).dropLast(".yaml".count)
        guard middle.count == 15, stampFormatter.date(from: String(middle)) != nil else {
            return nil
        }
        return String(middle)
    }

    private static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}
