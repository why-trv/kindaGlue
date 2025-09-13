import Foundation
import AppKit
import OSLog

/// Observes accessibility events for modal/sheet detection and focused element tracking
class AXWatcher {

    public var onAccessibilityChanged: (() -> Void)?

    private var observedApp: NSRunningApplication? // Currently observed app
    private var axObserver: AXObserver?
    private(set) var focusedElement: AXUIElement?
    private(set) var modalElement: AXUIElement?

    deinit {
        stop()
    }

    /// Starts observing the specified app (we only do one app at a time)
    func observe(_ app: NSRunningApplication?) {
        stop()

        guard let app = app else { return }

        let pid = app.processIdentifier
        guard pid != observedApp?.processIdentifier else { return }

        observedApp = app

        // Create accessibility observer
        axObserver = AXObserver.create(for: pid, callback: { observer, element, notification, refcon in
            let accessibilityObserver = Unmanaged<AXWatcher>.fromOpaque(refcon!).takeUnretainedValue()
            accessibilityObserver.handleAccessibilityNotification(observer: observer, element: element, notification: notification)
        })

        guard let observer = axObserver else {
            Logger.general.error("Failed to create accessibility observer")
            return
        }

        // Get the application element
        let appElement = AXUIElement.application(app: app)

        // Add watchers for the application
        addWatchers(to: appElement, observer: observer)

        // Start the observer
        observer.addToRunLoop()

        // Initial state check
        updateAccessibilityState()
    }

    func stop() {
        if let observer = axObserver {
            observer.removeFromRunLoop()
            axObserver = nil
        }
        observedApp = nil
    }
    
    var focusedElementRole: String {
        guard let element = focusedElement else { return "" }
        return element.role
    }

    var focusedElementSubrole: String {
        guard let element = focusedElement else { return "" }
        return element.subrole
    }

    var focusedElementPlaceholder: String {
        guard let element = focusedElement else { return "" }
        return element.getStringAttribute(kAXPlaceholderValueAttribute as String)
    }
    
    var modalElementRole: String {
        return modalElement?.role ?? ""
    }

    private func addWatchers(to element: AXUIElement, observer: AXObserver) {
        // Add watchers for the application element
        let notifications = [
            kAXWindowCreatedNotification,
            kAXFocusedUIElementChangedNotification,
            kAXApplicationActivatedNotification,
            kAXApplicationDeactivatedNotification
        ]

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let successCount = observer.addNotifications(notifications, to: element, with: refcon)

        if successCount < notifications.count {
            Logger.general.warning("Failed to add some notifications. Added \(successCount) of \(notifications.count)")
        }

        // Add watchers for all existing windows
        addWindowWatchers(to: element, observer: observer)
    }

    private func addWindowWatchers(to appElement: AXUIElement, observer: AXObserver) {
        let windows = appElement.windows

        for window in windows {
            let windowNotifications = [
                kAXWindowCreatedNotification,
                kAXFocusedUIElementChangedNotification,
                kAXUIElementDestroyedNotification
            ]

            let refcon = Unmanaged.passUnretained(self).toOpaque()
            observer.addNotifications(windowNotifications, to: window, with: refcon)
        }
    }

    private func handleAccessibilityNotification(observer: AXObserver, element: AXUIElement, notification: CFString) {
        updateAccessibilityState()
    }

    private func updateAccessibilityState() {
        updateFocusedElement()
        updateModalState()
        onAccessibilityChanged?()
    }

    private func updateFocusedElement() {
        guard let app = observedApp else {
            focusedElement = nil
            return
        }

        let appElement = AXUIElement.application(app: app)
        focusedElement = appElement.focusedElement
    }

    private func updateModalState() {
        guard let app = observedApp else {
            modalElement = nil
            return
        }

        let appElement = AXUIElement.application(app: app)
        modalElement = findModalOrSheet(in: appElement, depth: 0)
    }

    private func findModalOrSheet(in element: AXUIElement, depth: Int) -> AXUIElement? {
        guard depth < 3 else { return nil } // Limit recursion

        // Check if this element is a modal or sheet
        if element.isModalOrDialog {
            return element
        }

        // Check children
        let children = element.children
        for child in children {
            if let modal = findModalOrSheet(in: child, depth: depth + 1) {
                return modal
            }
        }

        return nil
    }
}
