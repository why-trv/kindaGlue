import AppKit
import Foundation
import OSLog

final class Engine {

    /// Mode defines how kindaGlue should handle situations where kindaVim is in insert
    /// (i.e. OS default) mode, but the app needs to behave somewhat differently.
    /// - off: kindaGlue doesn't mess with anything
    /// - manual: kindaGlue waits for kindaVim to go to normal mode, then goes to 'off' mode.
    ///   Say, a normal mode keybinding in KE sends a bunch of shortcuts to an app (making
    ///   kindaVim go to insert mode), and we want the overlay to look as if we're in normal mode
    ///   all this time. We just set the 'manual' color the same as 'normal', and make KE send
    ///   send the normal mode shortcut at the end.
    /// - autoRevert: kindaGlue waits for an overlay (only supported for Homerow at the moment)
    ///   to disappear, then sends a shortcut to kindaVim to go to normal mode (and goes to 'off'
    ///   mode as a result). In this case KE doesn't need to send the normal mode shortcut.
    /// - field: Functionally the same as 'manual', but intended for text input fields. You
    ///   may want to set a different overlay color for this, and have a conditional mapping where
    ///   e.g. ⎋ maps to ⎋<normal mode> and ↩ to ↩<normal mode>. In other words, 'manual' is meant
    ///   for a brief shorcut or shorcut sequence to act as if we've never left normal mode, while
    ///   'field' is meant for some deliberate user input.
    enum Mode: String {
        case off = ""
        case manual = "manual"
        case autoRevert = "auto"
        case input = "input"
    }

    private typealias Variables = Karabiner.Variables

    private var zmk = ZMKWatcher()
    private var overlay = Overlay()
    private var kvWatcher = KindaVim()
    private var karabiner = Karabiner()
    private var windowObserver = WindowWatcher()
    private var axWatcher = AXWatcher()
    private var homerowObserver = HomerowWatcher()
    private var axAccess = AXAccess()
    private var appModeKeeper = AppModeKeeper()

    private var mode = Mode.off

    init() {
        zmk.onLayerChanged = zmkLayerChanged
        zmk.start()

        kvWatcher.onModeChanged = kvModeChanged
        kvWatcher.start()

        windowObserver.onWindowChanged = windowChanged

        axWatcher.onAccessibilityChanged = accessibilityChanged

        homerowObserver.onHomerowDidAppear = homerowDidAppearOrChange
        homerowObserver.onHomerowDidChange = homerowDidAppearOrChange
        homerowObserver.onHomerowDidDisappear = homerowDidDisappear

        if axAccess.requestPermissions() {
            windowObserver.start()
            homerowObserver.start()
            observeFrontmostApp()
        }
    }

    /// Reads and update the mode from Karabiner variables
    @discardableResult
    private func pullMode() -> Mode {
        guard let str = karabiner.getStringVariable(Variables.mode) else {
            Logger.general.error("Couldn't pull mode from Karabiner variables")
            mode = Mode.off
            return mode
        }

        mode = Mode(rawValue: str) ?? Mode.off
        return mode
    }

    private func observeFrontmostApp() {
        if let frontmostApp = windowObserver.frontmostApp {
            axWatcher.observe(frontmostApp)
        }
    }

    private func updateOverlay() {
        let mode = getOverlayMode()
        overlay.color = Config.modeColors[mode] ?? NSColor.clear
    }

    func getOverlayMode() -> String {
        if case let layer = zmk.getCurrentLayer(), layer != ZMKWatcher.Layer.none {
            return layer.rawValue
        }
        if mode != .off {
            return mode.rawValue
        }
        return kvWatcher.mode.rawValue
    }

    private func zmkLayerChanged(layer: ZMKWatcher.Layer) {
        updateOverlay()
    }

    private func kvModeChanged(kvMode: KindaVim.Mode) {
        if kvMode == KindaVim.Mode.insert {
            pullMode()
        } else if mode != .off, kvMode == KindaVim.Mode.normal {
            mode = .off
            karabiner.pushVariable(Variables.mode, value: mode.rawValue)
        }

        saveAppMode()
        updateOverlay()
    }

    private func windowChanged() {
        recallAppMode()

        let app = windowObserver.frontmostApp

        let frontmostApp = windowObserver.frontmostAppName
        let overlayApp = windowObserver.overlayAppName
        let windowIdentifier = windowObserver.frontmostWindowIdentifier
        let family = app == nil ? .none : kvWatcher.family(for: app!)

        // Only observe frontmost app if we have accessibility permissions
        if axAccess.arePermissionsGranted() {
            observeFrontmostApp()
        }

        karabiner.stageVariable(Variables.frontmostWindowApp, value: frontmostApp)
        karabiner.stageVariable(Variables.overlayWindowApp, value: overlayApp)
        karabiner.stageVariable(Variables.windowIdentifier, value: windowIdentifier)
        karabiner.stageVariable(Variables.frontmostAppFamily, value: family.rawValue)
        karabiner.pushStagedVariables()
    }

    private func accessibilityChanged() {
        let modalRole = axWatcher.modalElementRole
        let focusedRole = axWatcher.focusedElementRole
        let focusedSubrole = axWatcher.focusedElementSubrole
        let focusedPlaceholder = axWatcher.focusedElementPlaceholder

        karabiner.stageVariable(Variables.modalRole, value: modalRole)
        karabiner.stageVariable(Variables.focusedRole, value: focusedRole)
        karabiner.stageVariable(Variables.focusedSubrole, value: focusedSubrole)
        karabiner.stageVariable(Variables.focusedPlaceholder, value: focusedPlaceholder)
        karabiner.pushStagedVariables()
    }

    private func homerowDidAppearOrChange(type: HomerowWatcher.OverlayType) {
        karabiner.pushVariable(Variables.homerowOverlayType, value: type.rawValue)
    }
    private func homerowDidDisappear() {
        if mode == .autoRevert {
            kvWatcher.sendNormalModeShortcut()
            mode = .off
            karabiner.stageVariable(Variables.mode, value: mode.rawValue)
        }

        karabiner.stageVariable(Variables.homerowOverlayType, value: "")
        karabiner.pushStagedVariables()

        updateOverlay()
    }

    private func recallAppMode() {
        appModeKeeper.cancelSave()

        let mode = appModeKeeper.loadMode(app: windowObserver.frontmostApp)
        kvWatcher.assumeMode(mode)

        if mode == .normal {
            kvWatcher.sendNormalModeShortcut()
        }

        updateOverlay()
    }

    private func saveAppMode() {
        appModeKeeper.queueSave(app: windowObserver.frontmostApp, mode: kvWatcher.mode)
    }
}
