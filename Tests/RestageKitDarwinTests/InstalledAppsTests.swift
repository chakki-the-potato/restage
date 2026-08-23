import Testing
@testable import RestageKitDarwin

/// 실제 설치 목록 대신 고정 목록으로 검증한다. 이름 대응은 이 파일에서 가장 틀리기 쉬운
/// 부분인데, 검증이 검증하는 사람의 컴퓨터에 깔린 앱에 좌우되면 안 된다.
private let fixture = [
    InstalledApp(name: "Safari", bundleID: "com.apple.Safari", fileName: "Safari"),
    InstalledApp(name: "Google Chrome", bundleID: "com.google.Chrome", fileName: "Google Chrome"),
    InstalledApp(name: "Microsoft Edge", bundleID: "com.microsoft.edgemac", fileName: "Microsoft Edge"),
    InstalledApp(name: "Microsoft Word", bundleID: "com.microsoft.Word", fileName: "Microsoft Word"),
    InstalledApp(name: "Claude", bundleID: "com.anthropic.claudefordesktop", fileName: "Claude"),
    InstalledApp(name: "Claude Code Notifier", bundleID: "com.chanhee.notifier", fileName: "Claude Code Notifier"),
    InstalledApp(name: "Find My", bundleID: "com.apple.findmy", fileName: "FindMy"),
    InstalledApp(name: "KakaoTalk", bundleID: "com.kakao.KakaoTalkMac", fileName: "KakaoTalk"),
    InstalledApp(name: "Visual Studio Code", bundleID: "com.microsoft.VSCode", fileName: "Visual Studio Code"),
]

private func resolved(_ query: String) -> String? {
    guard case .found(let app) = InstalledApps.match(query, in: fixture) else { return nil }
    return app.bundleID
}

@Test func exactNameWins() {
    #expect(resolved("Safari") == "com.apple.Safari")
    #expect(resolved("KakaoTalk") == "com.kakao.KakaoTalkMac")
}

@Test func caseDoesNotMatter() {
    #expect(resolved("safari") == "com.apple.Safari")
    #expect(resolved("kakaotalk") == "com.kakao.KakaoTalkMac")
}

/// 기존 config가 쓰던 짧은 이름이 계속 동작해야 한다. `chrome`은 `Google Chrome`이다.
@Test func singleWordMatchesLongerName() {
    #expect(resolved("chrome") == "com.google.Chrome")
    #expect(resolved("edge") == "com.microsoft.edgemac")
    #expect(resolved("word") == "com.microsoft.Word")
}

/// 정확히 일치하는 이름이 있으면 부분 일치보다 항상 우선한다.
/// 그러지 않으면 `Claude`가 `Claude Code Notifier`로 샐 수 있다.
@Test func exactMatchBeatsWordMatch() {
    #expect(resolved("Claude") == "com.anthropic.claudefordesktop")
}

/// 표시 이름과 파일 이름이 다른 앱은 둘 다로 찾을 수 있어야 한다.
@Test func fileNameAlsoMatches() {
    #expect(resolved("FindMy") == "com.apple.findmy")
    #expect(resolved("Find My") == "com.apple.findmy")
}

/// 띄어쓰기를 뺀 형태도 받아준다.
@Test func normalizedFormMatches() {
    #expect(resolved("googlechrome") == "com.google.Chrome")
    #expect(resolved("visualstudiocode") == "com.microsoft.VSCode")
}

/// bundle ID를 그대로 붙여넣는 사람도 있다. 막을 이유가 없다.
@Test func bundleIDMatchesItself() {
    #expect(resolved("com.apple.Safari") == "com.apple.Safari")
}

/// 이름에 "Microsoft"가 들어간 것은 Edge와 Word 둘이다. Visual Studio Code는
/// bundle ID에만 microsoft가 있고 이름에는 없으므로 걸리지 않는다.
@Test func ambiguousQueryReportsCandidates() {
    guard case .ambiguous(let candidates) = InstalledApps.match("microsoft", in: fixture) else {
        Issue.record("여러 앱이 걸려야 합니다")
        return
    }
    #expect(candidates.map(\.name).sorted() == ["Microsoft Edge", "Microsoft Word"])
}

@Test func unknownNameIsNotFound() {
    #expect(InstalledApps.match("nonexistent-app", in: fixture) == .notFound)
    #expect(InstalledApps.match("", in: fixture) == .notFound)
    #expect(InstalledApps.match("   ", in: fixture) == .notFound)
}
