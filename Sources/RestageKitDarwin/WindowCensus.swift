import CoreGraphics

enum WindowCensus {
    struct Window: Equatable {
        let number: Int
        let frame: CGRect
        let spaces: [Int]
    }

    struct Result: Equatable {
        var here: [Int] = []
        var elsewhere: [Int] = []
        var offDisplay: [Int] = []
        var noSpace: [Int] = []

        var real: Int { here.count + elsewhere.count + offDisplay.count }
    }

    static func classify(
        _ windows: [Window], currentSpaces: Set<Int>, displays: [CGRect]
    ) -> Result {
        var result = Result()
        for window in windows {
            guard !window.spaces.isEmpty else {
                result.noSpace.append(window.number)
                continue
            }
            guard displays.contains(where: { $0.intersects(window.frame) }) else {
                result.offDisplay.append(window.number)
                continue
            }
            if window.spaces.contains(where: currentSpaces.contains) {
                result.here.append(window.number)
            } else {
                result.elsewhere.append(window.number)
            }
        }
        return result
    }
}
