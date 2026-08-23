import ApplicationServices
import CoreGraphics
import RestageKit

@MainActor
public struct AXWindow: WindowHandle {
    let element: AXUIElement
    /// 이 창을 소유한 프로세스. 요소가 무효화됐을 때 재획득하려면 필요하다.
    public let pid: Int32

    init(element: AXUIElement, pid: Int32) {
        self.element = element
        self.pid = pid
    }

    /// 해당 프로세스의 창 목록. 첫 번째가 가장 최근 활성 창이다.
    public static func windows(ofPID pid: Int32) throws -> [AXWindow] {
        let app = AXUIElementCreateApplication(pid)
        var raw: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(app, AXAttributes.windows as CFString, &raw)

        if status == .apiDisabled { throw EngineError.axDisabled }
        guard status == .success, let list = raw as? [AXUIElement] else { return [] }
        return list.map { AXWindow(element: $0, pid: pid) }
    }

    /// 앱을 최전면으로 올린다.
    ///
    /// `NSRunningApplication.activate()`를 쓰지 않는 이유: 호출하는 쪽이 GUI 앱이 아니면
    /// macOS가 활성화 요청을 무시한다. 이 도구는 CLI라 그 경로가 아무 효과도 내지 못한다.
    /// AX는 접근성 권한이 이미 있으므로 동작하며, Apple Events 권한을 새로 요구하지 않는다.
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

    /// AX 요소가 더 이상 유효하지 않은 상태. Electron 앱은 기동 중 창을 파괴하고
    /// 새로 만드는 경우가 있어, 잡아둔 요소가 도중에 무효화될 수 있다.
    public var isStale: Bool { currentFrame == nil }

    public var isOnActiveSpace: Bool {
        currentFrame != nil
    }

    public var role: String? { string(AXAttributes.role) }
    public var minSize: CGSize? { size(AXAttributes.minSize) }
    var isMinimized: Bool { bool(AXAttributes.minimized) ?? false }
    var isFullScreen: Bool { bool(AXAttributes.fullScreen) ?? false }
    var hasFullScreenButton: Bool { rawAttribute(AXAttributes.fullScreenButton) != nil }

    /// 앱이 이 창의 크기 변경을 허용하는지. IINA의 시작 창처럼 위치만 바뀌고
    /// 크기는 거부되는 창이 있어, 배치 실패 원인을 가릴 때 필요하다.
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
