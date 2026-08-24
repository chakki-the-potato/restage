import Foundation
import RestageKit
import ServiceManagement

/// 로그인 시 자동 실행 등록.
///
/// `SMAppService`는 앱 번들을 요구한다. 터미널에서 바이너리를 직접 실행한 경우에는
/// 등록할 대상이 없으므로 메뉴에서 이 항목을 숨긴다.
@MainActor
enum LoginItem {
    static var isSupported: Bool { LaunchContext.isInsideAppBundle }

    static var isEnabled: Bool {
        guard isSupported else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    /// 등록 상태를 뒤집는다. 실패하면 사유를 돌려준다.
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
