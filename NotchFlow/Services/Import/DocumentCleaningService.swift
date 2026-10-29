import Foundation

// MARK: - Document Cleaning Service

/// Normalizes raw extracted document text into clean, teleprompter-friendly reading format.
/// Resolves common formatting artifacts:
/// - Hyphenated line breaks (e.g. "pre-\nsentation" -> "presentation")
/// - Hard line wraps within sentences (PDF line breaks)
/// - Excessive whitespace and trailing spaces
/// - Repeated page numbers and footer artifacts
/// - Preserves genuine paragraph breaks and bullet points
enum DocumentCleaningService {
    
    /// Cleans and formats raw extracted text.
    /// - Parameter text: Raw text from PDF, TXT, or pasted input.
    /// - Returns: Cleaned text ready for structuring.
    static func clean(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        
        var result = text
        
        // 1. Normalize line endings to \n
        result = result.replacingOccurrences(of: "\r\n", with: "\n")
        result = result.replacingOccurrences(of: "\r", with: "\n")
        
        // 2. Remove broken hyphenated line wraps (e.g. "ac-\ncomplish" -> "accomplish")
        let hyphenWrapPattern = "([a-zA-Z]+)-\\n([a-zA-Z]+)"
        if let regex = try? NSRegularExpression(pattern: hyphenWrapPattern) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1$2")
        }
        
        // 3. Remove standalone page numbers (e.g., "\n\n12\n\n" or "Page 3 of 10")
        let pageNumPattern = "(?m)^\\s*(Page\\s+\\d+(\\s+of\\s+\\d+)?|\\d+)\\s*$"
        if let regex = try? NSRegularExpression(pattern: pageNumPattern, options: [.caseInsensitive]) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }
        
        // 4. Split into paragraphs (delimited by double newlines)
        let paragraphs = result.components(separatedBy: "\n\n")
        var cleanedParagraphs: [String] = []
        
        for para in paragraphs {
            let trimmed = para.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            // Check if paragraph is a bullet list or heading
            let lines = trimmed.components(separatedBy: "\n")
            var cleanedLines: [String] = []
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                guard !trimmedLine.isEmpty else { continue }
                cleanedLines.append(trimmedLine)
            }
            
            // If lines look like regular sentence flow (not list items), join with a space
            let isBulletList = cleanedLines.contains { $0.hasPrefix("•") || $0.hasPrefix("- ") || $0.hasPrefix("* ") }
            
            if isBulletList {
                cleanedParagraphs.append(cleanedLines.joined(separator: "\n"))
            } else {
                // Join broken lines inside paragraph with space
                cleanedParagraphs.append(cleanedLines.joined(separator: " "))
            }
        }
        
        // 5. Rejoin paragraphs with standard double newline
        result = cleanedParagraphs.joined(separator: "\n\n")
        
        // 6. Normalize multiple consecutive spaces
        let multiSpacePattern = "[ \\t]{2,}"
        if let regex = try? NSRegularExpression(pattern: multiSpacePattern) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: " ")
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
