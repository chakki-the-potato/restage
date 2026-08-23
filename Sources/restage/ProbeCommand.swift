import Foundation
import RestageKit
import RestageKitDarwin

struct ProbeOptions {
    var slot: Slot = .leftHalf
    var apps: [AppID] = AppRegistry.probeSample
    var includeFullScreen = false
    var warmOnly = false

    static func parse(_ arguments: [String]) throws -> ProbeOptions {
        var options = ProbeOptions()
        var index = 0

        while index < arguments.count {
            switch arguments[index] {
            case "--slot":
                index += 1
                guard index < arguments.count, let slot = Slot(rawValue: arguments[index]) else {
                    throw ProbeError.usage("--slot 값이 올바르지 않습니다. 가능한 값: "
                        + Slot.allCases.map(\.rawValue).joined(separator: ", "))
                }
                options.slot = slot
            case "--app":
                index += 1
                guard index < arguments.count else {
                    throw ProbeError.usage("--app 뒤에 앱 이름이 필요합니다")
                }
                options.apps = [AppID(arguments[index])]
            case "--fullscreen":
                options.includeFullScreen = true
            case "--warm-only":
                options.warmOnly = true
            default:
                throw ProbeError.usage("알 수 없는 인자: \(arguments[index])")
            }
            index += 1
        }
        return options
    }
}

enum ProbeError: Error, CustomStringConvertible {
    case usage(String)
    var description: String {
        switch self { case .usage(let message): return message }
    }
}

@MainActor
enum ProbeCommand {
    static let windowTimeout: Duration = .seconds(15)
    static let terminateTimeout: Duration = .seconds(5)

    static func run(_ options: ProbeOptions) async -> Int32 {
        guard AccessibilityPermission.isTrusted() else {
            print(AccessibilityPermission.onboardingMessage)
            return 1
        }
        guard !ScreenLock.isLocked() else {
            print(ScreenLock.message)
            return 1
        }
        guard let display = DisplayProvider.primary() else {
            print("디스플레이 정보를 조회할 수 없습니다")
            return 1
        }

        let engine = AXWindowEngine()
        var rows: [ProbeRow] = []

        for app in options.apps {
            if !options.warmOnly {
                rows.append(await coldStart(app, engine: engine, display: display, options: options))
            }
            rows.append(await warmStart(app, engine: engine, display: display, options: options))
        }

        print(ProbeReport.render(rows))
        return ProbeReport.hasFailure(rows) ? 1 : 0
    }

    private static func coldStart(
        _ app: AppID, engine: AXWindowEngine, display: DisplayInfo, options: ProbeOptions
    ) async -> ProbeRow {
        do {
            let bundleID = try AppRegistry.bundleID(for: app)
            _ = await AppLauncher.terminate(bundleID: bundleID, timeout: terminateTimeout)
            return await placeOnce(
                app, start: "cold", engine: engine, display: display, options: options)
        } catch {
            return ProbeReport.errorRow(app: app, start: "cold", error: error)
        }
    }

    private static func warmStart(
        _ app: AppID, engine: AXWindowEngine, display: DisplayInfo, options: ProbeOptions
    ) async -> ProbeRow {
        await placeOnce(app, start: "warm", engine: engine, display: display, options: options)
    }

    private static func placeOnce(
        _ app: AppID, start: String, engine: AXWindowEngine,
        display: DisplayInfo, options: ProbeOptions
    ) async -> ProbeRow {
        do {
            let handle = try await engine.launch(app)
            let window = try await engine.waitForWindow(handle, timeout: windowTimeout)
            let result = await engine.place(window, slot: options.slot, display: display)

            guard options.includeFullScreen, result.isPass else {
                return ProbeReport.row(app: app, start: start, result: result)
            }
            let fullScreenResult = await engine.fullscreen(window)
            let restored = await engine.exitFullscreen(window)
            let row = ProbeReport.row(app: app, start: start + "+fs", result: fullScreenResult)
            return restored ? row : ProbeReport.markRestoreFailure(row)
        } catch {
            return ProbeReport.errorRow(app: app, start: start, error: error)
        }
    }
}
