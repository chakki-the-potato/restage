import Foundation
import RestageKit

/// 브라우저별 AppleScript 어휘 차이를 이 파일에만 가둔다.
/// 새 브라우저를 지원하려면 여기에 항목을 추가하면 된다.
struct BrowserDialect {
    let applicationName: String
    private let makesWindowWithURL: Bool

    private static let dialects: [String: BrowserDialect] = [
        "safari": BrowserDialect(applicationName: "Safari", makesWindowWithURL: true),
        "chrome": BrowserDialect(applicationName: "Google Chrome", makesWindowWithURL: false),
    ]

    static func forApp(_ app: AppID) -> BrowserDialect? {
        dialects[app.rawValue.lowercased()]
    }

    /// 창 id와 각 창의 탭 URL을 줄 단위로 돌려준다.
    /// 출력 형식은 창 하나당 한 줄이며 필드는 탭 문자로 구분한다.
    ///
    /// 구분자를 `tell` 블록 밖에서 만드는 이유는 블록 안에서 `tab`이 AppleScript의
    /// 탭 상수가 아니라 브라우저의 `tab` 클래스로 해석되기 때문이다. 그대로 쓰면
    /// 구분자 자리에 문자열 "tab"이 들어가 파싱이 전부 실패한다. 실제로 겪었다.
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

    /// 새 창을 만들고 첫 URL을 연다.
    ///
    /// 만들어진 창이 맨 앞으로 온다는 보장이 없다. Safari에서 실제로 확인했다.
    /// 호출자는 반드시 첫 탭 URL로 창을 다시 찾아야 한다.
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

    func addTabScript(windowID: Int, url: String) -> String {
        """
        tell application "\(applicationName)"
          repeat with w in windows
            if (id of w) is \(windowID) then
              make new tab at end of tabs of w with properties {URL:"\(escape(url))"}
              exit repeat
            end if
          end repeat
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
