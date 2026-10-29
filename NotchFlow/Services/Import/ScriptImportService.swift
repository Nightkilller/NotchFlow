import Foundation

// MARK: - Script Import Service

/// Unified entry point for importing documents into NotchFlow.
/// Supports TXT, Markdown, and PDF formats.
enum ScriptImportService {
    
    /// Supported file extensions for document import.
    static let supportedExtensions: Set<String> = ["txt", "md", "markdown", "pdf"]
    
    /// Imports and cleans text from a supported document URL.
    /// - Parameter url: File URL to import.
    /// - Returns: A tuple containing the derived title and cleaned text content.
    static func importDocument(from url: URL) throws -> (title: String, text: String) {
        let ext = url.pathExtension.lowercased()
        
        guard supportedExtensions.contains(ext) else {
            throw AppError.unsupportedFileType(ext.isEmpty ? "unknown" : ext)
        }
        
        // Derive title from filename without extension
        let title = url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
        
        let text: String
        switch ext {
        case "txt":
            text = try PlainTextImportService.parse(from: url)
        case "md", "markdown":
            text = try MarkdownImportService.parse(from: url)
        case "pdf":
            text = try PDFImportService.parse(from: url)
        default:
            throw AppError.unsupportedFileType(ext)
        }
        
        AppLogger.import_.info("Successfully imported document: \(title), words: \(text.split(whereSeparator: { $0.isWhitespace }).count)")
        return (title: title, text: text)
    }
}
