import AppKit

/// AppKit이 화면 정보를 정확히 보고하도록 프로세스를 GUI 앱으로 초기화한다.
///
/// 초기화하지 않으면 `NSScreen.visibleFrame`이 보조 디스플레이의 메뉴바 영역을
/// 반영하지 않는다. 주 디스플레이는 정상인데 외장만 `frame`과 같은 값을 돌려주므로,
/// 그대로 믿고 배치하면 OS가 메뉴바 높이만큼 잘라내 목표에 도달하지 못한다.
/// 이 머신에서 외장 디스플레이의 topInset이 0에서 30으로 바뀌는 것을 확인했다.
///
/// `.accessory`는 Dock 아이콘과 메뉴바를 만들지 않으므로 CLI 동작에 영향이 없다.
/// 이미 정책이 정해져 있으면 건드리지 않는다. 후속 사이클의 메뉴바 UI가 `.regular`를
/// 쓰게 되면 그 설정을 덮어쓰지 않아야 한다.
@MainActor
public enum AppKitBootstrap {
    public static func ensureGUIApplication() {
        let app = NSApplication.shared
        if app.activationPolicy() == .prohibited {
            app.setActivationPolicy(.accessory)
        }
    }
}
