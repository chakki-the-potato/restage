struct SpaceMap {
    private let current: Set<Int>
    private let fullScreen: Set<Int>
    private let tiles: [Int: [Int]]
    private let positions: [Int: Int]

    init(displays: [DisplaySpaces]) {
        current = Set(displays.map(\.current))
        var fullScreen: Set<Int> = []
        var tiles: [Int: [Int]] = [:]
        var positions: [Int: Int] = [:]
        for (index, space) in displays.flatMap(\.all).enumerated() {
            if space.isFullScreen { fullScreen.insert(space.id) }
            tiles[space.id] = space.tileWindows
            positions[space.id] = index
        }
        self.fullScreen = fullScreen
        self.tiles = tiles
        self.positions = positions
    }

    func position(of spaces: [Int]) -> Int {
        spaces.compactMap { positions[$0] }.min() ?? Int.max
    }

    var currentSpaces: Set<Int> { current }

    func isCurrent(_ spaces: [Int]) -> Bool {
        spaces.contains { current.contains($0) }
    }

    func isFullScreen(_ spaces: [Int]) -> Bool {
        spaces.contains { fullScreen.contains($0) }
    }

    func isSharedFullScreen(_ spaces: [Int]) -> Bool {
        spaces.contains { fullScreen.contains($0) && (tiles[$0]?.count ?? 0) > 1 }
    }

    func holdsAllOf(_ spaces: [Int], window: Int) -> Bool {
        for space in spaces where fullScreen.contains(space) {
            guard let owners = tiles[space], !owners.isEmpty else { continue }
            if !owners.contains(window) { return false }
        }
        return true
    }
}
