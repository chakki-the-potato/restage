import Foundation
import RestageKit

/// 브라우저별 AppleScript 어휘 차이를 이 파일에만 가둔다.
/// 새 브라우저를 지원하려면 여기에 항목을 추가하면 된다.
struct BrowserDialect {
    let applicationName: String
    let makesWindowWithURL: Bool

    /// 탭 제어 어휘를 외부에 열어두지 않은 브라우저. Chromium 문법이 통하지 않는다.
    /// 되는 척하지 않고 명확히 실패로 보고하기 위해 목록으로 둔다.
    private static let withoutTabControl: Set<String> = [
        "firefox", "firefox developer edition", "firefox nightly",
        "librewolf", "waterfox", "tor browser", "zen", "zen browser",
    ]

    private static let safariName = "safari"

    /// Safari만 독자 어휘를 쓰고 나머지는 전부 Chromium 계열과 같은 문법을 쓴다.
    ///
    /// 브라우저를 하나씩 등록하지 않는 이유는, 목록에 없는 브라우저를 쓰는 사람이 이 파일을
    /// 고치고 다시 빌드해야 하는 상황을 만들지 않기 위해서다. Chrome, Edge, Brave, Arc,
    /// Whale, Vivaldi는 모두 Chromium 경로를 그대로 탄다.
    ///
    /// 검증한 것은 Safari와 Chrome 둘뿐이다. 나머지는 같은 코드 경로를 타지만 실제로
    /// 확인하지는 않았다.
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

    /// 창 좌표와 각 탭 URL을 줄 단위로 돌려준다. 앞 네 칸이 bounds다.
    ///
    /// `readWindowsScript`가 창 id를 쓰는 것과 달리 좌표를 쓰는 이유는, 현재 배치를 config로
    /// 옮길 때 AX가 본 창과 브라우저가 아는 창을 맞춰야 하는데 둘 사이에 공통된 id가 없기
    /// 때문이다. 제목은 두 API가 서로 다르게 주지만 `bounds`는 AX의 위치·크기와 정확히 같다.
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
