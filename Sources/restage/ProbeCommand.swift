import AppKit
import Foundation
import RestageKit
import RestageKitDarwin

struct ProbeOptions {
    var slot: Slot = .leftHalf
    /// 비어 있으면 실행 중인 앱 전부를 대상으로 한다. 검증 표본을 코드에 박아두면
    /// 그 목록을 만든 사람의 컴퓨터에서만 의미가 있다.
    var apps: [AppID] = []
    var includeFullScreen = false
    /// 콜드 스타트는 대상 앱을 강제 종료한다. 되돌릴 수 없으므로 기본값은 끔이다.
    var includeColdStart = false

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
            case "--cold":
                options.includeColdStart = true
            default:
                throw ProbeError.usage("알 수 없는 인자: \(arguments[index])")
            }
            index += 1
        }

        guard !options.includeColdStart || !options.apps.isEmpty else {
            throw ProbeError.usage(
                "--cold는 대상 앱을 강제 종료하므로 --app으로 하나만 지정해야 합니다")
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

        let apps = options.apps.isEmpty ? runningApps() : options.apps
        guard !apps.isEmpty else {
            print("검증할 앱이 없습니다. 앱을 하나 이상 실행하거나 --app으로 지정하세요")
            return 1
        }
        guard confirmColdStart(options, apps: apps) else {
            print("취소했습니다")
            return 1
        }

        let engine = AXWindowEngine()
        var rows: [ProbeRow] = []

        for app in apps {
            if options.includeColdStart {
                rows.append(await coldStart(app, engine: engine, display: display, options: options))
            }
            rows.append(await warmStart(app, engine: engine, display: display, options: options))
        }

        print(ProbeReport.render(rows))
        return ProbeReport.hasFailure(rows) ? 1 : 0
    }

    /// 지금 화면에 떠 있는 앱. Dock에 아이콘이 있는 앱만 센다.
    private static func runningApps() -> [AppID] {
        let running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !$0.isTerminated }
        let bundleIDs: [String] = running.compactMap { $0.bundleIdentifier }
        let names: [String] = bundleIDs.compactMap { InstalledApps.displayName(bundleID: $0) }
        return names.sorted().map { AppID($0) }
    }

    /// 앱을 강제 종료하기 전에 확인을 받는다. 작업 중인 창이 저장 없이 닫힐 수 있다.
    private static func confirmColdStart(_ options: ProbeOptions, apps: [AppID]) -> Bool {
        guard options.includeColdStart else { return true }
        let names = apps.map(\.rawValue).joined(separator: ", ")
        return Console.confirm("콜드 스타트를 위해 \(names)을(를) 강제 종료합니다. 계속할까요?")
    }

    private static func coldStart(
        _ app: AppID, engine: AXWindowEngine, display: DisplayInfo, options: ProbeOptions
    ) async -> ProbeRow {
        do {
            let bundleID = try InstalledApps.bundleID(for: app)
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
            let window = try await engine.waitForWindow(
                handle, selector: .mostRecentlyActive, timeout: windowTimeout)
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
