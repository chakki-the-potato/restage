import Foundation
import RestageKit
import RestageKitDarwin
import SwiftUI

/// 패널이 그리는 상태.
///
/// 화면과 분리하는 이유는 목록 갱신, 단축키 등록, 실행 중 표시가 서로 얽히기 때문이다.
/// 뷰는 이 값을 읽어 그리기만 한다.
@MainActor
final class PanelStore: ObservableObject {
    struct Item: Identifiable, Equatable {
        var id: String { name }
        let name: String
        let summary: WorkspaceSummary?
        /// config를 읽지 못한 사유. 있으면 실행할 수 없다.
        let error: String?
        /// 등록된 단축키 표시 문자열.
        let hotkey: String?
        /// config에 적힌 단축키. 설정 창에 현재 값을 채우는 데 쓴다.
        let hotkeySpec: HotkeySpec?
        /// 단축키를 등록하지 못한 사유.
        let hotkeyWarning: String?

        var isRunnable: Bool { error == nil }

        var subtitle: String {
            if let error { return firstLine(of: error) }
            guard let summary else { return "" }
            return LayoutSummaryLabel.text(summary)
        }

        private func firstLine(of text: String) -> String {
            text.split(separator: "\n").first.map(String.init) ?? text
        }
    }

    @Published private(set) var items: [Item] = []
    @Published private(set) var runningName: String?
    /// 실행 중인 워크스페이스가 어디까지 갔는지.
    @Published private(set) var progress: RunProgress?
    /// 워크스페이스별 마지막 실패 사유. 성공하면 지운다.
    @Published private(set) var messages: [String: String] = [:]
    @Published private(set) var accessibilityGranted = true
    @Published private(set) var listError: String?
    @Published private(set) var loginItemEnabled = false

    let loginItemSupported = LoginItem.isSupported

    private let hotkeys = HotkeyRegistry()
    private var registrations: [String: HotkeyRegistry.Registration] = [:]

    func installHotkeys() {
        hotkeys.install { [weak self] workspace in
            self?.run(workspace)
        }
        reload()
    }

    /// 패널을 열 때마다 다시 읽는다. config 파일을 직접 고치는 것도 이 도구의 편집 방식이라
    /// 한 번만 읽으면 앱을 재시작해야 한다.
    func reload() {
        accessibilityGranted = AccessibilityPermission.isTrusted()
        loginItemEnabled = LoginItem.isEnabled

        let entries: [WorkspaceEntry]
        do {
            entries = try WorkspaceRegistry().list()
            listError = nil
        } catch {
            entries = []
            listError = "\(error)".split(separator: "\n").first.map(String.init) ?? "\(error)"
        }

        let declared = declaredHotkeys(in: entries)
        registrations = hotkeys.reload(declared)
        let specs = Dictionary(
            uniqueKeysWithValues: declared.compactMap { entry -> (String, HotkeySpec)? in
                guard let spec = try? HotkeySpec.parse(entry.raw) else { return nil }
                return (entry.workspace, spec)
            })
        items = entries.map { entry in
            Item(
                name: entry.name,
                summary: entry.summary,
                error: entry.error,
                hotkey: hotkeyLabel(for: entry.name),
                hotkeySpec: specs[entry.name],
                hotkeyWarning: hotkeyWarning(for: entry.name))
        }
        messages = messages.filter { key, _ in entries.contains { $0.name == key } }
    }

    func run(_ name: String) {
        guard runningName == nil else { return }
        runningName = name
        messages[name] = nil

        Task { @MainActor in
            let outcome = await WorkspaceLauncher.run(name) { [weak self] step in
                self?.progress = step
            }
            runningName = nil
            progress = nil
            messages[name] = outcome.message
            reload()
        }
    }

    func dismissMessage(for name: String) {
        messages[name] = nil
    }

    func toggleLoginItem() {
        if let reason = LoginItem.toggle() {
            Prompt.message(L10n.string("error.login_item"), reason)
        }
        loginItemEnabled = LoginItem.isEnabled
    }

    // MARK: - 단축키

    private func declaredHotkeys(
        in entries: [WorkspaceEntry]
    ) -> [(workspace: String, raw: String)] {
        entries.compactMap { entry in
            guard entry.error == nil,
                  let config = try? ConfigLoader.load(path: entry.path),
                  let raw = config.hotkey else { return nil }
            return (entry.name, raw)
        }
    }

    private func hotkeyLabel(for workspace: String) -> String? {
        guard case .registered(let spec) = registrations[workspace] else { return nil }
        return spec.displayString
    }

    private func hotkeyWarning(for workspace: String) -> String? {
        switch registrations[workspace] {
        case .invalid(let reason):
            return reason
        case .conflicted(let spec):
            return "단축키 \(spec.displayString)를 등록하지 못했습니다. 다른 앱이 쓰고 있거나 중복입니다"
        case .registered, nil:
            return nil
        }
    }
}
