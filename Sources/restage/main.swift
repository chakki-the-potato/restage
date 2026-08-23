import AppKit
import RestageKit
import RestageKitDarwin

guard AccessibilityPermission.isTrusted() else {
    print(AccessibilityPermission.onboardingMessage)
    exit(1)
}

guard let display = DisplayProvider.primary() else {
    print("디스플레이 정보를 조회할 수 없습니다")
    exit(1)
}

let target = SlotGeometry.frame(
    for: .leftHalf, in: display.visibleFrame, primaryMaxY: display.primaryMaxY)
print("target=\(target)")

do {
    let bundleID = try AppRegistry.bundleID(for: AppID("cursor"))
    guard let app = AppLauncher.runningApplication(bundleID: bundleID) else {
        print("cursor가 실행 중이 아닙니다")
        exit(1)
    }
    let window = try await WindowWaiter.wait(pid: app.processIdentifier, timeout: .seconds(5))
    print("before=\(window.currentFrame.map(String.init(describing:)) ?? "n/a")")
    await WindowWaiter.prepareForDesktopPlacement(window)
    let result = await WindowPlacer.place(window, target: target)
    print("result=\(result)")
    print("after=\(window.currentFrame.map(String.init(describing:)) ?? "n/a")")
} catch {
    print("실패: \(error)")
    exit(1)
}
