import AppKit
import Foundation
import OSLog

/// Observes Homerow app for scroll/search overlay detection
final class HomerowWatcher {

    enum OverlayType: String {
        case none = ""
        case scroll = "scroll"
        case search = "search"
    }

    var onHomerowDidAppear: ((OverlayType) -> Void)?
    var onHomerowDidChange: ((OverlayType) -> Void)?
    var onHomerowDidDisappear: (() -> Void)?

    static private let homerowBundleId = "com.superultra.Homerow"

    private var homerowApp: NSRunningApplication?
    private var homerowElement: AXUIElement?
    private var axObserver: AXObserver?
    private var launchObserver: NSObjectProtocol?
    private var terminationObserver: NSObjectProtocol?

    private var prevNumDialogs: Int = 0

    deinit {
        stop()
    }

    func start() {
        stop()

        setupAppLifecycleObservers()

        if let app = NSRunningApplication.runningApplications(
            withBundleIdentifier: Self.homerowBundleId
        ).first {
            homerowApp = app
            homerowElement = AXUIElement.application(app: app)
            startAXObserver()
        } else {
            Logger.general.log("Homerow not currently running - will monitor for launch")
        }
    }

    private func setupAppLifecycleObservers() {
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }

            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication,
                Self.isAppHomerow(app)
            {
                self.homerowApp = app
                self.homerowElement = AXUIElement.application(app: app)
                self.startAXObserver()
            }
        }

        terminationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }

            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication,
                Self.isAppHomerow(app)
            {
                self.stopAXObserver()
                self.homerowApp = nil
                self.homerowElement = nil
                self.prevNumDialogs = 0
            }
        }
    }

    func stop() {
        stopAXObserver()

        if let observer = launchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            launchObserver = nil
        }

        if let observer = terminationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            terminationObserver = nil
        }

        homerowApp = nil
        homerowElement = nil
        prevNumDialogs = 0
    }

    static private func isAppHomerow(_ app: NSRunningApplication?) -> Bool {
        return app?.bundleIdentifier == Self.homerowBundleId
    }

    private func stopAXObserver() {
        if let observer = axObserver {
            observer.removeFromRunLoop()
            axObserver = nil
        }
    }

    private func startAXObserver() {
        guard let pid = homerowApp?.processIdentifier,
            let element = homerowElement
        else { return }

        axObserver = AXObserver.create(
            for: pid,
            callback: { observer, element, notification, refcon in
                let homerowObserver = Unmanaged<HomerowWatcher>.fromOpaque(refcon!)
                    .takeUnretainedValue()
                homerowObserver.handleHomerowNotification(
                    observer: observer, element: element, notification: notification)
            })

        guard let observer = axObserver else {
            Logger.general.error("Could not create AX observer for Homerow app")
            return
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let notifications = [
            kAXUIElementDestroyedNotification,
            kAXWindowCreatedNotification,
        ]
        observer.addNotifications(notifications, to: element, with: refcon)
        observer.addToRunLoop()
    }

    private func handleHomerowNotification(
        observer: AXObserver, element: AXUIElement, notification: CFString
    ) {
        let notificationString = notification as String
        let numDialogs = countSystemDialogs()

        if notificationString == kAXWindowCreatedNotification {
            let subrole = element.subrole

            if subrole == kAXSystemDialogSubrole {
                // HACK: Homerow provides almost no AX data, the only way to distinguish scroll
                // from search is to check the number of children (scrolls has them, while search has none)
                let children = element.children
                let numChildren = children.count

                if numDialogs >= 0 {
                    let type = numChildren > 0 ? OverlayType.scroll : OverlayType.search
                    if prevNumDialogs <= 0 {
                        onHomerowDidAppear?(type)
                    } else {
                        onHomerowDidChange?(type)
                    }
                }
                return
            }
        }

        if notificationString == kAXUIElementDestroyedNotification
            && numDialogs <= 0
        {
            onHomerowDidDisappear?()
        }

        prevNumDialogs = numDialogs
    }

    private func countSystemDialogs() -> Int {
        guard let children = homerowElement?.children else { return 0 }

        var count = 0
        for child in children {
            if child.subrole == kAXSystemDialogSubrole {
                count += 1
            }
        }

        return count
    }
}
