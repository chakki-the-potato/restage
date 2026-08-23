import Testing
import RestageKit
@testable import RestageKitDarwin

@Test func resolvesKnownApps() throws {
    #expect(try AppRegistry.bundleID(for: AppID("safari")) == "com.apple.Safari")
    #expect(try AppRegistry.bundleID(for: AppID("cursor")) == "com.todesktop.230313mzl4w4u92")
    #expect(try AppRegistry.bundleID(for: AppID("kakaotalk")) == "com.kakao.KakaoTalkMac")
}

@Test func rejectsUnknownApp() {
    #expect(throws: EngineError.self) {
        try AppRegistry.bundleID(for: AppID("nonexistent-app"))
    }
}

@Test func lookupIsCaseInsensitive() throws {
    #expect(try AppRegistry.bundleID(for: AppID("Safari")) == "com.apple.Safari")
    #expect(try AppRegistry.bundleID(for: AppID("KakaoTalk")) == "com.kakao.KakaoTalkMac")
}

@Test func sampleExcludesProtectedApps() {
    #expect(AppRegistry.probeSample.count == 8)
    for app in AppRegistry.protected {
        #expect(!AppRegistry.probeSample.contains(app))
    }
}

@Test func protectedAppsAreRecognized() {
    #expect(AppRegistry.isProtected(AppID("cursor")))
    #expect(AppRegistry.isProtected(AppID("Cursor")))
    #expect(AppRegistry.isProtected(AppID("chrome")))
    #expect(!AppRegistry.isProtected(AppID("safari")))
}

@Test func protectedAppsStillResolveForNormalUse() throws {
    #expect(try AppRegistry.bundleID(for: AppID("cursor")) == "com.todesktop.230313mzl4w4u92")
    #expect(try AppRegistry.bundleID(for: AppID("chrome")) == "com.google.Chrome")
}

@Test func everySampleAppResolves() throws {
    for app in AppRegistry.probeSample {
        _ = try AppRegistry.bundleID(for: app)
    }
}

@Test func knownAppsIsSortedAndCoversSample() {
    let known = AppRegistry.knownApps.map(\.rawValue)
    #expect(known == known.sorted())
    for app in AppRegistry.probeSample {
        #expect(known.contains(app.rawValue))
    }
}
