import Foundation
import RestageKit

struct BrowserDialect {
    let applicationName: String
    let makesWindowWithURL: Bool

    private static let withoutTabControl: Set<String> = [
        "firefox", "firefox developer edition", "firefox nightly",
        "librewolf", "waterfox", "tor browser", "zen", "zen browser",
    ]

    private static let safariName = "safari"

    @MainActor
    static func forApp(_ app: AppID) throws -> BrowserDialect {
        let bundleID = try InstalledApps.bundleID(for: app)
        let name = InstalledApps.displayName(bundleID: bundleID) ?? app.rawValue
        guard InstalledApps.isBrowser(bundleID: bundleID) else {
            throw EngineError.notABrowser(name: name)
        }
        guard !withoutTabControl.contains(name.lowercased()) else {
            throw EngineError.browserWithoutTabControl(name: name)
        }
        return BrowserDialect(
            applicationName: name, makesWindowWithURL: name.lowercased() == safariName)
    }

    func readWindowsScript() -> String {
        """
        set fieldSeparator to character id 9
        set lineSeparator to character id 10
        set out to ""
        tell application "\(applicationName)"
          repeat with w in windows
            try
              set out to out & (id of w)
              repeat with t in tabs of w
                set out to out & fieldSeparator & (URL of t)
              end repeat
              set out to out & lineSeparator
            end try
          end repeat
        end tell
        return out
        """
    }

    func newWindowScript(url: String) -> String {
        if makesWindowWithURL {
            return """
            tell application "\(applicationName)"
              make new document with properties {URL:"\(escape(url))"}
            end tell
            """
        }
        return """
        tell application "\(applicationName)"
          set w to make new window
          set URL of active tab of w to "\(escape(url))"
        end tell
        """
    }

    func readWindowGeometryScript() -> String {
        """
        set fieldSeparator to character id 9
        set lineSeparator to character id 10
        set out to ""
        tell application "\(applicationName)"
          repeat with w in windows
            try
              set b to bounds of w
              set out to out & (item 1 of b) & fieldSeparator & (item 2 of b) ¬
                & fieldSeparator & (item 3 of b) & fieldSeparator & (item 4 of b)
              repeat with t in tabs of w
                set out to out & fieldSeparator & (URL of t)
              end repeat
              set out to out & lineSeparator
            end try
          end repeat
        end tell
        return out
        """
    }

    func setFirstTabURLScript(windowID: Int, url: String) -> String {
        """
        tell application "\(applicationName)"
          tell window id \(windowID)
            set URL of tab 1 to "\(escape(url))"
          end tell
        end tell
        """
    }

    func addTabScript(windowID: Int, url: String) -> String {
        """
        tell application "\(applicationName)"
          tell window id \(windowID)
            make new tab at end of tabs with properties {URL:"\(escape(url))"}
          end tell
        end tell
        """
    }

    func frontWindowIDScript() -> String {
        """
        tell application "\(applicationName)"
          if (count of windows) is 0 then return ""
          return (id of window 1) as string
        end tell
        """
    }

    private func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
