import Foundation
import OSLog

final class FileWatcher {

    private var fileMonitor: DispatchSourceFileSystemObject?

    deinit {
        stop()
    }

    func watch(path: String, onChange: @escaping () -> Void) -> Bool {
        stop()

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else {
            Logger.general.error("Unable to find '\(path)', are you sure the app is running?")
            return false
        }

        let fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor != -1 else {
            Logger.general.error("Failed to get file descriptor for '\(path)'")
            return false
        }

        fileMonitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            // We're in it for writes, but in some cases (e.g. user defaults) the file is deleted
            // and recreated as a whole
            eventMask: [.write, .delete],
            queue: .main
        )

        guard let fileMonitor else {
            Logger.general.error("Failed to create file monitor for '\(path)'")
            return false
        }

        fileMonitor.setEventHandler { [weak self] in
            onChange()
            let flags = fileMonitor.data
            if flags.contains(.delete) {
                // File deleted, gonna have to resubscribe. Resubscribing right away feels like a
                // weird thing to do (the file might be deleted, but not yet newly created), but
                // it seems to work.
                Logger.general.debug("File deleted at '\(path)', gonna have to re-watch")
                guard self?.watch(path: path, onChange: onChange) != nil else {
                    Logger.general.error("Failed to re-watch '\(path)', won't continue")
                    return
                }
            }
        }

        fileMonitor.setCancelHandler {
            close(fileDescriptor)
        }

        fileMonitor.resume()
        return true
    }

    func stop() {
        fileMonitor?.cancel()
        fileMonitor = nil
    }
}
