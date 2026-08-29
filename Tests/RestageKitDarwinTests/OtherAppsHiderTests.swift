import Testing

@testable import RestageKitDarwin

private func app(
    _ bundleID: String, isRegular: Bool = true, isHidden: Bool = false, pid: Int32 = 100
) -> OtherAppsHider.RunningApp {
    OtherAppsHider.RunningApp(
        bundleID: bundleID, isRegular: isRegular, isHidden: isHidden, pid: pid)
}

private func targets(
    _ running: [OtherAppsHider.RunningApp], keeping: Set<String> = [], selfPID: Int32 = 1
) -> [String] {
    OtherAppsHider.targets(running: running, keeping: keeping, selfPID: selfPID)
}

@Test func anAppThatIsNotDeclaredIsHidden() {
    #expect(targets([app("com.apple.Notes")]) == ["com.apple.Notes"])
}

@Test func aDeclaredAppIsLeftAlone() {
    #expect(targets([app("com.apple.Safari")], keeping: ["com.apple.Safari"]).isEmpty)
}

@Test func finderIsNeverHidden() {
    #expect(targets([app("com.apple.finder")]).isEmpty)
}

@Test func restageDoesNotHideItself() {
    #expect(targets([app("com.chakki.restage", pid: 42)], selfPID: 42).isEmpty)
}

@Test func anAppThatIsAlreadyHiddenIsNotReported() {
    #expect(targets([app("com.apple.Notes", isHidden: true)]).isEmpty)
}

@Test func backgroundAgentsAreNotHidden() {
    #expect(targets([app("com.apple.controlcenter", isRegular: false)]).isEmpty)
}

@Test func onlyTheUndeclaredOnesAreHidden() {
    let running = [
        app("com.apple.Safari", pid: 10),
        app("com.apple.Notes", pid: 11),
        app("com.apple.finder", pid: 12),
        app("com.apple.Dictionary", isHidden: true, pid: 13),
        app("com.chakki.restage", pid: 1),
    ]
    #expect(targets(running, keeping: ["com.apple.Safari"]) == ["com.apple.Notes"])
}
