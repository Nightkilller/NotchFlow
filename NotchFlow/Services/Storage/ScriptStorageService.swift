import Foundation

// MARK: - Script Storage Service

/// Manages local file-based JSON persistence of user scripts in Application Support.
/// Each script is stored as an individual JSON file (`<UUID>.json`) with an `index.json` catalog.
enum ScriptStorageService {
    
    // MARK: - Directory Locations
    
    private static var storageDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let notchFlowDir = appSupport.appendingPathComponent("NotchFlow", isDirectory: true)
        let scriptsDir = notchFlowDir.appendingPathComponent("Scripts", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: scriptsDir.path) {
            try? FileManager.default.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
        }
        return scriptsDir
    }
    
    private static var indexFileURL: URL {
        storageDirectory.appendingPathComponent("index.json")
    }
    
    // MARK: - Public Operations
    
    /// Saves a script to disk as a JSON file and updates the catalog.
    static func save(_ script: Script) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let fileURL = storageDirectory.appendingPathComponent("\(script.id.uuidString).json")
        let data = try encoder.encode(script)
        try data.write(to: fileURL, options: .atomic)
        
        updateIndex(with: script)
        AppLogger.storage.info("Saved script '\(script.title)' (ID: \(script.id.uuidString))")
    }
    
    /// Loads all saved scripts from disk, ordered by most recently modified.
    static func loadAllScripts() -> [Script] {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        var scripts: [Script] = []
        for file in files where file.pathExtension.lowercased() == "json" && file.lastPathComponent != "index.json" {
            if let data = try? Data(contentsOf: file),
               let script = try? decoder.decode(Script.self, from: data) {
                scripts.append(script)
            }
        }
        
        // Sort descending by modified date
        return scripts.sorted(by: { $0.modifiedAt > $1.modifiedAt })
    }
    
    /// Deletes a script file and removes it from the catalog.
    static func delete(id: UUID) throws {
        let fileURL = storageDirectory.appendingPathComponent("\(id.uuidString).json")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
            removeFromIndex(id: id)
            AppLogger.storage.info("Deleted script ID: \(id.uuidString)")
        }
    }
    
    // MARK: - Catalog Index Maintenance
    
    private struct ScriptIndexEntry: Codable {
        let id: UUID
        var title: String
        var modifiedAt: Date
    }
    
    private static func updateIndex(with script: Script) {
        var index = loadIndex()
        if let idx = index.firstIndex(where: { $0.id == script.id }) {
            index[idx].title = script.title
            index[idx].modifiedAt = script.modifiedAt
        } else {
            index.append(ScriptIndexEntry(id: script.id, title: script.title, modifiedAt: script.modifiedAt))
        }
        saveIndex(index)
    }
    
    private static func removeFromIndex(id: UUID) {
        var index = loadIndex()
        index.removeAll(where: { $0.id == id })
        saveIndex(index)
    }
    
    private static func loadIndex() -> [ScriptIndexEntry] {
        guard let data = try? Data(contentsOf: indexFileURL),
              let entries = try? JSONDecoder().decode([ScriptIndexEntry].self, from: data) else {
            return []
        }
        return entries
    }
    
    private static func saveIndex(_ entries: [ScriptIndexEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: indexFileURL, options: .atomic)
    }
}
