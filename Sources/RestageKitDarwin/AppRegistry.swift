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
    public static let probeSample: [AppID] = [
        AppID("safari"),
        AppID("iterm"),
        AppID("xcode"),
        AppID("iina"),
        AppID("chrome"),
        AppID("cursor"),
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
