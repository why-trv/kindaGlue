import OSLog

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!

    static let general = Logger(subsystem: subsystem, category: "general")
}
