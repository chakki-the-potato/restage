import AppKit
import RestageKitDarwin

@MainActor
enum MenuBarCommand {
    private static var controller: PopoverController?

    static func run() -> Never {
        AppKitBootstrap.ensureGUIApplication()
        AppearanceSetting.apply()
        let controller = PopoverController()
        Self.controller = controller
        controller.start()
        NSApplication.shared.run()
        exit(0)
    }
}
