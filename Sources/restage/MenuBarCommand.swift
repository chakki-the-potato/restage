import AppKit
import RestageKitDarwin

@MainActor
enum MenuBarCommand {
    static func run() -> Never {
        AppKitBootstrap.ensureGUIApplication()
        let controller = MenuBarController()
        controller.start()
        NSApplication.shared.run()
        exit(0)
    }
}
