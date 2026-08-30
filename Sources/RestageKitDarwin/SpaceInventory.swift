import CoreGraphics
import Foundation

public struct DisplaySpaces: Sendable, Equatable {
    public let display: String
    public let current: Int
    public let all: [Space]

    public struct Space: Sendable, Equatable {
        public let id: Int
        public let isFullScreen: Bool
        public let tileWindows: [Int]
    }
}

enum SpaceInventory {
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias CopyDisplaySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?
    private typealias CopyWindowSpaces = @convention(c) (Int32, Int32, CFArray)
        -> Unmanaged<CFArray>?
    private typealias SetCurrentSpace = @convention(c) (Int32, CFString, Int) -> Void

    private static let fullScreenType = 4
    private static let allSpacesMask: Int32 = 7
    private static let tileManagerKey = "TileLayoutManager"
    private static let tilesKey = "TileSpaces"
    private static let tileWindowKey = "TileWindowID"

    private static func symbol<T>(_ name: String, as type: T.Type) -> T? {
        guard let handle = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else { return nil }
        return unsafeBitCast(handle, to: type)
    }

    private static let connection: Int32? = {
        guard let main = symbol("CGSMainConnectionID", as: MainConnection.self) else { return nil }
        let id = main()
        return id == 0 ? nil : id
    }()

    static var isAvailable: Bool { connection != nil }

    static func displays() -> [DisplaySpaces]? {
        guard let connection,
              let copy = symbol("CGSCopyManagedDisplaySpaces", as: CopyDisplaySpaces.self),
              let raw = copy(connection)?.takeRetainedValue() as? [[String: Any]] else { return nil }

        return raw.compactMap { entry in
            guard let display = entry["Display Identifier"] as? String else { return nil }
            let current = (entry["Current Space"] as? [String: Any])?["ManagedSpaceID"] as? Int
            let all = (entry["Spaces"] as? [[String: Any]] ?? []).compactMap { space -> DisplaySpaces.Space? in
                guard let id = space["ManagedSpaceID"] as? Int else { return nil }
                return DisplaySpaces.Space(
                    id: id, isFullScreen: space["type"] as? Int == fullScreenType,
                    tileWindows: tileWindows(in: space))
            }
            return DisplaySpaces(display: display, current: current ?? -1, all: all)
        }
    }

    private static func tileWindows(in space: [String: Any]) -> [Int] {
        let manager = space[tileManagerKey] as? [String: Any] ?? [:]
        let tiles = manager[tilesKey] as? [[String: Any]] ?? []
        return tiles.compactMap { $0[tileWindowKey] as? Int }
    }

    static func spaces(ofWindow number: Int) -> [Int]? {
        guard let connection,
              let copy = symbol("CGSCopySpacesForWindows", as: CopyWindowSpaces.self),
              let raw = copy(connection, allSpacesMask, [number] as CFArray)?.takeRetainedValue()
                as? [Int] else { return nil }
        return raw
    }

    static func currentSpaceIDs() -> Set<Int>? {
        guard let displays = displays() else { return nil }
        return Set(displays.map(\.current))
    }

    @discardableResult
    static func show(space: Int, on display: String) -> Bool {
        guard let connection,
              let set = symbol("CGSManagedDisplaySetCurrentSpace", as: SetCurrentSpace.self)
        else { return false }
        set(connection, display as CFString, space)
        return displays()?.contains { $0.display == display && $0.current == space } ?? false
    }

    static func display(of space: Int) -> String? {
        displays()?.first { entry in entry.all.contains { $0.id == space } }?.display
    }

    static func map() -> SpaceMap? {
        guard let displays = displays() else { return nil }
        return SpaceMap(displays: displays)
    }
}
