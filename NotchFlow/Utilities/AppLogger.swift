import os

// MARK: - NotchFlow Logging

/// Centralized logging using Apple's os.Logger.
/// Categories help filter logs in Console.app.
enum AppLogger {
    /// General application lifecycle events.
    static let app = Logger(subsystem: "com.notchflow.app", category: "App")
    /// Script import and document processing.
    static let import_ = Logger(subsystem: "com.notchflow.app", category: "Import")
    /// Speech recognition events.
    static let speech = Logger(subsystem: "com.notchflow.app", category: "Speech")
    /// Script synchronization / position matching.
    static let sync = Logger(subsystem: "com.notchflow.app", category: "Sync")
    /// Window management and display geometry.
    static let window = Logger(subsystem: "com.notchflow.app", category: "Window")
    /// Persistence (save/load).
    static let storage = Logger(subsystem: "com.notchflow.app", category: "Storage")
    /// Teleprompter rendering and state.
    static let teleprompter = Logger(subsystem: "com.notchflow.app", category: "Teleprompter")
}
