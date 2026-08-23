/// AX 속성 이름. Swift 6 strict concurrency에서 `kAX*` 전역 상수는
/// 'not concurrency-safe' 에러를 내므로 리터럴로 정의한다.
enum AXAttributes {
    static let windows = "AXWindows"
    static let frontmost = "AXFrontmost"
    static let main = "AXMain"
    static let role = "AXRole"
    static let position = "AXPosition"
    static let size = "AXSize"
    static let minSize = "AXMinSize"
    static let minimized = "AXMinimized"
    static let fullScreen = "AXFullScreen"
    static let fullScreenButton = "AXFullScreenButton"
    static let windowRole = "AXWindow"
    static let pressAction = "AXPress"
}
