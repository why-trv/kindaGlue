import AppKit

// Saves and recalls the current mode on a per-app basis
class AppModeKeeper {

    private var lastModes: [pid_t: KindaVim.Mode] = [:]
    private var delayedWorkItem: DispatchWorkItem?

    func queueSave(app: NSRunningApplication?, mode: KindaVim.Mode) {
        guard let app else { return }
        
        delayedWorkItem = DispatchWorkItem { [weak self] in
            self?.lastModes[app.processIdentifier] = mode
        }
        
        guard let delayedWorkItem else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: delayedWorkItem)
    }

    func cancelSave() {
        delayedWorkItem?.cancel()
        delayedWorkItem = nil
    }

    func loadMode(app: NSRunningApplication?) -> KindaVim.Mode {
        guard let app else { return .insert }
        
        return lastModes[app.processIdentifier] ?? .insert
    }
}
