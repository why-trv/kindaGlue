import Foundation
import AppKit
import OSLog

/// Handles accessibility permissions for the application
class AXAccess {

    // For now we're not actively checking permissions and require app restart,
    // so there's no point in having the granted callback
    // var onPermissionsGranted: (() -> Void)?
    // var onPermissionsDenied: (() -> Void)?

    func arePermissionsGranted() -> Bool {
        return AXIsProcessTrustedWithOptions(nil)
    }

    func requestPermissions() -> Bool {
        // Check if we already have permissions
        if arePermissionsGranted() {
            // onPermissionsGranted?()
            return true
        }

        // If not, show a dialog explaining the reasons
        showPermissionsDialog()
        return false
    }

    func showSystemPermissionsDialog() {
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]
        AXIsProcessTrustedWithOptions(options)
    }

    // Shows a dialog explaining the reasons for permissions
    private func showPermissionsDialog() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permissions Required"
        alert.informativeText = """
        kindaGlue needs accessibility permissions to get UI elements data to set to Karabiner-Elements variables.

        After granting permissions, restart kindaGlue for the changes to take effect.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Grant Permissions")
        alert.addButton(withTitle: "Quit")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            showSystemPermissionsDialog()
        } else {
            Logger.general.critical("Accessibility permissions denied, quitting")
            NSApp.terminate(nil)
        }
    }
   
    // MAYBE: Monitor permissions changes (maybe using NSWorkspace.didDeactivateApplicationNotification
    // or something)
}
