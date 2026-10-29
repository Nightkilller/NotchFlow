import Foundation

// MARK: - Markdown Import Service

enum MarkdownImportService {
    
    /// Parses a Markdown document and cleans formatting syntax for teleprompter reading.
    static func parse(from url: URL) throws -> String {
        let rawText = try PlainTextImportService.parse(from: url)
        return cleanMarkdownSyntax(rawText)
    }
    
    /// Strips Markdown decorative syntax while preserving headings and paragraph boundaries.
    static func cleanMarkdownSyntax(_ text: String) -> String {
        var result = text
        
        // 1. Remove Markdown headers `# Heading` -> `Heading`
        let headerPattern = "(?m)^#{1,6}\\s+(.+)$"
        if let regex = try? NSRegularExpression(pattern: headerPattern) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1")
        }
        
        // 2. Remove Bold/Italic markers: `**text**` or `*text*` -> `text`
        let boldItalicPattern = "(\\*\\*|\\*|__|_)(.*?)\\1"
        if let regex = try? NSRegularExpression(pattern: boldItalicPattern) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$2")
        }
        
        // 3. Convert Markdown links: `[title](url)` -> `title`
        let linkPattern = "\\[([^\\]]+)\\]\\([^\\)]+\\)"
        if let regex = try? NSRegularExpression(pattern: linkPattern) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1")
        }
        
        // 4. Remove blockquotes: `> quote` -> `quote`
        let quotePattern = "(?m)^>\\s+(.+)$"
        if let regex = try? NSRegularExpression(pattern: quotePattern) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1")
        }
        
        return DocumentCleaningService.clean(result)
    }
}
