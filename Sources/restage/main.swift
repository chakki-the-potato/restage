import Foundation
import RestageKitDarwin

let usage = """
restage — 워크스페이스 복원 도구

사용법:
  restage probe [--slot <slot>] [--app <name>] [--fullscreen] [--warm-only]

옵션:
  --slot <slot>   배치할 위치. 기본값 left-half
  --app <name>    단일 앱만 검증. 기본값은 표본 10종 전부
  --fullscreen    배치 후 전체화면 전환까지 검증
  --warm-only     콜드 스타트를 건너뛴다. 앱을 종료하지 않고 현재 상태 그대로 검증
"""

let arguments = Array(CommandLine.arguments.dropFirst())

guard let command = arguments.first else {
    print(usage)
    exit(2)
}

switch command {
case "probe":
    do {
        let options = try ProbeOptions.parse(Array(arguments.dropFirst()))
        let code = await ProbeCommand.run(options)
        exit(code)
    } catch {
        print(error)
        print("")
        print(usage)
        exit(2)
    }
default:
    print("알 수 없는 명령: \(command)")
    print("")
    print(usage)
    exit(2)
}
