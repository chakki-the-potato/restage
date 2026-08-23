import Foundation
import RestageKit
import RestageKitDarwin

guard AccessibilityPermission.isTrusted() else {
    print(AccessibilityPermission.onboardingMessage)
    exit(1)
}
guard let displays = DisplayCatalog.current() else {
    print("디스플레이를 찾을 수 없습니다")
    exit(1)
}
print("primary: visibleFrame=\(displays.primary.visibleFrame) primaryMaxY=\(displays.primary.primaryMaxY)")
for (index, external) in displays.externals.enumerated() {
    print("external-\(index + 1): visibleFrame=\(external.visibleFrame) primaryMaxY=\(external.primaryMaxY)")
}
