import Testing
import Foundation
@testable import NotchFlow

// MARK: - ScriptStorageService Tests

@Suite("ScriptStorageService")
struct ScriptStorageServiceTests {
    
    @Test("Saves and reloads scripts from disk")
    func saveAndReload() throws {
        let uniqueTitle = "Storage Test \(UUID().uuidString.prefix(6))"
        let script = Script(title: uniqueTitle, rawText: "Testing local file persistence in Application Support.")
        
        try ScriptStorageService.save(script)
        
        let allScripts = ScriptStorageService.loadAllScripts()
        let found = allScripts.first(where: { $0.id == script.id })
        
        #expect(found != nil)
        #expect(found?.title == uniqueTitle)
        #expect(found?.rawText == script.rawText)
        
        // Clean up
        try ScriptStorageService.delete(id: script.id)
    }
    
    @Test("Deletes scripts cleanly")
    func deleteScript() throws {
        let script = Script(title: "To Be Deleted", rawText: "Temporary script.")
        try ScriptStorageService.save(script)
        
        try ScriptStorageService.delete(id: script.id)
        
        let allScripts = ScriptStorageService.loadAllScripts()
        let found = allScripts.first(where: { $0.id == script.id })
        #expect(found == nil)
    }
}

// MARK: - SettingsStorageService Tests

@Suite("SettingsStorageService")
struct SettingsStorageServiceTests {
    
    @Test("Persists and restores custom ReadingSettings")
    func settingsRoundtrip() {
        var custom = ReadingSettings()
        custom.fontSize = 36
        custom.autoScrollSpeed = 190
        custom.readingMode = .manual
        
        SettingsStorageService.save(custom)
        let loaded = SettingsStorageService.load()
        
        #expect(loaded.fontSize == 36)
        #expect(loaded.autoScrollSpeed == 190)
        #expect(loaded.readingMode == .manual)
    }
}
