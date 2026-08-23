import Foundation
import RestageKit
import RestageKitDarwin

guard AccessibilityPermission.isTrusted(), !ScreenLock.isLocked() else {
    print("접근성 권한 또는 화면 잠금 확인 필요")
    exit(1)
}
guard let displays = DisplayCatalog.current(), let external = displays.externals.first else {
    print("외장 디스플레이가 없습니다")
    exit(1)
}

let target = SlotGeometry.frame(
    for: .leftHalf, in: external.visibleFrame, primaryMaxY: external.primaryMaxY)
print("target=\(target)")

let engine = AXWindowEngine()
do {
    let handle = try await engine.launch(AppID("safari"))
    let window = try await engine.waitForWindow(handle, timeout: .seconds(15))
    let result = await engine.place(window, slot: .leftHalf, display: external)
    print("result=\(result)")
} catch {
    print("실패: \(error)")
    exit(1)
}
