public enum BlankTabs {
    private static let blankURLs: Set<String> = [
        "", "about:blank", "about:newtab", "favorites://",
        "chrome://newtab/", "chrome://new-tab-page/",
        "edge://newtab/", "brave://newtab/", "vivaldi://newtab/",
    ]

    public static func isBlank(_ url: String) -> Bool {
        blankURLs.contains(url.trimmingCharacters(in: .whitespaces).lowercased())
    }

    public static func allBlank(_ urls: [String]) -> Bool {
        !urls.isEmpty && urls.allSatisfy(isBlank)
    }
}
