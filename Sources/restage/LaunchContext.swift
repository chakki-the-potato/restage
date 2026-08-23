import Foundation

/// 앱 번들 안에서 실행됐는지 판별한다.
///
/// 번들에서 실행되면 인자 없이도 메뉴바를 띄운다. Finder에서 더블클릭하거나
/// 로그인 항목으로 실행될 때는 인자가 오지 않기 때문이다.
/// 터미널에서 실행하면 번들 밖이므로 기존대로 usage를 출력한다.
enum LaunchContext {
    static var isInsideAppBundle: Bool {
        Bundle.main.bundleIdentifier != nil
            && Bundle.main.bundlePath.hasSuffix(".app")
    }
}
