import Foundation

@MainActor
enum Polling {
    static let defaultInterval: Duration = .milliseconds(25)

    static func poll<T>(
        interval: Duration = defaultInterval,
        timeout: Duration,
        body: () throws -> T?
    ) async rethrows -> T? {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while true {
            if let value = try body() { return value }
            if clock.now >= deadline { return nil }
            try? await Task.sleep(for: interval)
        }
    }

    static func settle<T: Equatable>(
        interval: Duration = defaultInterval,
        timeout: Duration,
        sample: () -> T?
    ) async -> T? {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        var previous: T? = sample()

        while clock.now < deadline {
            try? await Task.sleep(for: interval)
            let current = sample()
            if let current, current == previous { return current }
            previous = current
        }
        return previous
    }
}
