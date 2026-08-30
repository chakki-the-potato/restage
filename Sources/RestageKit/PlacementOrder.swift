public enum PlacementOrder {
    public static func sorted(_ positions: [Int], in items: [PlannedItem]) -> [Int] {
        positions.sorted { left, right in
            let first = rank(items[left])
            let second = rank(items[right])
            return first == second ? left < right : first < second
        }
    }

    static func rank(_ item: PlannedItem) -> Int {
        if item.hasTitle { return 0 }
        if case .tabs = item { return 1 }
        return 2
    }
}
