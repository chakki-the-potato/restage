import Foundation
import RestageKitDarwin

let usage = """
restage — 워크스페이스 복원 도구

사용법:
  restage open <name|path>
  restage list
  restage menubar
  restage probe [--slot <slot>] [--app <name>] [--fullscreen] [--warm-only]

open 옵션:
  <name|path>     워크스페이스 이름 또는 config 파일 경로
                  이름은 ~/.config/restage/<이름>.yaml 에서 찾습니다

menubar:
  메뉴바에 아이콘을 띄우고 워크스페이스를 클릭해 실행합니다
  종료하려면 메뉴에서 종료를 누르세요

probe 옵션:
  --slot <slot>   배치할 위치. 기본값 left-half
  --app <name>    단일 앱만 검증. 기본값은 표본 전부
  --fullscreen    배치 후 전체화면 전환까지 검증
  --warm-only     콜드 스타트를 건너뛴다. 앱을 종료하지 않고 현재 상태 그대로 검증
"""

AppKitBootstrap.ensureGUIApplication()

let arguments = Array(CommandLine.arguments.dropFirst())

guard let command = arguments.first else {
    if LaunchContext.isInsideAppBundle { MenuBarCommand.run() }
    print(usage)
    exit(2)
}

switch command {
case "open":
    guard arguments.count >= 2 else {
        print("open 뒤에 워크스페이스 이름 또는 config 파일 경로가 필요합니다")
        print("")
        print(usage)
        exit(2)
    }
    let code = await OpenCommand.run(target: arguments[1])
    exit(code)
case "menubar":
    MenuBarCommand.run()
case "list":
    exit(ListCommand.run())
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
