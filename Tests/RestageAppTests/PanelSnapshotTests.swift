import AppKit
import RestageKit
import SwiftUI
import Testing

@testable import restage

/// 패널을 화면 없이 PNG로 그려 눈으로 보는 도구.
///
/// 메뉴바 팝오버는 화면 기록 권한 없이는 캡처할 수 없어서 손으로 확인할 방법이 없었다.
/// `ImageRenderer`로 그리면 권한도 창도 필요 없다. 실제로 이 도구가 진행 막대와
/// '다시 시도'가 AppKit 컨트롤이라 정해둔 크기와 색이 나오지 않는 것을 잡아냈다.
///
///     RESTAGE_SNAPSHOT_DIR=/tmp/shots swift test --filter renderPanel
private let snapshotDirectory = ProcessInfo.processInfo.environment["RESTAGE_SNAPSHOT_DIR"]

@MainActor
@Test(.enabled(if: snapshotDirectory != nil))
func renderPanelForReview() throws {
    let out = try #require(snapshotDirectory)

    func item(
        _ name: String, apps: [String], shape: LayoutShape, screens: Int = 1, hotkey: String? = nil
    ) -> PanelStore.Item {
        PanelStore.Item(
            name: name,
            summary: WorkspaceSummary(
                apps: apps.map { AppID($0) }, shape: shape,
                screenCount: screens, itemCount: apps.count),
            error: nil, hotkey: hotkey, hotkeySpec: nil, hotkeyWarning: nil)
    }

    let dev = item("dev", apps: ["Safari", "Notion"], shape: .leftRight)
    let research = item("research", apps: ["Music"], shape: .fullScreen, hotkey: "⌃⌥⌘2")
    let design = item(
        "design", apps: ["Safari", "Notion", "Music", "Mail", "Calendar"],
        shape: .leftRight, screens: 3, hotkey: "⌃⌥⌘4")
    let missing = item("planning", apps: ["Zed"], shape: .single(.leftHalf))

    func card(
        _ value: PanelStore.Item, running: Bool = false, progress: RunProgress? = nil,
        message: String? = nil
    ) -> some View {
        WorkspaceCard(
            item: value, isRunning: running, isBusy: false, progress: progress, message: message,
            onRun: {}, onEdit: {}, onToggleActions: {}, onDismissMessage: {})
    }

    let sheet = VStack(alignment: .leading, spacing: 6) {
        card(dev)
        card(research)
        card(design)
        card(missing)
        card(
            dev, running: true,
            progress: RunProgress(
                phase: .launching, app: AppID("Notion"), completed: 1, total: 2))
        card(research, message: L10n.string("error.engine.no_windows_open"))
        HStack {
            Spacer()
            LanguagePill(setting: LanguageSetting())
        }
    }
    .padding(12)
    .frame(width: 320)
    .background(Color(nsColor: .windowBackgroundColor))

    let panel = WorkspacePanel(
        store: PanelStore(), dismiss: {}, reopen: {}, presentMenu: { _, _ in }, onQuit: {})

    try write(sheet, to: out + "/cards-light.png", dark: false)
    try write(sheet, to: out + "/cards-dark.png", dark: true)
    try write(panel, to: out + "/panel-light.png", dark: false)
    try write(panel, to: out + "/panel-dark.png", dark: true)
}

@MainActor
private func write(_ view: some View, to path: String, dark: Bool) throws {
    let appearance = try #require(NSAppearance(named: dark ? .darkAqua : .aqua))
    var png: Data?
    appearance.performAsCurrentDrawingAppearance {
        let renderer = ImageRenderer(
            content: view.environment(\.colorScheme, dark ? .dark : .light))
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff)
        else { return }
        png = bitmap.representation(using: .png, properties: [:])
    }
    try #require(png).write(to: URL(fileURLWithPath: path))
}
