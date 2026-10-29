import Foundation

// MARK: - Plain Text Import Service

enum PlainTextImportService {
    
    /// Reads and cleans a plain text document.
    /// - Parameter url: Local file URL.
    /// - Returns: Cleaned plain text content.
    static func parse(from url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        
        // Attempt UTF-8, then fallback encodings
        let encodings: [String.Encoding] = [.utf8, .utf16, .isoLatin1, .ascii]
        var rawText: String?
        
        for encoding in encodings {
            if let decoded = String(data: data, encoding: encoding) {
                rawText = decoded
                break
            }
        }
        
        guard let text = rawText else {
            throw AppError.fileReadFailed(url.lastPathComponent)
        }
        
        let cleaned = DocumentCleaningService.clean(text)
        guard !cleaned.isEmpty else {
            throw AppError.emptyDocument
        }
        
        return cleaned
    }
}
