import CoreGraphics

/// 화면 잠금 상태. 잠긴 동안에는 AX가 어떤 앱의 창도 열거하지 못한다.
///
/// 이걸 확인하지 않으면 모든 항목이 "창이 뜨지 않았습니다"로 실패하고,
/// 원인이 잠금이라는 사실이 보고서 어디에도 남지 않는다.
public enum ScreenLock {
    private static let lockedKey = "CGSSessionScreenIsLocked"

    public static func isLocked() -> Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return session[lockedKey] as? Int == 1
    }

    public static let message = """
        화면이 잠겨 있습니다.

        잠긴 상태에서는 접근성 API가 창 목록을 조회하지 못해
        모든 항목이 실패로 기록됩니다. 잠금을 해제한 뒤 다시 실행하세요.
        """
}
