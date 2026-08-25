import Foundation
import RestageKit
import ServiceManagement

@MainActor
enum LoginItem {
    static var isSupported: Bool { LaunchContext.isInsideAppBundle }

    static var isEnabled: Bool {
        guard isSupported else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    static func toggle() -> String? {
        guard isSupported else { return L10n.string("error.login_item.needs_bundle") }
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
