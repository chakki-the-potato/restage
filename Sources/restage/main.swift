import Foundation
import RestageKit
import RestageKitDarwin

let usage = """
restage — 워크스페이스 복원 도구

사용법:
  restage new <name>
  restage open <name|path>
  restage list
  restage menubar
  restage probe [--slot <slot>] [--app <name>] [--fullscreen] [--cold]

new:
  지금 열린 창 배치를 읽어 워크스페이스를 만듭니다
  보여주는 목록을 고친 뒤 Enter를 누르면 저장됩니다

open 옵션:
  <name|path>     워크스페이스 이름 또는 config 파일 경로
                  이름은 ~/.config/restage/<이름>.yaml 에서 찾습니다

menubar:
  메뉴바에 아이콘을 띄우고 워크스페이스를 클릭해 실행합니다
  종료하려면 메뉴에서 종료를 누르세요

probe 옵션:
  --slot <slot>   배치할 위치. 기본값 left-half
  --app <name>    단일 앱만 검증. 기본값은 실행 중인 앱 전부
  --fullscreen    배치 후 전체화면 전환까지 검증
  --cold          콜드 스타트까지 검증. 대상 앱을 강제 종료하므로 --app이 필요하고
                  실행 전에 확인을 받는다
"""

AppKitBootstrap.ensureGUIApplication()

let arguments = Array(CommandLine.arguments.dropFirst())

guard let command = arguments.first else {
    if LaunchContext.isInsideAppBundle { MenuBarCommand.run() }
    print(usage)
    exit(2)
}

switch command {
case "new":
    guard arguments.count >= 2 else {
        print(L10n.string("cli.new.needs_name"))
        print("")
        print(usage)
        exit(2)
    }
    exit(NewCommand.run(name: arguments[1]))
case "open":
    guard arguments.count >= 2 else {
        print(L10n.string("cli.open.needs_target"))
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
    print(L10n.string("cli.unknown_command", command))
    print("")
    print(usage)
    exit(2)
}
