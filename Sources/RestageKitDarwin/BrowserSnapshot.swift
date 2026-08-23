import RestageKit

public struct CapturedBrowserWindow: Sendable, Equatable {
    /// 창 제목. 활성 탭의 제목이라 AX가 읽은 `AXTitle`과 같은 값이다.
    public let title: String
    public let tabs: [String]

    public init(title: String, tabs: [String]) {
        self.title = title
        self.tabs = tabs
    }
}

/// 브라우저가 지금 열어둔 탭을 읽는다.
///
/// `TabController`가 탭을 여는 쪽이라면 이쪽은 읽기만 한다. 현재 배치를 config로 옮길 때
/// 창 위치뿐 아니라 열려 있는 URL까지 담기 위해 필요하다.
@MainActor
public enum BrowserSnapshot {
    /// 해당 브라우저의 창별 탭 목록. 브라우저가 아니거나 권한이 없으면 nil이다.
    ///
    /// 실패를 오류로 올리지 않고 nil로 돌려주는 이유는 호출자가 탭 없이 창 배치만 담는
    /// 경로로 물러설 수 있어야 하기 때문이다. 자동화 권한을 거부한 사용자에게 config 생성
    /// 전체가 막히면 안 된다.
    public static func windows(of app: AppID) -> [CapturedBrowserWindow]? {
        guard let dialect = try? BrowserDialect.forApp(app) else { return nil }
        guard let raw = try? AppleScriptRunner.run(
            dialect.readWindowTitlesScript(), applicationName: dialect.applicationName)
        else { return nil }

        return raw.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard let title = fields.first else { return nil }
            return CapturedBrowserWindow(
                title: String(title), tabs: fields.dropFirst().map(String.init))
        }
    }

    /// 이 앱이 탭을 다룰 수 있는 브라우저인지. 탭 제어가 안 되는 브라우저는 false다.
    public static func isBrowser(_ app: AppID) -> Bool {
        (try? BrowserDialect.forApp(app)) != nil
    }

    /// 탭 제어 가능 여부와 무관하게 브라우저인지. 탭 없이 창만 배치할 때 쓴다.
    public static func isAnyBrowser(bundleID: String) -> Bool {
        InstalledApps.isBrowser(bundleID: bundleID)
    }
}
