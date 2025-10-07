import AppKit
import Foundation
import OSLog

/// Handles interaction (mostly one-way) with kindaVim, that is:
/// - watches the kV state JSON file for mode changes
/// - sends a normal mode shortcut to KV
/// - reads kV user defaults to be able to check which family an app belongs to
final class KindaVim {

    enum Mode: String {
        case insert = "insert"
        case normal = "normal"
        case visual = "visual"
    }

    enum Family: String {
        case none = ""
        case off = "off"
        case pgr = "pgr"
        case electron = "electron"
        case keyMapping = "keymap"
        case nineOneOne = "911"
    }

    static let bundleId = "mo.com.sleeplessmind.kindaVim"
    /// The path to the JSON file to be monitored for changes
    static let jsonPath = ("~/Library/Application Support/kindaVim/environment.json" as NSString)
        .expandingTildeInPath
    /// The path to the UserDefaults plist file
    static let plistPath = ("~/Library/Preferences/mo.com.sleeplessmind.kindaVim.plist" as NSString)
        .expandingTildeInPath
    // MAYBE: Get it from kindaVim UserDefaults
    static let normalModeShortcut = Config.kindaVimNormalModeShortcut
    static let visualModeShortcut = Config.kindaVimVisualModeShortcut

    /// Closure to call when file changes
    var onModeChanged: ((Mode) -> Void)?

    private(set) var mode = Mode.insert

    private var appFamilies: [String: Family] = [:]

    private var jsonWatcher = FileWatcher()
    private var plistWatcher = FileWatcher()

    deinit {
        stop()
    }

    func start() {
        updateFamiliesFromUserDefaults()

        guard
            (jsonWatcher.watch(path: Self.jsonPath) { [weak self] in
                guard let self else { return }
                self.onModeChanged?(self.updateModeFromJSON())
            })
        else {
            Logger.general.critical(
                "Failed to setup JSON file watcher for kindaVim, won't continue")
            return
        }

        guard
            (plistWatcher.watch(path: Self.plistPath) { [weak self] in
                guard let self else { return }
                self.updateFamiliesFromUserDefaults()
            })
        else {
            Logger.general.critical(
                "Failed to setup plist file watcher for kindaVim, won't continue")
            return
        }

        // Initial update
        onModeChanged?(updateModeFromJSON())
        updateFamiliesFromUserDefaults()
    }

    func stop() {
        jsonWatcher.stop()
        plistWatcher.stop()
    }

    /// Sets the expected mode here, locally, ahead of time - though in reality it's gonna
    /// take some time to propagate via the JSON file. Mostly intended for instant overlay
    /// color changes when recalling last used mode on app switch.
    func assumeMode(_ newMode: Mode) {
        mode = newMode
        self.onModeChanged?(mode)
    }

    func sendNormalModeShortcut() {
        Self.normalModeShortcut.post()
    }
    
    func sendVisualModeShortcut() {
        Self.visualModeShortcut.post()
    }

    func family(for app: NSRunningApplication) -> Family {
        guard let bid = app.bundleIdentifier else { return Family.none }
        return appFamilies[bid] ?? Family.none
    }

    /// Reads the JSON file and returns the mode value
    private func updateModeFromJSON() -> Mode {
        let url = URL(fileURLWithPath: Self.jsonPath)

        do {
            let data = try Data(contentsOf: url)
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            if let json = jsonObject as? [String: Any], let kvMode = json["mode"] as? String {
                mode = Mode(rawValue: kvMode) ?? Mode.insert
                return mode
            }
        } catch {
            Logger.general.error("Failed to read kindaVim JSON file: \(error)")
        }

        mode = Mode.insert
        return mode
    }

    private func updateFamiliesFromUserDefaults() {
        guard let ud = UserDefaults(suiteName: Self.bundleId) else {
            Logger.general.error("Failed to access UserDefaults for suite com.kindaVim")
            return
        }

        let map = [
            "appsToIgnore": Family.off,
            "appsForWhichToUseHybridMode": Family.pgr,
            "appsForWhichToEnforceElectron": Family.electron,
            "appsForWhichToEnforceKeyboardStrategy": Family.keyMapping,
            "appsForWhichToEnforceNineOneOne": Family.nineOneOne,
        ]

        var res: [String: Family] = [:]

        for (key, value) in map {
            guard let str = ud.string(forKey: key),
                let data = str.data(using: .utf8)
            else { continue }

            // The value is a string representing an array of strings, e.g.
            // '["com.abc", "org.def.ghi", "gov.xyz"]', so we're gonna use a JSON parser
            do {
                guard
                    let bundleIDs = try JSONSerialization.jsonObject(with: data, options: [])
                        as? [String]
                else { continue }

                for id in bundleIDs {
                    res[id] = value
                }
            } catch {
                Logger.general.error("Failed to parse app family (\(key)) array string: \(error)")
                continue
            }
        }

        appFamilies = res
    }
}
