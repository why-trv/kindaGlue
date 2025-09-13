import Foundation
import AppKit
import OSLog

public extension AXUIElement {

    struct Selector {
        let role: String?
        let subrole: String?
        let identifier: String?
        let title: String?
        let value: String?
        let label: String?
        let allowedAncestorRoles: [String]
    }

    // --

    /// Gets the AXUIElement for an application by process ID
    static func application(pid: pid_t) -> AXUIElement {
        return AXUIElementCreateApplication(pid)
    }

    /// Gets the AXUIElement for a NSRunningApplication
    static func application(app: NSRunningApplication) -> AXUIElement {
        return AXUIElement.application(pid: app.processIdentifier)
    }

    /// Gets the system-wide AXUIElement
    static var systemWide: AXUIElement {
        return AXUIElementCreateSystemWide()
    }

    /// Gets the focused application from the system-wide element
    static var focusedApplication: AXUIElement? {
        guard let value = AXUIElement.systemWide.getAttribute(kAXFocusedApplicationAttribute as String) else {
            return nil
        }
        return (value as! AXUIElement)
    }

    //--

    func getAttribute(_ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(self, attribute as CFString, &value)

        guard result == .success else { return nil }
        return value
    }

    func getStringAttribute(_ attribute: String) -> String {
        guard let value = getAttribute(attribute) else { return "" }
        return value as? String ?? ""
    }

    func getBooleanAttribute(_ attribute: String) -> Bool {
        guard let value = getAttribute(attribute) else { return false }
        return value as? Bool ?? false
    }

    func isAttributeSettable(_ attribute: String) -> Bool {
        var isSettable = DarwinBoolean(false)
        let error = AXUIElementIsAttributeSettable(self, attribute as CFString, &isSettable)
        return error == .success && isSettable.boolValue
    }

    func setAttribute(_ attribute: String, value: CFTypeRef) -> Bool {
        return AXUIElementSetAttributeValue(self, attribute as CFString, value) == .success
    }

    //--

    var parent: AXUIElement? {
        guard let value = getAttribute(kAXParentAttribute as String) else { return nil }
        return (value as! AXUIElement)
    }

    var children: [AXUIElement] {
        guard let value = getAttribute(kAXChildrenAttribute as String) else { return [] }
        return value as! [AXUIElement]
    }

    var role: String {
        return getStringAttribute(kAXRoleAttribute as String)
    }

    var subrole: String {
        return getStringAttribute(kAXSubroleAttribute as String)
    }

    var title: String {
        return getStringAttribute(kAXTitleAttribute as String)
    }

    var value: String {
        return getStringAttribute(kAXValueAttribute as String)
    }

    var identifier: String {
        return getStringAttribute(kAXIdentifierAttribute as String)
    }

    var label: String {
        return getStringAttribute(kAXLabelValueAttribute as String)
    }

    var actions: [String] {
        var cfArray: CFArray?
        let error = AXUIElementCopyActionNames(self as AXUIElement, &cfArray)
        guard error == .success, let array = cfArray as? [String] else { return [] }
        return array
    }

    var isModalOrDialog: Bool {
        return role == kAXSheetRole ||
               subrole == kAXDialogSubrole ||
               subrole == kAXSystemDialogSubrole
    }

    var isApplication: Bool {
        return role == kAXApplicationRole;
    }

    //--

    func press() -> Bool {
        return AXUIElementPerformAction(self, kAXPressAction as CFString) == .success
    }

    var isFocusable: Bool {
        return isAttributeSettable(kAXFocusedAttribute as String)
    }

    func focus() -> Bool {
        return setAttribute(kAXFocusedAttribute as String, value: kCFBooleanTrue)
    }

    var isSelectable: Bool {
        return isAttributeSettable(kAXSelectedAttribute as String)
    }

    func select() -> Bool {
        return setAttribute(kAXSelectedAttribute as String, value: kCFBooleanTrue)
    }

