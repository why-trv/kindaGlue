import AppKit
import CoreGraphics
import OSLog

/// Observes window and application changes
class WindowWatcher {

    var onWindowChanged: (() -> Void)?

    private(set) var frontmostApp: NSRunningApplication?
    private(set) var overlayApp: NSRunningApplication?
    private(set) var frontmostWindowIdentifier: String = ""

    var frontmostAppName: String { return frontmostApp?.localizedName ?? "" }
    var overlayAppName: String { return overlayApp?.localizedName ?? "" }

    static private let excludedApps = Config.excludedFrontmostApps
    static private let overlayApps = Config.includedOverlayApps

    /// Dictionary of observers for each application, keyed on PID
    private var appObservers: [pid_t: AXObserver] = [:]

    /// NSWorkspace notification observers
    private var launchObserver: NSObjectProtocol?
    private var terminationObserver: NSObjectProtocol?

    deinit {
        stop()
    }

    func start() {
        for app in NSWorkspace.shared.runningApplications {
            // NOTE: setupAppObserver takes care of filtering out irrelevant apps
            setupAppObserver(for: app)
        }

        // Also add a notification observer for when applications launch or terminate
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] no in
            if let app = no.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self?.setupAppObserver(for: app)
            }
        }
        terminationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] no in
            if let app = no.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self?.removeAppObserver(for: app)
            }
        }

        // Initial update
        updateWindowData()
    }

    func stop() {
        // Unsubscribe from app launch/termination notifications
        if let observer = launchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            launchObserver = nil
        }
        if let observer = terminationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            terminationObserver = nil
        }

        // Clean up app-specific observers
        for (_, observer) in appObservers {
            observer.removeFromRunLoop()
        }
        appObservers.removeAll()
    }

    /// Use this to filter out various helpers, agents etc., i.e. apps that the user never sees
    private func shouldObserveApp(_ app: NSRunningApplication) -> Bool {
        // Ensure non-nil and non-empty bundle identifier, and apps with no UI
        // (we have to let .accessory apps pass though, as they may create windows)
        guard app.activationPolicy != .prohibited,
            let bid = app.bundleIdentifier,
            !bid.isEmpty
        else { return true }

        let excluded: Set = [
            "org.pqrs.Karabiner-AXNotifier",  // This thing never responds, skip to not waste time
            "com.adobe.PDApp.AAMUpdatesNotifier",
            "com.apple.loginwindow",
            "com.apple.WindowManager",  // kAXErrorNotificationUnsupported
            "com.apple.universalcontrol",
        ]

        let lower = bid.lowercased()

        if excluded.contains(bid)
            || bid.starts(with: "com.apple.WebKit.")  // Catch .WebContent, .GPU, .Networking in one condition
            || bid.starts(with: "com.apple.dock")  // Dock itself + com.apple.dock.extra, com.apple.dock.external.extra.arm64
            // Hoping that nobody names their app 'helper' or 'agent', but there's some risk of throwing
            // the baby out with the bathwater
            || lower.contains("helper")
            || lower.contains("agent")
        {
            return true
        }

        return false
    }

    /// Sets up an observer for a specific application to monitor its windows and whatnot
    private func setupAppObserver(for app: NSRunningApplication) {
        guard !shouldObserveApp(app) else { return }

        let observerCallback: AXObserverCallback = { observer, element, notification, refcon in
            let windowObserver = Unmanaged<WindowWatcher>.fromOpaque(refcon!).takeUnretainedValue()

            DispatchQueue.main.async {
                windowObserver.updateWindowData()
            }
        }

        let pid = app.processIdentifier
        guard let observer = AXObserver.create(for: pid, callback: observerCallback) else {
            Logger.general.error("Failed to create observer for \(app.localizedName ?? "unknown")")
            return
        }

        appObservers[pid] = observer
        observer.addToRunLoop()

        let appElement = AXUIElement.application(app: app)
        var appNotifications = [
            kAXApplicationActivatedNotification,
            kAXApplicationDeactivatedNotification,
            kAXFocusedWindowChangedNotification,
            kAXMainWindowChangedNotification,
        ]

        // NOTE: We need a way to trigger updates when e.g. Alfred or Homerow is dismissed.
        // As far as I can see, kAXUIElementDestroyedNotification is the only thing we can use in
        // such cases. On the other hand, it probably makes no sense to observe this notification
        // for 'normal' windowed apps. The condition here seemed like a decent way to exclude most
        // 'regular' apps, but there could be better options.
        if appElement.windows.isEmpty, app.activationPolicy == .accessory {
            appNotifications.append(kAXUIElementDestroyedNotification)
        }

        // Add application-level notifications
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let count = observer.addNotifications(appNotifications, to: appElement, with: refcon)

        if count > 0 {
            // Logger.general.debug("Successfully added \(count) notifications for app: \(app.localizedName ?? "unknown")")
        } else {
            Logger.general.error(
                "Failed to add any notifications for app: \(app.localizedName ?? "unknown")")
        }
    }

    private func removeAppObserver(for app: NSRunningApplication) {
        let pid = app.processIdentifier
        if let observer = appObservers[pid] {
            observer.removeFromRunLoop()
            appObservers.removeValue(forKey: pid)
        }
    }

    private func updateWindowData() {
        let newApp = findFrontmostApp()
        let newOverlay = findOverlayApp()
        let newWindowIdentifier = findFrontmostWindowIdentifier(app: newApp)

        if newApp != frontmostApp
            || newOverlay != overlayApp
            || newWindowIdentifier != frontmostWindowIdentifier
        {
            frontmostApp = newApp
            overlayApp = newOverlay
            frontmostWindowIdentifier = newWindowIdentifier

            onWindowChanged?()
        }
    }

    /// Checks if an app is excluded from frontmost window detection
    private func isExcludedApp(_ app: NSRunningApplication?) -> Bool {
        guard let app else { return true }
        return Self.excludedApps.contains(app.localizedName ?? "")
    }

    /// Checks if an app is included for frontmost overlay app window detection
    private func isOverlayApp(_ app: NSRunningApplication?) -> Bool {
        guard let app else { return false }
        return Self.overlayApps.contains(app.localizedName ?? "")
    }

    private func findFrontmostApp() -> NSRunningApplication? {
        // Use Accessibility API to get the frontmost application.
        // This is going to catch stuff like Alfred and Spotlight.
        if let app = AXUIElement.focusedApplication?.runningApplication, !isExcludedApp(app) {
            return app
        }

        // Fallback to NSWorkspace method.
        // This is going to catch the main app when Homerow is doing its overlay thing.
        if let app = NSWorkspace.shared.frontmostApplication, !isExcludedApp(app) {
            return app
        }

        return nil
    }

    private func findOverlayApp() -> NSRunningApplication? {
        if let app = AXUIElement.focusedApplication?.runningApplication, isOverlayApp(app) {
            return app
        }

        // Overlay ain't gonna be NSWorkspace's frontmostApplication, so that's it
        return nil
    }

    private func findFrontmostWindowIdentifier(app: NSRunningApplication?) -> String {
        guard let app else { return "" }

        let appElement = AXUIElement.application(app: app)
        let windows = appElement.windows

        guard !windows.isEmpty else { return "" }

        let window = windows[0]  // frontmost == first?
        return window.identifier
    }
}
