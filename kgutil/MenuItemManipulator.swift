import Foundation
import AppKit

struct MenuItemManipulator {

    private struct MenuAction {
        enum Action {
            case press
            case uncheck
            case check
        }

        let path: [String]
        let action: Action
    }

    static func pressMenuItems(inApp app: AXUIElement, cliArg: String) -> Bool {
        let cmds = parseCLIArgument(cliArg)

        var success = true

        for cmd in cmds {
            guard let item = app.findMenuItem(path: cmd.path) else { continue }
            success = success && performAction(cmd.action, item)
        }

        return success
    }

    // Sometimes it's important we get a list of menu items first, and only then perform the
    // actions. For instance, if a menu item changes its name depending on the state, we need to
    // provide both names, but only press the one that's currently active.
    static func toggleMenuItems(inApp app: AXUIElement, cliArg: String) -> Bool {
        let cmds = parseCLIArgument(cliArg)

        var success = true

        let items = cmds.map { cmd in
            return app.findMenuItem(path: cmd.path)
        }
        for (item, cmd) in zip(items, cmds) {
            guard let item else { continue }
            success = success && performAction(cmd.action, item)
        }

        return success
    }

    static private func performAction(_ action: MenuAction.Action, _ item: AXUIElement) -> Bool {
        switch action {
            case .press:
                return item.press()
            case .check:
                return item.setChecked(true)
            case .uncheck:
                return item.setChecked(false)
        }
    }

    // Example format: "Menu>ItemA;Menu>ItemB:1;Menu>ItemC:0"
    // In this case ItemA with be pressed, ItemB checked, and ItemC unchecked.
    private static func parseCLIArgument(_ arg: String) -> [MenuAction] {
        let paths = arg.split(separator: ";")

        guard !paths.isEmpty else { return [] }

        return paths.map { path in
            let parts = path.split(separator: ":")

            assert(
                parts.count <= 1 || parts[1] == "1" || parts[1] == "0",
                "Unexpected path action: \(parts[1])"
            )

            return MenuAction(
                path: parts[0].split(separator: ">").map { String($0) },
                action: parts.count <= 1 ? .press : parts[1] == "0" ? .uncheck : .check
            )
        }
    }
}
