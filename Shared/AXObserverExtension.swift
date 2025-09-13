import AppKit
import OSLog

extension AXObserver {
    /// Creates an AXObserver for the given process ID
    static func create(for pid: pid_t, callback: @escaping AXObserverCallback) -> AXObserver? {
        var observer: AXObserver?
        let result = AXObserverCreate(pid, callback, &observer)

        guard result == .success, let observer = observer else {
            Logger.general.error("Failed to create accessibility observer for PID \(pid)")
            return nil
        }

        return observer
    }

    /// Adds the AXObserver's run loop source to the current run loop
    func addToRunLoop() {
        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(self), .defaultMode)
    }

    /// Removes the AXObserver's run loop source from the current run loop
    func removeFromRunLoop() {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(self), .defaultMode)
    }

    /// Adds notification to an AXObserver with the specified refcon
    func addNotification(
        _ notification: String,
        to element: AXUIElement,
        with refcon: UnsafeMutableRawPointer
    ) -> Bool {
        let result = AXObserverAddNotification(self, element, notification as CFString, refcon)
        if result != .success {
            Logger.general.error(
                "Failed to add notification \(notification) to \(String(describing: element)): \(result.rawValue)"
            )
        }
        return result == .success
    }

    /// Adds multiple notifications to an AXObserver with the specified refcon
    @discardableResult
    func addNotifications(
        _ notifications: [String],
        to element: AXUIElement,
        with refcon: UnsafeMutableRawPointer
    ) -> Int {
        var successCount = 0

        for notification in notifications {
            if addNotification(notification, to: element, with: refcon) {
                successCount += 1
            }
        }

        return successCount
    }
}
