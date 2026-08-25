import Foundation

enum Console {
    static var isInteractive: Bool { isatty(FileHandle.standardInput.fileDescriptor) == 1 }

    static func ask(_ prompt: String) -> String? {
        print(prompt, terminator: "")
        fflush(stdout)
        return readLine(strippingNewline: true)
    }

    static func confirm(_ question: String) -> Bool {
        guard let answer = ask("\(question) [y/N] ") else { return false }
        return ["y", "yes"].contains(answer.trimmingCharacters(in: .whitespaces).lowercased())
    }
}
