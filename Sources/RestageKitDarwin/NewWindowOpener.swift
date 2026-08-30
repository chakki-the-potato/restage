import AppKit
import ApplicationServices
import RestageKit

@MainActor
enum NewWindowOpener {
    static let appearTimeout: Duration = .seconds(5)

    private static let blankURL = "about:blank"
    private static let menuBar = "AXMenuBar"
    private static let children = "AXChildren"
    private static let cmdChar = "AXMenuItemCmdChar"
    private static let cmdModifiers = "AXMenuItemCmdModifiers"
    private static let enabled = "AXEnabled"
    private static let newWindowKey = "N"
    private static let commandOnly = 0

    static func isNewWindowItem(
        cmdChar: String?, cmdModifiers: Int?, isEnabled: Bool?
    ) -> Bool {
        guard isEnabled != false else { return false }
        guard let cmdChar, cmdChar.uppercased() == newWindowKey else { return false }
        return cmdModifiers == commandOnly
    }

    static func open(pid: Int32) -> Bool {
        if openBrowserWindow(pid: pid) { return true }
        return pressNewWindowItem(pid: pid)
    }

    private static func openBrowserWindow(pid: Int32) -> Bool {
        guard let name = appName(pid: pid),
              let dialect = try? BrowserDialect.forApp(AppID(name)) else { return false }
        let script = dialect.newWindowScript(url: blankURL)
        return (try? AppleScriptRunner.run(script, applicationName: name)) != nil
    }

    private static func appName(pid: Int32) -> String? {
        guard let running = NSRunningApplication(processIdentifier: pid),
              let bundleID = running.bundleIdentifier else { return nil }
        return InstalledApps.displayName(bundleID: bundleID)
    }

    private static func pressNewWindowItem(pid: Int32) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        guard let item = newWindowItem(in: app) else { return false }
        if press(item) { return true }
        AXWindow.setApplicationFrontmost(pid: pid)
        return press(item)
    }

    private static func press(_ item: AXUIElement) -> Bool {
        AXUIElementPerformAction(item, AXAttributes.pressAction as CFString) == .success
    }

    private static func newWindowItem(in app: AXUIElement) -> AXUIElement? {
        guard let bar = element(app, menuBar) else { return nil }
        for barItem in list(bar, children) {
            for menu in list(barItem, children) {
                for item in list(menu, children) {
                    if matches(item) { return item }
                    for submenu in list(item, children) {
                        for nested in list(submenu, children) where matches(nested) {
                            return nested
                        }
                    }
                }
            }
        }
        return nil
    }

    private static func matches(_ item: AXUIElement) -> Bool {
        isNewWindowItem(
            cmdChar: string(item, cmdChar), cmdModifiers: integer(item, cmdModifiers),
            isEnabled: bool(item, enabled))
    }

    private static func list(_ element: AXUIElement, _ attribute: String) -> [AXUIElement] {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, attribute as CFString, &raw) == .success,
            let values = raw as? [AXUIElement] else { return [] }
        return values
    }

    private static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, attribute as CFString, &raw) == .success,
            let value = raw, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, attribute as CFString, &raw) == .success else { return nil }
        return raw as? String
    }

    private static func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, attribute as CFString, &raw) == .success else { return nil }
        return raw as? Bool
    }

    private static func integer(_ element: AXUIElement, _ attribute: String) -> Int? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, attribute as CFString, &raw) == .success else { return nil }
        return raw as? Int
    }
}
