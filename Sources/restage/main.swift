import Foundation
import RestageKit
import RestageKitDarwin

guard let displays = DisplayCatalog.current() else { exit(1) }
let target = SlotGeometry.frame(
    for: .leftHalf, in: displays.primary.visibleFrame, primaryMaxY: displays.primary.primaryMaxY)
print("target=\(target)")

for name in ["safari", "notion"] {
    do {
        let bundleID = try AppRegistry.bundleID(for: AppID(name))
        guard let app = AppLauncher.runningApplication(bundleID: bundleID) else {
            print("\(name): 미실행")
            continue
        }
        let pid = app.processIdentifier
        print("\(name): 창 \(CurrentState.windowCount(pid: pid))개 "
            + "isPlaced=\(CurrentState.isPlaced(pid: pid, target: target)) "
            + "isFullScreen=\(CurrentState.isFullScreen(pid: pid, on: displays.primary))")
    } catch {
        print("\(name): \(error)")
    }
}
