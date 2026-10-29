import Foundation
import AppKit

// MARK: - Script Line

/// Represents a visually wrapped line of script words for teleprompter presentation.
struct ScriptLine: Identifiable, Equatable, Sendable {
    let id: Int
    let words: [ScriptWord]
    
    var startIndex: Int { words.first?.globalIndex ?? 0 }
    var endIndex: Int { words.last?.globalIndex ?? 0 }
    
    func contains(wordIndex: Int) -> Bool {
        guard !words.isEmpty else { return false }
        return startIndex <= wordIndex && wordIndex <= endIndex
    }
}

// MARK: - Script Line Wrap Service

/// Calculates visual line breaks for teleprompter words based on container width and typography.
/// Enables deterministic 2-line compact teleprompter display and smooth line-by-line scrolling.
enum ScriptLineWrapService {
    
    /// Computes lines of script words that fit within `maxWidth`.
    static func computeLines(
        words: [ScriptWord],
        maxWidth: CGFloat,
        fontSize: CGFloat
    ) -> [ScriptLine] {
        guard !words.isEmpty else { return [] }
        
        let nsFont = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        let wordPadding: CGFloat = 8 // 4pt padding on each side of WordHighlightView
        let interWordSpacing: CGFloat = 6
        let effectiveMaxWidth = max(240, maxWidth)
        
        var lines: [ScriptLine] = []
        var currentLineWords: [ScriptWord] = []
        var currentLineWidth: CGFloat = 0
        var lineIndex = 0
        
        for word in words {
            let textWidth = (word.text as NSString).size(withAttributes: [.font: nsFont]).width + wordPadding
            let neededWidth = currentLineWords.isEmpty ? textWidth : (currentLineWidth + interWordSpacing + textWidth)
            
            if neededWidth <= effectiveMaxWidth || currentLineWords.isEmpty {
                currentLineWords.append(word)
                currentLineWidth = neededWidth
            } else {
                lines.append(ScriptLine(id: lineIndex, words: currentLineWords))
                lineIndex += 1
                currentLineWords = [word]
                currentLineWidth = textWidth
            }
        }
        
        if !currentLineWords.isEmpty {
            lines.append(ScriptLine(id: lineIndex, words: currentLineWords))
        }
        
        return lines
    }
    
    /// Finds the active line index corresponding to a given global word index.
    static func activeLineIndex(for currentWordIndex: Int, in lines: [ScriptLine]) -> Int {
        guard !lines.isEmpty else { return 0 }
        
        if let idx = lines.firstIndex(where: { $0.contains(wordIndex: currentWordIndex) }) {
            return idx
        }
        if let first = lines.first, currentWordIndex < first.startIndex {
            return 0
        }
        return max(0, lines.count - 1)
    }
}
