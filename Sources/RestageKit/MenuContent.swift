import Foundation

/// 메뉴에 그릴 항목 하나. AppKit과 분리해 단위 테스트가 가능하게 한다.
public enum MenuEntry: Equatable, Sendable {
    /// 클릭하면 실행되는 워크스페이스.
    case workspace(name: String)
    /// 파싱에 실패해 실행할 수 없는 워크스페이스. 사유는 툴팁에 넣는다.
    case brokenWorkspace(name: String, reason: String)
    /// 클릭할 수 없는 안내 문구.
    case notice(String)
    /// 접근성 권한이 없을 때. 누르면 시스템 설정을 연다.
    case permissionNeeded

    public var title: String {
        switch self {
        case .workspace(let name): return name
        case .brokenWorkspace(let name, _): return name
        case .notice(let text): return text
        case .permissionNeeded: return "접근성 권한을 허용하세요"
        }
    }

    public var isEnabled: Bool {
        switch self {
        case .workspace, .permissionNeeded: return true
        case .brokenWorkspace, .notice: return false
        }
    }

    public var tooltip: String? {
        if case .brokenWorkspace(_, let reason) = self { return reason }
        return nil
    }
}

public enum MenuContent {
    /// 레지스트리 조회 결과를 메뉴 항목으로 바꾼다.
    ///
    /// 깨진 config를 목록에서 빼지 않는다. 목록에 없으면 사용자는 파일이 없는 줄 알고
    /// 엉뚱한 곳을 찾는다. CLI의 `restage list`와 같은 원칙이다.
    public static func entries(
        for result: Result<[WorkspaceEntry], Error>, accessibilityGranted: Bool = true
    ) -> [MenuEntry] {
        let workspaces = workspaceEntries(for: result)
        guard accessibilityGranted else { return [.permissionNeeded] + workspaces }
        return workspaces
    }

    private static func workspaceEntries(
        for result: Result<[WorkspaceEntry], Error>
    ) -> [MenuEntry] {
        switch result {
        case .failure(let error):
            return [.notice(firstLine(of: "\(error)"))]
        case .success(let entries) where entries.isEmpty:
            return [.notice("등록된 워크스페이스가 없습니다")]
        case .success(let entries):
            return entries.map { entry in
                guard let error = entry.error else { return .workspace(name: entry.name) }
                return .brokenWorkspace(name: entry.name, reason: error)
            }
        }
    }

    /// 실행 결과 중 실패한 것만 사람이 읽을 형태로 모은다. 실패가 없으면 nil.
    public static func failureSummary(_ outcomes: [ItemOutcome]) -> String? {
        let failures = outcomes.filter { !$0.status.isSuccess }
        guard !failures.isEmpty else { return nil }
        return failures.map { outcome in
            let app = outcome.app?.rawValue ?? outcome.screenID
            return "\(app): \(outcome.detail)"
        }.joined(separator: "\n")
    }

    private static func firstLine(of text: String) -> String {
        text.split(separator: "\n").first.map(String.init) ?? text
    }
}
