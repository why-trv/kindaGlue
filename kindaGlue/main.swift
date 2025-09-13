import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Configure the app to run as a background menubar app
app.setActivationPolicy(.accessory)

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
