import AppKit
import Foundation
import HotKey

/// Watches for ZMK layer changes via hotkey monitoring
class ZMKWatcher {

    enum Layer: String {
        case none = ""
        case nav = "nav"
        case sym = "sym"
    }

    var onLayerChanged: ((Layer) -> Void)?

    /// Current ZMK layer states
    private var navActive: Bool = false
    private var symActive: Bool = false

    private var navOnHotkey: HotKey?
    private var navOffHotkey: HotKey?
    private var symOnHotkey: HotKey?
    private var symOffHotkey: HotKey?

    func start() {
        navOnHotkey = Config.ZMKLayers.navOn.createHotKey(handler: { [weak self] in
            self?.setNavActive(true)
        })
        navOffHotkey = Config.ZMKLayers.navOff.createHotKey(handler: { [weak self] in
            self?.setNavActive(false)
        })
        symOnHotkey = Config.ZMKLayers.symOn.createHotKey(handler: { [weak self] in
            self?.setSymActive(true)
        })
        symOffHotkey = Config.ZMKLayers.symOff.createHotKey(handler: { [weak self] in
            self?.setSymActive(false)
        })
    }

    func stop() {
        navOnHotkey = nil
        navOffHotkey = nil
        symOnHotkey = nil
        symOffHotkey = nil
    }

    func getCurrentLayer() -> Layer {
        return navActive ? .nav : symActive ? .sym : .none
    }

    private func setNavActive(_ active: Bool) {
        if navActive != active {
            navActive = active
            notifyLayerChanged()
        }
    }

    private func setSymActive(_ active: Bool) {
        if symActive != active {
            symActive = active
            notifyLayerChanged()
        }
    }

    private func notifyLayerChanged() {
        onLayerChanged?(getCurrentLayer())
    }
}
