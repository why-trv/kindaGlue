import AppKit
import Foundation
import OSLog

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private let engine = Engine()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupMenubar()
    }

    // func applicationWillTerminate(_ aNotification: Notification) {}

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func setupMenubar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard statusItem != nil else {
            Logger.general.error("Can't setup menu bar item")
            return
        }

        // Set up the menu bar button's appearance and behavior.
        if let button = statusItem?.button {
            if let icon = NSImage(named: "MenubarIcon") {
                // Configure the icon for menubar display
                icon.isTemplate = true // This makes it adapt to the current menu bar appearance
                icon.size = NSSize(width: 18, height: 18) // Standard menubar icon size
                button.image = icon
            } else {
                // Fallback to a system icon if custom icon fails to load
                button.image = NSImage(systemSymbolName: "gear", accessibilityDescription: "kindaGlue")
            }
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: appNameAndVersion(), action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func appNameAndVersion() -> String {
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return "\(appName ?? "") \(appVersion ?? "")"
    }
}
