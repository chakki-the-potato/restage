import ApplicationServices

@MainActor
public final class WindowClaims {
    private var claimed: Set<AXUIElement> = []

    public init() {}

    func contains(_ window: AXWindow) -> Bool {
        claimed.contains(window.element)
    }

    func claim(_ window: AXWindow) {
        claimed.insert(window.element)
    }
}
