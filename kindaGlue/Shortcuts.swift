import AppKit
import HotKey

struct IncomingShortcutDefinition {
    let key: Key
    let modifiers: NSEvent.ModifierFlags

    typealias Handler = () -> Void

    func createHotKey(handler: @escaping Handler) -> HotKey {
        let hk = HotKey(key: key, modifiers: modifiers)
        hk.keyDownHandler = handler
        return hk
    }
}

struct OutgoingShortcutDefinition {
    let key: CGKeyCode
    let modifiers: CGEventFlags

    func post() {
        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: false)

        guard let keyUp, let keyDown else {
            return
        }

        keyDown.flags = modifiers
        keyUp.flags = modifiers

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