    /// Returns whether the menu item is checked
    var isChecked: Bool {
        if let markChar = getAttribute(kAXMenuItemMarkCharAttribute as String) as? String, !markChar.isEmpty {
            return true
        }
        return false
    }

    func setChecked(_ checked: Bool) -> Bool {
        guard checked != self.isChecked else { return true }
        return press()
    }

    // --

    /// Gets the focused element (for an application element)
    var focusedElement: AXUIElement? {
        // assert(isApplication || role.isEmpty, "Windows are only available for application elements (\(kAXApplicationRole)) or empty, while this one is a \(role)")
        assert(isApplication || role.isEmpty, "Windows are only available for application elements (\(kAXApplicationRole)), while this one is a \(role)")
        guard let value = getAttribute(kAXFocusedUIElementAttribute as String) else { return nil }
        return (value as! AXUIElement)
    }

    /// Gets the menu bar element (for an application element)
    var menuBar: AXUIElement? {
        assert(isApplication || role.isEmpty, "Menu bar is only available for application elements (\(kAXApplicationRole)), while this one is a \(role)")
        guard let value = getAttribute(kAXMenuBarAttribute as String) else { return nil }
        return (value as! AXUIElement)
    }

    /// Gets all windows (for an application element)
    var windows: [AXUIElement] {
        guard let value = getAttribute(kAXWindowsAttribute as String) else { return [] }
        return value as! [AXUIElement]
    }

    /// Gets the process ID from an AXUIElement
    var pid: pid_t? {
        var pid: pid_t = 0
        let result = AXUIElementGetPid(self, &pid)
        return (result == .success) ? pid : nil
    }

    /// Gets the NSRunningApplication corresponding to an AXUIElement
    var runningApplication: NSRunningApplication? {
        guard let pid = self.pid else { return nil }
        return NSRunningApplication(processIdentifier: pid)
    }

    // --

    func findDescendant(selector s: Selector) -> AXUIElement? {
        let ownRole = self.role
        var matched = true

        if let role = s.role, ownRole != role { matched = false }
        else if let subrole = s.subrole, self.subrole != subrole { matched = false }
        else if let identifier = s.identifier, self.identifier != identifier { matched = false }
        else if let title = s.title, self.title != title { matched = false }
        else if let value = s.value, self.value != value { matched = false }
        else if let label = s.label, self.label != label { matched = false }

        if matched {
            return self
        }

        // If the ancestor roles passlist is provided and the element doesn't match, don't go any further
        if !s.allowedAncestorRoles.isEmpty,
           !ownRole.isEmpty,
           !s.allowedAncestorRoles.contains(ownRole) {
            return nil
        }

        for child in self.children {
            if let found = child.findDescendant(selector: s) {
                return found
            }
        }

        return nil
    }

    func findAncestor(passingTest test: (AXUIElement) -> Bool) -> AXUIElement? {
        var parent = self.parent

        while parent != nil {
            if test(parent!) {
                return parent
            }
            parent = parent?.parent
        }

        return nil
    }

    func findSelectableAncestor() -> AXUIElement? {
        return findAncestor(passingTest: { $0.isSelectable })
    }

    /// Finds a menu item by following a path of menu titles
    func findMenuItem(path: [String]) -> AXUIElement? {
        guard !path.isEmpty, let menuBar else {
            return nil
        }

        var menu: AXUIElement = menuBar
        var item: AXUIElement? = nil
        let count = path.count

        for (idx, title) in path.enumerated() {
            item = menu.children.first(where: { $0.title == title })
            guard let item else {
                // Item not found
                return nil
            }

            guard idx < count - 1 else {
                // This is the last path component, return
                return item
            }

            // I guess we don't need to check that child role is kAXMenuRole here,
            // so can just grab the first one
            guard let submenu = item.children.first else {
                // We still haven't walked the entire path, but alas, there's no submenu
                return nil
            }

            menu = submenu
        }

        return item
    }
}
