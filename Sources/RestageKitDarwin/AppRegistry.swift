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

    /// 창 배치 검증 표본. 실패 유형이 서로 다른 군을 덮도록 선정했다.
    ///
    /// cursor는 매핑에는 있지만 표본에서 뺐다. probe의 콜드 스타트가 앱을 종료하는데,
    /// 이 저장소의 개발이 Cursor 안에서 이뤄지므로 자기 자신을 죽이게 된다.
    /// Electron 계열은 discord, notion, claude 3종이 대신 덮는다.
    public static let probeSample: [AppID] = [
        AppID("safari"),
        AppID("iterm"),
        AppID("xcode"),
        AppID("iina"),
        AppID("chrome"),
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
