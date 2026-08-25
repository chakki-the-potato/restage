import Foundation
import RestageKit
import RestageKitDarwin
import SwiftUI

@MainActor
final class PanelStore: ObservableObject {
    struct Item: Identifiable, Equatable {
        var id: String { name }
        let name: String
        let summary: WorkspaceSummary?
        let error: String?
        let hotkey: String?
        let hotkeySpec: HotkeySpec?
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
    @Published private(set) var progress: RunProgress?
    @Published private(set) var messages: [String: String] = [:]
    @Published private(set) var accessibilityGranted = true
    @Published private(set) var listError: String?
    @Published private(set) var loginItemEnabled = false

    let loginItemSupported = LoginItem.isSupported

    init() {}

    init(items: [Item]) {
        self.items = items
    }

    private let hotkeys = HotkeyRegistry()
    private var registrations: [String: HotkeyRegistry.Registration] = [:]

    func installHotkeys() {
        hotkeys.install { [weak self] workspace in
            self?.run(workspace)
        }
        reload()
    }

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
            return L10n.string("error.hotkey.conflict", spec.displayString)
        case .registered, nil:
            return nil
        }
    }
}
