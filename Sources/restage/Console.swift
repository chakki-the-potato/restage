import Foundation

/// 터미널 입출력. 대화형 명령이 표준 입력을 읽는 경로를 한곳에 모은다.
enum Console {
    /// 표준 입력이 터미널이 아니면 대화형 흐름을 쓸 수 없다.
    /// 파이프로 입력을 흘려넣는 검증에서는 true가 아니므로 호출자가 분기하지 않도록
    /// 판정만 제공하고 동작은 바꾸지 않는다.
    static var isInteractive: Bool { isatty(FileHandle.standardInput.fileDescriptor) == 1 }

    /// 질문을 출력하고 한 줄을 읽는다. 입력이 끝나면 nil이다.
    static func ask(_ prompt: String) -> String? {
        print(prompt, terminator: "")
        fflush(stdout)
        return readLine(strippingNewline: true)
    }

    /// 되돌릴 수 없는 동작 앞에서 확인을 받는다. 기본값은 항상 거부다.
    static func confirm(_ question: String) -> Bool {
        guard let answer = ask("\(question) [y/N] ") else { return false }
        return ["y", "yes"].contains(answer.trimmingCharacters(in: .whitespaces).lowercased())
    }
}
