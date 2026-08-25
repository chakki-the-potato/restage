import AppKit

@MainActor
public enum AppKitBootstrap {
    public static func ensureGUIApplication() {
        let app = NSApplication.shared
        if app.activationPolicy() == .prohibited {
            app.setActivationPolicy(.accessory)
        }
    }
}
