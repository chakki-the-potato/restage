import RestageKit

/// 논리 앱 이름을 macOS bundle ID로 해석한다.
/// bundle ID 문자열은 프로젝트 전체에서 이 파일에만 존재해야 한다.
public enum AppRegistry {
    private static let mapping: [String: String] = [
        "safari": "com.apple.Safari",
        "iterm": "com.googlecode.iterm2",
        "xcode": "com.apple.dt.Xcode",
        "iina": "com.colliderli.iina",
        "chrome": "com.google.Chrome",
        "cursor": "com.todesktop.230313mzl4w4u92",
        "discord": "com.hnc.Discord",
        "notion": "notion.id",
        "claude": "com.anthropic.claudefordesktop",
        "kakaotalk": "com.kakao.KakaoTalkMac",
    ]

    /// probe가 종료하거나 창을 옮겨서는 안 되는 앱.
    ///
    /// probe는 콜드 스타트를 재현하려고 대상 앱을 종료한다. 그 동작이 절대 닿으면
    /// 안 되는 앱을 여기 둔다. 지시문이나 기억이 아니라 코드로 막는다.
    ///
    /// - cursor: 이 저장소의 개발이 Cursor 안에서 이뤄진다. 종료하면 세션이 끊긴다.
    /// - chrome: 사용자가 작업 중인 브라우저다.
    ///
    /// 매핑에는 남아 있으므로 `restage open`은 config에 선언되면 정상 배치한다.
    /// 보호 대상은 검증 하네스의 파괴적 동작뿐이다.
    public static let protected: Set<AppID> = [
        AppID("cursor"),
        AppID("chrome"),
    ]

    public static func isProtected(_ app: AppID) -> Bool {
        protected.contains(AppID(app.rawValue.lowercased()))
    }

    /// 창 배치 검증 표본. 실패 유형이 서로 다른 군을 덮도록 선정했다.
    ///
    /// `protected`에 있는 앱은 제외한다. Chromium 계열이 빠지지만 Electron 계열
    /// discord, notion, claude 3종이 렌더러 자가 리사이즈 유형을 덮는다.
    public static let probeSample: [AppID] = [
        AppID("safari"),
        AppID("iterm"),
        AppID("xcode"),
        AppID("iina"),
        AppID("discord"),
        AppID("notion"),
        AppID("claude"),
        AppID("kakaotalk"),
    ]

    public static func bundleID(for app: AppID) throws -> String {
        guard let id = mapping[app.rawValue.lowercased()] else {
            throw EngineError.unknownApp(app)
        }
        return id
    }

    public static var knownApps: [AppID] {
        mapping.keys.sorted().map { AppID($0) }
    }
}
