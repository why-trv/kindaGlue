import AppKit

struct UIElementManipulator {

    static func focusElement(inApp app: AXUIElement, cliArg: String) -> Bool {
        guard let element = findElement(app: app, cliArg: cliArg) else { return false }
        return element.focus()
    }

    static func selectElement(inApp app: AXUIElement, cliArg: String) -> Bool {
        guard let element = findElement(app: app, cliArg: cliArg) else { return false }
        // NOTE: We're actually looking for the nearest ancestor that is selectable,
        // should we do the same for focus?
        return element.findSelectableAncestor()?.select() ?? false
    }

    static func pressElement(inApp app: AXUIElement, cliArg: String) -> Bool {
        guard let element = findElement(app: app, cliArg: cliArg) else { return false }
        return element.press()
    }

    private static func findElement(app: AXUIElement, cliArg: String) -> AXUIElement? {
        guard let selector = parseCLIArgument(cliArg) else { return nil }
        return app.findDescendant(selector: selector)
    }

    private static func parseCLIArgument(_ arg: String) -> AXUIElement.Selector? {
        let items = arg.split(separator: ";", omittingEmptySubsequences: false)
        guard !items.isEmpty else { return nil }

        let item: (Int) -> String? = { idx in
            guard items.count > idx, !items[idx].isEmpty else { return nil }
            return String(items[idx])
        }

        return AXUIElement.Selector(
            role: item(0),
            subrole: item(1),
            identifier: item(2),
            title: item(3),
            value: item(4),
            label: item(5),
            allowedAncestorRoles: item(6)?.split(separator: ",").map({ String($0) }) ?? []
        )
    }
}
