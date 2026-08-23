import Foundation

/// `@MainActor`인 이유: 호출자가 전부 MainActor 격리 타입이라
/// 비격리로 두면 클로저를 넘길 때 'sending value of non-Sendable type' 에러가 난다.
@MainActor
enum Polling {
    static let defaultInterval: Duration = .milliseconds(25)

    /// body가 nil이 아닌 값을 반환할 때까지 폴링한다. 타임아웃 시 nil.
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

    /// sample이 연속 2회 같은 값을 반환할 때까지 폴링한다.
    /// Electron 앱이 배치 직후 스스로 크기를 되돌리는 동작이 끝난 시점을 잡는다.
    /// 타임아웃 시 마지막으로 관측한 값을 반환한다(관측 자체가 실패했으면 nil).
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
