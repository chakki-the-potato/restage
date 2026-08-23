import AppKit
import RestageKit
import RestageKitDarwin

guard AccessibilityPermission.isTrusted() else {
    print(AccessibilityPermission.onboardingMessage)
    exit(1)
}

guard let finder = NSWorkspace.shared.runningApplications
        .first(where: { $0.bundleIdentifier == "com.apple.finder" }) else {
    print("Finder를 찾을 수 없습니다")
    exit(1)
}

do {
    let windows = try AXWindow.windows(ofPID: finder.processIdentifier)
    print("Finder 창 개수: \(windows.count)")
    for window in windows {
        let frame = window.currentFrame.map(String.init(describing:)) ?? "n/a"
        let min = window.minSize.map(String.init(describing:)) ?? "n/a"
        print("  role=\(window.role ?? "?") frame=\(frame) minSize=\(min)")
    }
} catch {
    print("조회 실패: \(error)")
    exit(1)
}
