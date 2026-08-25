public struct RunProgress: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        case launching
        case placing
    }

    public let phase: Phase
    public let app: AppID?
    public let completed: Int
    public let total: Int

    public init(phase: Phase, app: AppID?, completed: Int, total: Int) {
        self.phase = phase
        self.app = app
        self.completed = completed
        self.total = total
    }
}
