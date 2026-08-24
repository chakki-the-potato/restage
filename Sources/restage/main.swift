import Foundation
import RestageKit
import RestageKitDarwin

let usage = L10n.string("cli.usage")

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
