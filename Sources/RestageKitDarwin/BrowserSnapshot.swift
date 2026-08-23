import CoreGraphics
import Foundation
import RestageKit

public struct CapturedBrowserWindow: Sendable, Equatable {
    /// AX 좌표계 사각형. AX가 읽은 창과 짝짓는 열쇠다.
    public let frame: CGRect
    public let tabs: [String]

    public init(frame: CGRect, tabs: [String]) {
        self.frame = frame
        self.tabs = tabs
    }
}

/// 브라우저가 지금 열어둔 탭을 읽는다.
///
/// `TabController`가 탭을 여는 쪽이라면 이쪽은 읽기만 한다. 현재 배치를 config로 옮길 때
/// 창 위치뿐 아니라 열려 있는 URL까지 담기 위해 필요하다.
@MainActor
public enum BrowserSnapshot {
    /// 창 테두리 계산 차이를 흡수할 만큼만 둔다.
    public nonisolated static let defaultTolerance: CGFloat = 2

    /// 해당 브라우저의 창별 탭 목록.
    ///
    /// 실패를 삼키지 않고 올리는 이유는 사용자가 이유를 알아야 하기 때문이다. 자동화 권한을
    /// 거부했는지, 브라우저가 아닌지, 탭 제어를 지원하지 않는지에 따라 할 일이 다르다.
    /// 호출자는 이것을 잡아 탭 없이 창 배치만 담는 경로로 물러서면 된다.
    public static func windows(of app: AppID) throws -> [CapturedBrowserWindow] {
        let dialect = try BrowserDialect.forApp(app)
        let raw = try AppleScriptRunner.run(
            dialect.readWindowGeometryScript(), applicationName: dialect.applicationName)
        return parse(raw)
    }

    /// AX가 읽은 창에 해당하는 브라우저 창의 위치. 없으면 nil이다.
    ///
    /// 제목으로 맞추지 않는 이유는 두 API가 같은 창에 서로 다른 제목을 주기 때문이다.
    /// 이 컴퓨터에서 측정한 값이다.
    ///
    ///     AppleScript(name of w):  "(15) Some Video Title - YouTube 🔊"
    ///     AX(AXTitle):             "(15) Some Video Title - YouTube - Chrome"
    ///
    /// Chrome은 소리가 나면 확성기 기호를 붙이고 AX 제목에는 앱 이름을 덧붙인다. 한쪽이
    /// 다른 쪽의 접두사도 아니다. 게다가 Safari 창 세 개의 제목이 "Example Domain"으로
    /// 겹치기도 했다. 열거 순서도 다르다. AX는 최근 활성 순인데 AppleScript는 그렇지 않다.
    ///
    /// 반면 `bounds`는 AX의 위치·크기와 정확히 같은 값을 준다. 그래서 좌표로 맞춘다.
    /// 창이 완전히 겹쳐 있으면 여럿이 걸리지만 그때는 어느 것을 골라도 결과가 같다.
    public nonisolated static func index(
        matching frame: CGRect, in windows: [CapturedBrowserWindow],
        tolerance: CGFloat = defaultTolerance
    ) -> Int? {
        windows.firstIndex { candidate in
            abs(candidate.frame.minX - frame.minX) <= tolerance
                && abs(candidate.frame.minY - frame.minY) <= tolerance
                && abs(candidate.frame.width - frame.width) <= tolerance
                && abs(candidate.frame.height - frame.height) <= tolerance
        }
    }

    /// 이 앱이 탭을 다룰 수 있는 브라우저인지.
    public static func isBrowser(_ app: AppID) -> Bool {
        (try? BrowserDialect.forApp(app)) != nil
    }

    /// 한 줄에 창 하나. 앞 네 칸이 `bounds`이고 나머지가 탭 URL이다.
    nonisolated static func parse(_ raw: String) -> [CapturedBrowserWindow] {
        raw.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count >= 4 else { return nil }
            let edges = fields.prefix(4).compactMap {
                Double($0.trimmingCharacters(in: .whitespaces))
            }
            guard edges.count == 4 else { return nil }
            let frame = CGRect(
                x: edges[0], y: edges[1],
                width: edges[2] - edges[0], height: edges[3] - edges[1])
            return CapturedBrowserWindow(frame: frame, tabs: fields.dropFirst(4).map(String.init))
        }
    }
}
