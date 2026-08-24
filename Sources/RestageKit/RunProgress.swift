/// 실행이 어디까지 갔는지.
///
/// 앱을 띄우고 창을 옮기는 데 몇 초가 걸린다. 그동안 도는 표시만 보이면 멈춘 것인지
/// 진행 중인지 알 수 없다. 항목 단위로 세는 이유는 실행기가 항목마다 결과를 내기 때문이다.
/// 화면 단위로 세면 화면이 하나인 워크스페이스에서는 눈금이 하나뿐이라 뜻이 없다.
public struct RunProgress: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        /// 앱을 띄우는 중.
        case launching
        /// 창을 옮기는 중.
        case placing
    }

    public let phase: Phase
    public let app: AppID?
    /// 끝난 항목 수. 지금 하는 항목은 아직 세지 않는다.
    public let completed: Int
    public let total: Int

    public init(phase: Phase, app: AppID?, completed: Int, total: Int) {
        self.phase = phase
        self.app = app
        self.completed = completed
        self.total = total
    }
}
