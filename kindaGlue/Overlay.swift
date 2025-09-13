import AppKit

/// Controls the colored overlays that indicate the current kindaVim / kindaGlue mode
class Overlay {

    private var overlayWindows: [NSWindow] = []

    init() {
        // Observe screen configuration changes to rebuild overlay windows
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        createWindows()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)

        clearWindows()
    }

    var color: NSColor {
        get {
            return self.overlayWindows.first?.backgroundColor ?? NSColor.clear
        }
        set(newColor) {
            guard (newColor != self.color) else {
                return
            }

            for window in self.overlayWindows {
                window.backgroundColor = newColor
            }
        }
    }

    /// Handles screen configuration changes by rebuilding overlay windows
    @objc private func screenConfigurationDidChange() {
        let curColor = self.color
        createWindows()
        self.color = curColor
    }

    private func createWindows() {
        // Clear any existing windows
        clearWindows()

        // Setup new overlay windows for each screen
        for screen in NSScreen.screens {
            let fullFrame = screen.frame
            let visibleFrame = screen.visibleFrame

            let menuBarHeight = fullFrame.maxY - visibleFrame.maxY
            let windowY = fullFrame.maxY - menuBarHeight
            let windowHeight = menuBarHeight
            let windowWidth = fullFrame.width

            let windowFrame = NSRect(
                x: fullFrame.origin.x,
                y: windowY,
                width: windowWidth,
                height: windowHeight
            )

            let window = NSWindow(
                contentRect: windowFrame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )

            window.level = .statusBar
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            window.isOpaque = false
            window.hasShadow = false
            window.backgroundColor = .clear
            window.ignoresMouseEvents = true

            window.orderFront(nil)
            overlayWindows.append(window)
        }
    }

    private func clearWindows() {
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
    }
}
