import Foundation
import Combine
import AppKit
import UniformTypeIdentifiers

// MARK: - Editor View Model

/// Manages script editing state, live metrics calculation, text structuring,
/// document import (TXT, Markdown, PDF), and teleprompter presentation transitions.
@MainActor
final class EditorViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var scriptTitle: String {
        didSet {
            rebuildStructuredScript()
        }
    }
    
    @Published var rawText: String {
        didSet {
            rebuildStructuredScript()
        }
    }
    
    @Published private(set) var structuredScript: Script
    @Published var isTeleprompterPresented: Bool = false
    @Published var errorMessage: String?
    @Published var showErrorAlert: Bool = false
    
    // MARK: - Initialization
    
    init(title: String = "Untitled Script", initialText: String = "") {
        self.scriptTitle = title
        self.rawText = initialText
        self.structuredScript = ScriptStructuringService.structure(
            rawText: initialText,
            title: title
        )
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
    
    // MARK: - Actions
    
    func createNewScript() {
        scriptTitle = "Untitled Script"
        rawText = ""
        rebuildStructuredScript()
    }
    
    func loadSampleScript() {
        scriptTitle = "Welcome to NotchFlow"
        rawText = """
        Welcome to NotchFlow, the native speech-synchronized teleprompter designed for your MacBook.

        As you speak, NotchFlow tracks your voice in real time, highlighting each word in vibrant orange while dimming words you have already completed.

        Because the reading window is anchored right beneath your camera notch, you can maintain direct eye contact with your audience while delivering natural, confident presentations.

        You can adjust reading speed, font size, line spacing, or switch to manual keyboard control at any time using simple arrow keys.
        """
        rebuildStructuredScript()
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
            self.scriptTitle = importedTitle
            self.rawText = importedText
            rebuildStructuredScript()
        } catch {
            self.errorMessage = error.localizedDescription
            self.showErrorAlert = true
            AppLogger.import_.error("Import failed: \(error.localizedDescription)")
        }
    }
    
    func startTeleprompter(mode: NotchWindowState = .expanded) {
        guard canStartTeleprompter else { return }
        // Ensure structured script is fresh
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
