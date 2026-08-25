import Testing
@testable import RestageKitDarwin

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

@Test func singleWordMatchesLongerName() {
    #expect(resolved("chrome") == "com.google.Chrome")
    #expect(resolved("edge") == "com.microsoft.edgemac")
    #expect(resolved("word") == "com.microsoft.Word")
}

@Test func exactMatchBeatsWordMatch() {
    #expect(resolved("Claude") == "com.anthropic.claudefordesktop")
}

@Test func fileNameAlsoMatches() {
    #expect(resolved("FindMy") == "com.apple.findmy")
    #expect(resolved("Find My") == "com.apple.findmy")
}

@Test func normalizedFormMatches() {
    #expect(resolved("googlechrome") == "com.google.Chrome")
    #expect(resolved("visualstudiocode") == "com.microsoft.VSCode")
}

@Test func bundleIDMatchesItself() {
    #expect(resolved("com.apple.Safari") == "com.apple.Safari")
}

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
