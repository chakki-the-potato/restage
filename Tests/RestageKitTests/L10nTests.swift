import Foundation
import Testing

@testable import RestageKit

private func table(_ code: String) -> [String: String] {
    guard let lproj = L10n.resourcesForTesting?.path(forResource: code, ofType: "lproj"),
          let dictionary = NSDictionary(
            contentsOf: URL(fileURLWithPath: lproj + "/Localizable.strings"))
            as? [String: String]
    else {
        Issue.record("\(code).lproj/Localizable.strings를 읽지 못했습니다")
        return [:]
    }
    return dictionary
}

private func specifiers(_ text: String) -> [Int: String] {
    let pattern = /%(?:(\d+)\$)?([@a-zA-Z])/
    var found: [Int: String] = [:]
    var next = 1
    for match in text.matches(of: pattern) {
        let type = String(match.2)
        if let explicit = match.1, let index = Int(explicit) {
            found[index] = type
        } else {
            found[next] = type
            next += 1
        }
    }
    return found
}

@Test func everyEnglishKeyHasAKoreanTranslation() {
    let english = table("en")
    let korean = table("ko")
    #expect(!english.isEmpty)

    let missing = Set(english.keys).subtracting(korean.keys).sorted()
    #expect(missing.isEmpty, "번역이 빠진 키: \(missing.joined(separator: ", "))")
}

@Test func koreanHasNoKeyMissingFromEnglish() {
    let extra = Set(table("ko").keys).subtracting(table("en").keys).sorted()
    #expect(extra.isEmpty, "영어에 없는 키: \(extra.joined(separator: ", "))")
}

@Test func formatSpecifiersMatchAcrossLanguages() {
    let korean = table("ko")
    for (key, english) in table("en") {
        guard let translated = korean[key] else { continue }
        #expect(
            specifiers(english) == specifiers(translated),
            "'\(key)'의 서식 지정자가 다릅니다: \(english) / \(translated)")
    }
}

@Suite(.serialized)
struct LanguageSelectionTests {
    @Test func lookupFollowsTheChosenLanguage() {
        let original = L10n.language
        defer { L10n.language = original }

        L10n.language = .english
        #expect(L10n.string("panel.retry") == "Retry")

        L10n.language = .korean
        #expect(L10n.string("panel.retry") == "다시 시도")
    }

    @Test func unknownKeyFallsBackToItself() {
        let original = L10n.language
        defer { L10n.language = original }

        L10n.language = .korean
        #expect(L10n.string("no.such.key") == "no.such.key")
    }
}
