import Foundation
import AppKit

enum CommandError: Error {
    case invalidArguments
    case itemNotFound
    case accessibilityError

    var message: String {
        switch self {
        case .invalidArguments:
            return "Invalid arguments"
        case .itemNotFound:
            return "Item not found"
        case .accessibilityError:
            return "Accessibility error. Make sure the app has accessibility permissions"
        }
    }

    var exitCode: Int32 {
        switch self {
            case .invalidArguments: return 10
            case .itemNotFound: return 20
            case .accessibilityError: return 30
        }
    }
}

enum CommandName: String {
    case focus = "focus"
    case select = "select"
    case press = "press"
    case menu = "menu"
    case menuToggle = "menu-toggle"
}

private func getFrontmostAppElement() -> AXUIElement? {
    // NOTE: This isn't going to work for overlays like Alfred, but it's probably fine.
    // But in case we need to take care of those too, see WindowWatcher's findFrontmostApp().
    guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
    return AXUIElement.application(app: app)
}

func main() -> Int32 {
    let args = CommandLine.arguments

    // Check if we have at least two arguments (command name and argument).
    // The first of CommandLine.arguments is the executable itself.
    guard args.count >= 3 else {
        print("Error: \(CommandError.invalidArguments.message)")
        return CommandError.invalidArguments.exitCode
    }

    // There has to be an even number of arguments (e.g. pairs of command name and argument)
    guard (args.count - 1) % 2 == 0 else {
        print("Error: \(CommandError.invalidArguments.message)")
        return CommandError.invalidArguments.exitCode
    }

    // Get the frontmost application
    guard let app = getFrontmostAppElement() else {
        print("Error: \(CommandError.accessibilityError.message)")
        return CommandError.accessibilityError.exitCode
    }
    
    var success = true

    var i = 1
    while i + 1 < args.count {
        guard let cmd = CommandName(rawValue: args[i]) else {
            print("Error: \(CommandError.invalidArguments.message)")
            return CommandError.invalidArguments.exitCode
        }

        let arg = args[i + 1]

        switch cmd {
            case .focus:
                success = success && UIElementManipulator.focusElement(inApp: app, cliArg: arg)
            case .select:
                success = success && UIElementManipulator.selectElement(inApp: app, cliArg: arg)
            case .press:
                success = success && UIElementManipulator.pressElement(inApp: app, cliArg: arg)
            case .menu:
                success = success && MenuItemManipulator.pressMenuItems(inApp: app, cliArg: arg)
            case .menuToggle:
                success = success && MenuItemManipulator.toggleMenuItems(inApp: app, cliArg: arg)
        }

        i += 2
    }
    
    guard success else {
        return CommandError.itemNotFound.exitCode
    }

    return 0
}

// Actually run the main function
exit(main())
