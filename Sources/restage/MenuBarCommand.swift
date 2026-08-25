import AppKit
import RestageKitDarwin

@MainActor
enum MenuBarCommand {
    /// 컨트롤러를 여기 붙들어 둔다. `NSStatusItem`의 button.target과 `NSMenu`의 delegate는
    /// 둘 다 약한 참조라 지역 변수로 두면 ARC가 곧바로 해제하고 클릭이 아무 데도 닿지 않는다.
    private static var controller: PopoverController?

    static func run() -> Never {
        AppKitBootstrap.ensureGUIApplication()
        // 패널을 열기 전에도 알림 창이 뜰 수 있다. 밝기를 먼저 건다.
        AppearanceSetting.apply()
        let controller = PopoverController()
        Self.controller = controller
        controller.start()
        NSApplication.shared.run()
        exit(0)
    }
}
