import CoreGraphics
import RestageKit

public enum ScreenLock {
    private static let lockedKey = "CGSSessionScreenIsLocked"

    public static func isLocked() -> Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return session[lockedKey] as? Int == 1
    }

    public static var message: String { L10n.string("screen_lock.message") }
}
