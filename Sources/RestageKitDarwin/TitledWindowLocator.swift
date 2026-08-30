import CoreGraphics
import Foundation
import RestageKit

@MainActor
enum TitledWindowLocator {
    enum Verdict {
        case absent
        case present
        case satisfied
    }

    struct Match {
        let number: Int
        let frame: CGRect
        let spaces: [Int]
    }

    static func check(
        pid: Int32, titleContains wanted: String, fullscreen: Bool, target: CGRect
    ) -> Verdict {
        let found = matches(pid: pid, titleContains: wanted)
        guard !found.isEmpty else { return .absent }
        guard let map = SpaceInventory.map() else { return .present }
        let satisfied = found.contains { match in
            if fullscreen { return map.isFullScreen(match.spaces) }
            return map.isCurrent(match.spaces) && CurrentState.matches(match.frame, target)
        }
        return satisfied ? .satisfied : .present
    }

    static func matches(pid: Int32, titleContains wanted: String) -> [Match] {
        let needle = wanted.lowercased()
        let list = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return list.compactMap { window in
            guard window[kCGWindowOwnerPID as String] as? Int32 == pid,
                  window[kCGWindowLayer as String] as? Int == 0,
                  let name = window[kCGWindowName as String] as? String,
                  name.lowercased().contains(needle),
                  let number = window[kCGWindowNumber as String] as? Int,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let x = bounds["X"] as? Double, let y = bounds["Y"] as? Double,
                  let width = bounds["Width"] as? Double, let height = bounds["Height"] as? Double
            else { return nil }
            return Match(
                number: number,
                frame: CGRect(x: x, y: y, width: width, height: height),
                spaces: SpaceInventory.spaces(ofWindow: number) ?? [])
        }
    }
}
