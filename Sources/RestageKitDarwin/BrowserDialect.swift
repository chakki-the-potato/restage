import Foundation
import RestageKit

/// Confines the AppleScript vocabulary differences between browsers to this one file.
/// Supporting a new browser means adding an entry here.
struct BrowserDialect {
    let applicationName: String
    let makesWindowWithURL: Bool

    /// Browsers that don't expose a tab control vocabulary. Chromium syntax doesn't reach them.
    /// They are listed so the failure is reported plainly instead of pretending to work.
    private static let withoutTabControl: Set<String> = [
        "firefox", "firefox developer edition", "firefox nightly",
        "librewolf", "waterfox", "tor browser", "zen", "zen browser",
    ]

    private static let safariName = "safari"

    /// Only Safari has its own vocabulary; everything else uses the Chromium syntax.
    ///
    /// Browsers aren't registered one by one so that someone using a browser missing from a list
    /// never has to edit this file and rebuild. Chrome, Edge, Brave, Arc, Whale, and Vivaldi all
    /// take the Chromium path as is.
    ///
    /// Only Safari and Chrome were verified. The rest run the same code path but weren't
    /// actually checked.
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

    /// Returns window ids and each window's tab URLs, one line per window.
    /// Fields within a line are separated by a tab character.
    ///
    /// The separator is built outside the `tell` block because inside it `tab` resolves to the
    /// browser's `tab` class rather than AppleScript's tab constant. Used as is, the string "tab"
    /// lands in the separator's place and every parse fails. That happened.
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

    /// Makes a new window and opens the first URL in it.
    ///
    /// There is no guarantee the new window comes to the front. Confirmed in Safari.
    /// The caller has to find the window again by its first tab URL.
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

    /// Returns window bounds and each tab URL, one line per window. The first four fields are the bounds.
    ///
    /// Unlike `readWindowsScript`, which uses window ids, this uses coordinates: turning the current
    /// layout into a config means matching the window AX saw with the one the browser knows, and the
    /// two share no id. Titles differ between the APIs, but `bounds` matches AX's position and size exactly.
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

    /// Adds tabs by naming the window id directly.
    ///
    /// Walking windows with `repeat` and appending to `tabs of w` is silently ignored by Brave. No
    /// error is raised and no tab appears, so it reports success having done nothing. That happened.
    /// Naming the window with `tell window id` works in Brave, Chrome, and Safari alike.
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
