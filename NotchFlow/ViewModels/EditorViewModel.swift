import Foundation
import Combine
import AppKit
import UniformTypeIdentifiers

// MARK: - Editor View Model

/// Manages script editing state, live metrics calculation, text structuring,
/// document import (TXT, Markdown, PDF), local JSON library persistence,
/// and teleprompter presentation transitions.
@MainActor
final class EditorViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var scriptTitle: String {
        didSet {
            rebuildStructuredScript()
            scheduleAutosave()
        }
    }
    
    @Published var rawText: String {
        didSet {
            rebuildStructuredScript()
            scheduleAutosave()
        }
    }
    
    @Published private(set) var structuredScript: Script
    @Published private(set) var savedScripts: [Script] = []
    
    @Published var isTeleprompterPresented: Bool = false
    @Published var errorMessage: String?
    @Published var showErrorAlert: Bool = false
    
    // Autosave debouncer
    private var autosaveCancellable: AnyCancellable?
    
    init(title: String = "Untitled Script", initialText: String = "", autoLoadSaved: Bool = true) {
        self.scriptTitle = title
        self.rawText = initialText
        self.structuredScript = ScriptStructuringService.structure(
            rawText: initialText,
            title: title
        )
        
        loadSavedScripts()
        
        // If autoLoadSaved is enabled and no explicit initialText was provided, load most recent
        if autoLoadSaved && initialText.isEmpty, let mostRecent = savedScripts.first {
            selectScript(mostRecent)
        }
    }
    
    // MARK: - Computed Properties
    
    var wordCount: Int {
        structuredScript.wordCount
    }
    
    var characterCount: Int {
        rawText.count
    }
    
    var canStartTeleprompter: Bool {
        wordCount > 0
    }
    
    var estimatedDurationSeconds: TimeInterval {
        structuredScript.estimatedDuration(wordsPerMinute: 150)
    }
    
    var estimatedDurationFormatted: String {
        let seconds = Int(estimatedDurationSeconds)
        let mins = seconds / 60
        let secs = seconds % 60
        if mins == 0 {
            return "\(secs)s"
        } else {
            return String(format: "%d:%02d min", mins, secs)
        }
    }
    
    // MARK: - Library & Script Management
    
    func loadSavedScripts() {
        self.savedScripts = ScriptStorageService.loadAllScripts()
    }
    
    func createNewScript() {
        saveCurrentScript()
        let newScript = Script(title: "Untitled Script", rawText: "")
        self.structuredScript = newScript
        self.scriptTitle = newScript.title
        self.rawText = newScript.rawText
    }
    
    func selectScript(_ script: Script) {
        if !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            saveCurrentScript()
        }
        self.structuredScript = script
        self.scriptTitle = script.title
        self.rawText = script.rawText
    }
    
    func deleteScript(_ script: Script) {
        do {
            try ScriptStorageService.delete(id: script.id)
            loadSavedScripts()
            if structuredScript.id == script.id {
                if let next = savedScripts.first {
                    selectScript(next)
                } else {
                    createNewScript()
                }
            }
        } catch {
            self.errorMessage = "Failed to delete script: \(error.localizedDescription)"
            self.showErrorAlert = true
        }
    }
    
    func saveCurrentScript() {
        guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        var toSave = structuredScript
        toSave.title = scriptTitle
        toSave.rawText = rawText
        toSave.modifiedAt = Date()
        
        do {
            try ScriptStorageService.save(toSave)
            loadSavedScripts()
        } catch {
            AppLogger.storage.error("Autosave error: \(error.localizedDescription)")
        }
    }
    
    private func scheduleAutosave() {
        autosaveCancellable?.cancel()
        autosaveCancellable = Timer.publish(every: 1.5, on: .main, in: .common)
            .autoconnect()
            .first()
            .sink { [weak self] _ in
                self?.saveCurrentScript()
            }
    }
    
    func loadSampleScript() {
        saveCurrentScript()
        let sample = Script(
            title: "Welcome to NotchFlow",
            rawText: """
            Welcome to NotchFlow, the native speech-synchronized teleprompter designed for your MacBook.

            As you speak, NotchFlow tracks your voice in real time, highlighting each word in vibrant orange while dimming words you have already completed.

            Because the reading window is anchored right beneath your camera notch, you can maintain direct eye contact with your audience while delivering natural, confident presentations.

            You can adjust reading speed, font size, line spacing, or switch to manual keyboard control at any time using simple arrow keys.
            """
        )
        self.structuredScript = sample
        self.scriptTitle = sample.title
        self.rawText = sample.rawText
        saveCurrentScript()
    }
    
    // MARK: - Document Import
    
    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            .plainText,
            .pdf,
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "markdown") ?? .plainText
        ]
        panel.prompt = "Import"
        panel.message = "Choose a TXT, Markdown, or PDF script to import"
        
        if panel.runModal() == .OK, let selectedURL = panel.url {
            importDocument(from: selectedURL)
        }
    }
    
    func importDocument(from url: URL) {
        do {
            let (importedTitle, importedText) = try ScriptImportService.importDocument(from: url)
            saveCurrentScript()
            self.scriptTitle = importedTitle
            self.rawText = importedText
            rebuildStructuredScript()
            saveCurrentScript()
        } catch {
            self.errorMessage = error.localizedDescription
            self.showErrorAlert = true
            AppLogger.import_.error("Import failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Teleprompter
    
    func startTeleprompter(mode: NotchWindowState = .expanded) {
        guard canStartTeleprompter else { return }
        saveCurrentScript()
        rebuildStructuredScript()
        isTeleprompterPresented = true
        NotchWindowController.shared.present(with: structuredScript, initialMode: mode)
    }
    
    func dismissTeleprompter() {
        isTeleprompterPresented = false
        NotchWindowController.shared.dismiss()
    }
    
    // MARK: - Internal
    
    private func rebuildStructuredScript() {
        structuredScript = ScriptStructuringService.structure(
            rawText: rawText,
            title: scriptTitle,
            existingId: structuredScript.id
        )
    }
}
