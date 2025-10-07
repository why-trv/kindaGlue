import Foundation
import AppKit
import HotKey

struct Config {

    /// The keys here can be one of KVWatcher.Mode, Engine.Mode, ZMKWatcher.Layer
    static let modeColors: [String: NSColor] = [
        KindaVim.Mode.normal.rawValue: NSColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 0.3),
        KindaVim.Mode.visual.rawValue: NSColor(red: 0.5, green: 0.0, blue: 0.5, alpha: 0.3),
        Engine.Mode.autoRevert.rawValue: NSColor(red: 0.0, green: 0.5, blue: 0.5, alpha: 0.3),
        Engine.Mode.manual.rawValue: NSColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 0.3),
        Engine.Mode.input.rawValue: NSColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 0.3),
        ZMKWatcher.Layer.nav.rawValue: NSColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 0.3),
        ZMKWatcher.Layer.sym.rawValue: NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.3)
    ]

    /// Apps that won't be considered for frontmost app
    static let excludedFrontmostApps = [
        "Hammerspoon",
        "Homerow",
        "Karabiner-EventViewer",
        "KeyCastr",
        "Accessibility Inspector",
        "kindaGlue"
    ]

    /// Apps that *will* be considered for frontmost *overlay* apps
    static let includedOverlayApps = [
        "Homerow"
    ]

    // Ctrl-[
    static let kindaVimNormalModeShortcut = OutgoingShortcutDefinition(key: 33, modifiers: .maskControl)
    // v
    static let kindaVimVisualModeShortcut = OutgoingShortcutDefinition(key: 9, modifiers: CGEventFlags())

    /// ZMK layer 'detection' hotkeys
    struct ZMKLayers {
        private static let hyper: NSEvent.ModifierFlags = [.control, .option, .command, .shift]

        static let navOn = IncomingShortcutDefinition(key: .f4, modifiers: hyper)
        static let navOff = IncomingShortcutDefinition(key: .f5, modifiers: hyper)
        static let symOn = IncomingShortcutDefinition(key: .f6, modifiers: hyper)
        static let symOff = IncomingShortcutDefinition(key: .f7, modifiers: hyper)
    }
}


