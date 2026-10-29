import Foundation

// MARK: - Settings Storage Service

/// Persists user preferences (font size, reading area dimensions, reading mode) in UserDefaults.
enum SettingsStorageService {
    
    private static let key = "com.notchflow.settings.reading"
    
    /// Loads saved reading settings, or returns defaults if none saved.
    static func load() -> ReadingSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(ReadingSettings.self, from: data) else {
            return ReadingSettings()
        }
        return settings
    }
    
    /// Saves reading settings to UserDefaults.
    static func save(_ settings: ReadingSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
