import CoreGraphics

/// 논리 앱 식별자. bundle ID 같은 OS 고유 값은 여기 들어오지 않는다.
public struct AppID: Hashable, Sendable, RawRepresentable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

public struct ProcessHandle: Sendable {
    public let pid: Int32
    /// 이번 실행에서 새로 띄웠으면 true, 기존 프로세스를 찾았으면 false.
    public let wasLaunched: Bool

    public init(pid: Int32, wasLaunched: Bool) {
        self.pid = pid
        self.wasLaunched = wasLaunched
    }
}

public struct DisplayInfo: Sendable {
    /// Cocoa 좌표계(bottom-left 원점)의 가용 영역. 메뉴바와 Dock 제외.
    public let visibleFrame: CGRect
    /// 주 디스플레이 위쪽 경계. AX 좌표계 변환 기준.
    public let primaryMaxY: CGFloat

    public init(visibleFrame: CGRect, primaryMaxY: CGFloat) {
        self.visibleFrame = visibleFrame
        self.primaryMaxY = primaryMaxY
    }

    /// 가용 영역을 AX 좌표계(top-left 원점)로 옮긴 사각형.
    public var axBounds: CGRect {
        CGRect(
            x: visibleFrame.minX, y: primaryMaxY - visibleFrame.maxY,
            width: visibleFrame.width, height: visibleFrame.height)
    }
}

/// 창에 대한 불투명 참조. 구현체가 OS 고유 핸들을 숨긴다.
///
/// 이름이 `WindowRef`가 아닌 이유: Carbon(HIToolbox)이 같은 이름의 타입을 정의하고 있어
/// ApplicationServices를 import한 파일에서 'WindowRef is ambiguous for type lookup' 에러가 난다.
///
/// `@MainActor`인 이유: 구현체가 AXUIElement를 들고 있어 액터 경계를 넘길 수 없다.
/// 비격리 프로토콜로 두면 구현체 적합화가 isolation mismatch 에러를 낸다.
@MainActor
public protocol WindowHandle {
    /// AX 좌표계 기준 현재 사각형. 조회 실패 시 nil.
    var currentFrame: CGRect? { get }
    /// 창이 주 디스플레이의 현재 Space에 보이는지 여부.
    var isOnActiveSpace: Bool { get }
}
