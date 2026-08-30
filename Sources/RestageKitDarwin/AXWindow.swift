import ApplicationServices
import CoreGraphics
import RestageKit

@_silgen_name("_AXUIElementGetWindow")
private func AXUIElementGetWindow(_ element: AXUIElement, _ identifier: inout CGWindowID) -> AXError

@MainActor
public struct AXWindow: WindowHandle {
    let element: AXUIElement
    public let pid: Int32
    public var wasOpened = false

    init(element: AXUIElement, pid: Int32) {
        self.element = element
        self.pid = pid
    }

    public static func windows(ofPID pid: Int32) throws -> [AXWindow] {
        let app = AXUIElementCreateApplication(pid)
        var raw: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(app, AXAttributes.windows as CFString, &raw)

        if status == .apiDisabled { throw EngineError.axDisabled }
        guard status == .success, let list = raw as? [AXUIElement] else { return [] }
        return list.map { AXWindow(element: $0, pid: pid) }
    }

    @discardableResult
    public func raise() -> Bool {
        AXUIElementPerformAction(element, AXAttributes.raise as CFString) == .success
    }

    @discardableResult
    static func setApplicationFrontmost(pid: Int32) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        return AXUIElementSetAttributeValue(
            app, AXAttributes.frontmost as CFString, true as CFTypeRef) == .success
    }

    public var currentFrame: CGRect? {
        guard let origin = point(AXAttributes.position),
              let extent = size(AXAttributes.size) else { return nil }
        return CGRect(origin: origin, size: extent)
    }

    public var isStale: Bool { currentFrame == nil }

    var windowNumber: Int? {
        var identifier: CGWindowID = 0
        guard AXUIElementGetWindow(element, &identifier) == .success, identifier != 0 else { return nil }
        return Int(identifier)
    }

    public var isOnActiveSpace: Bool {
        currentFrame != nil
    }

    public var role: String? { string(AXAttributes.role) }
    public var title: String? { string(AXAttributes.title) }
    public var minSize: CGSize? { size(AXAttributes.minSize) }
    var isMinimized: Bool { bool(AXAttributes.minimized) ?? false }
    var isFullScreen: Bool { bool(AXAttributes.fullScreen) ?? false }
    var hasFullScreenButton: Bool { rawAttribute(AXAttributes.fullScreenButton) != nil }

    var supportsFullScreen: Bool {
        isSettable(AXAttributes.fullScreen) || hasFullScreenButton
    }

    var isSizeSettable: Bool { isSettable(AXAttributes.size) }

    private func isSettable(_ attribute: String) -> Bool {
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(
            element, attribute as CFString, &settable) == .success else { return false }
        return settable.boolValue
    }

    @discardableResult
    func setPosition(_ value: CGPoint) -> Bool {
        var mutable = value
        guard let axValue = AXValueCreate(.cgPoint, &mutable) else { return false }
        return AXUIElementSetAttributeValue(
            element, AXAttributes.position as CFString, axValue) == .success
    }

    @discardableResult
    func setSize(_ value: CGSize) -> Bool {
        var mutable = value
        guard let axValue = AXValueCreate(.cgSize, &mutable) else { return false }
        return AXUIElementSetAttributeValue(
            element, AXAttributes.size as CFString, axValue) == .success
    }

    @discardableResult
    func setMinimized(_ value: Bool) -> Bool {
        AXUIElementSetAttributeValue(
            element, AXAttributes.minimized as CFString, value as CFTypeRef) == .success
    }

    @discardableResult
    func setMain(_ value: Bool) -> Bool {
        AXUIElementSetAttributeValue(
            element, AXAttributes.main as CFString, value as CFTypeRef) == .success
    }

    @discardableResult
    func setFullScreen(_ value: Bool) -> Bool {
        AXUIElementSetAttributeValue(
            element, AXAttributes.fullScreen as CFString, value as CFTypeRef) == .success
    }

    @discardableResult
    func pressFullScreenButton() -> Bool {
        guard let raw = rawAttribute(AXAttributes.fullScreenButton),
              CFGetTypeID(raw) == AXUIElementGetTypeID() else { return false }
        let button = unsafeDowncast(raw, to: AXUIElement.self)
        return AXUIElementPerformAction(button, AXAttributes.pressAction as CFString) == .success
    }

    private func rawAttribute(_ attribute: String) -> CFTypeRef? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &raw) == .success
        else { return nil }
        return raw
    }

    private func axValue(_ attribute: String) -> AXValue? {
        guard let raw = rawAttribute(attribute),
              CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        return unsafeDowncast(raw, to: AXValue.self)
    }

    private func point(_ attribute: String) -> CGPoint? {
        guard let value = axValue(attribute) else { return nil }
        var result = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &result) else { return nil }
        return result
    }

    private func size(_ attribute: String) -> CGSize? {
        guard let value = axValue(attribute) else { return nil }
        var result = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &result) else { return nil }
        return result
    }

    private func string(_ attribute: String) -> String? {
        rawAttribute(attribute) as? String
    }

    private func bool(_ attribute: String) -> Bool? {
        rawAttribute(attribute) as? Bool
    }
}
