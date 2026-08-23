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
print("visibleFrame=\(display.visibleFrame) primaryMaxY=\(display.primaryMaxY)")
print("")

do {
    for app in AppRegistry.probeSample {
        let bundleID = try AppRegistry.bundleID(for: app)
        let instances = AppLauncher.runningApplications(bundleID: bundleID)
        let pids = instances.map { String($0.processIdentifier) }.joined(separator: ",")
        print("\(app.rawValue): instances=\(instances.count) pids=[\(pids)]")
    }
} catch {
    print("조회 실패: \(error)")
    exit(1)
}
