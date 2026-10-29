import AppKit

// MARK: - NotchFlow Application Delegate

/// Native AppKit lifecycle coordinator for NotchFlow.
/// Manages window reopening from the Dock, application termination,
/// and prevents premature process exit when the editor is closed while teleprompter is active.
final class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLogger.app.info("NotchFlow application launched successfully")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Prevent application from immediately terminating if the teleprompter window is active
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows {
                if !(window is NSPanel) {
                    window.makeKeyAndOrderFront(nil)
                    return true
                }
            }
        }
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            NotchWindowController.shared.dismiss()
        }
        AppLogger.app.info("NotchFlow application terminating cleanly")
    }
}
