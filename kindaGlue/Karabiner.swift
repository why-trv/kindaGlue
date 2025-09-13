import Foundation
import OSLog
import RegexBuilder

/// Abstracts away setting and reading Karabiner-Elements variables. But mostly setting.
final class Karabiner {

    static let cliPath =
        "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli"
    static let jsonPath =
        "/Library/Application Support/org.pqrs/tmp/karabiner_grabber_manipulator_environment.json"

    private static let prefix = "kG."
    struct Variables {
        static let mode = "\(prefix)mode"
        static let homerowOverlayType = "\(prefix)homerowOverlayType"
        static let frontmostWindowApp = "\(prefix)frontmostApp"
        static let frontmostAppFamily = "\(prefix)frontmostAppFamily"
        static let overlayWindowApp = "\(prefix)overlayApp"
        static let windowIdentifier = "\(prefix)windowIdentifier"
        static let modalRole = "\(prefix)modalRole"
        static let focusedRole = "\(prefix)focusedRole"
        static let focusedSubrole = "\(prefix)focusedSubrole"
        static let focusedPlaceholder = "\(prefix)focusedPlaceholder"

        static let count = 10
    }

    // MAYBE: Actually restrict variable value to Bool, Int and String only
    typealias Value = any Equatable

    private static let defaultVariableValues: [String: Value] = [
        Variables.mode: Engine.Mode.off.rawValue,
        Variables.homerowOverlayType: HomerowWatcher.OverlayType.none.rawValue,
        Variables.frontmostWindowApp: "",
        Variables.overlayWindowApp: "",
        Variables.windowIdentifier: "",
        Variables.modalRole: false,
        Variables.focusedRole: "",
        Variables.focusedSubrole: "",
        Variables.focusedPlaceholder: "",
    ]

    /// NOTE: These dictionaries are for the most part concerned with the variables we want to push
    /// to Karabiner-Elements, and aren't read from Karabiner-Elements (except for 'mode').
    /// In other words, don't expect the values in currentVariables to be synced to KE.
    private var currentVariables: [String: Value] = Dictionary(minimumCapacity: Variables.count)
    private var pendingVariables: [String: Value] = Dictionary(minimumCapacity: Variables.count)

    private var regexCache: [String: Regex<(Substring, Substring)>] = [:]

    init() {
        pushDefaultVariables()
    }

    deinit {
        pushDefaultVariables()
    }

    /// Stages a variable to be sent to Karabiner-Elements CLI on the next commitVariables() call
    func stageVariable<T: Equatable>(_ name: String, value: T) {
        if let current = currentVariables[name] as? T, current == value {
            // Remove the value from pending if it's the same as the current
            pendingVariables.removeValue(forKey: name)
        } else {
            pendingVariables[name] = value
        }
    }

    func stageVariables(_ variables: [String: Value]) {
        for (key, value) in variables {
            stageVariable(key, value: value)
        }
    }

    private func pushDefaultVariables() {
        stageVariables(Self.defaultVariableValues)
        pushStagedVariables()
    }

    /// Sends all staged variables to Karabiner-Elements via CLI
    func pushStagedVariables() {
        guard !pendingVariables.isEmpty else { return }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: pendingVariables, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

            let process = Process()
            process.executableURL = URL(fileURLWithPath: Self.cliPath)
            process.arguments = ["--set-variables", jsonString]

            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                // Update current variables with committed values
                for (key, value) in pendingVariables {
                    currentVariables[key] = value
                }
                pendingVariables.removeAll()
            } else {
                Logger.general.error(
                    "Failed to set Karabiner variables: exit code \(process.terminationStatus)")
            }
        } catch {
            Logger.general.error("Error setting Karabiner variables: \(error)")
        }
    }

    /// Just a shorthand for when you only need to send one variable
    func pushVariable(_ name: String, value: Value) {
        stageVariable(name, value: value)
        pushStagedVariables()
    }

    /// Reads a string variable from the Karabiner-Elements environment file.
    /// NOTE: It's doesn't make a lot of sense to parse the whole JSON when we only need one
    /// variable, so we use regex instead.
    func getStringVariable(_ name: String) -> String? {
        do {
            let content = try String(contentsOfFile: Self.jsonPath, encoding: .utf8)
            let regex = regexForVariable(name)

            if let match = content.firstMatch(of: regex) {
                let stringValue = String(match.1)
                didReadVariable(name, value: stringValue)
                return stringValue
            }
        } catch {
            Logger.general.error("Error reading Karabiner environment file: \(error)")
        }

        return nil
    }

    /// Returns a cached regex for a variable contained in the KE JSON file, or creates and caches
    /// a new one.
    private func regexForVariable(_ name: String) -> Regex<(Substring, Substring)> {
        if let cached = regexCache[name] {
            return cached
        }

        let regex = Regex {
            /"/
            name
            /":\s*"([^\n]*)",?\n/
        }
        regexCache[name] = regex
        return regex
    }

    /// Updates the current variables dict with the value read from the KE JSON file
    private func didReadVariable<T: Equatable>(_ name: String, value: T) {
        currentVariables[name] = value

        if pendingVariables[name] as? T == value {
            pendingVariables.removeValue(forKey: name)
        }
    }
}
