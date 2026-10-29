import Foundation

// MARK: - Text Normalization Service

/// Normalizes script text and recognized speech transcripts to maximize matching accuracy.
/// Handles punctuation stripping, number-to-words expansion, and fuzzy Levenshtein distance.
enum TextNormalizationService {
    
    // MARK: - Normalization
    
    /// Normalizes a single token or phrase: lowercased, non-letters/numbers removed except apostrophes.
    static func normalize(_ text: String) -> String {
        var lower = text.lowercased()
        
        // Expand currency: $5 -> 5 dollars
        lower = lower.replacingOccurrences(of: "\\$(\\d+)", with: "$1 dollars", options: .regularExpression)
        lower = lower.replacingOccurrences(of: "$", with: " dollars ")
        
        // Expand common symbols
        lower = lower.replacingOccurrences(of: "%", with: " percent")
        lower = lower.replacingOccurrences(of: "&", with: " and ")
        lower = lower.replacingOccurrences(of: "@", with: " at ")
        
        // Expand common ordinal numbers
        lower = lower.replacingOccurrences(of: "\\b1st\\b", with: "first", options: .regularExpression)
        lower = lower.replacingOccurrences(of: "\\b2nd\\b", with: "second", options: .regularExpression)
        lower = lower.replacingOccurrences(of: "\\b3rd\\b", with: "third", options: .regularExpression)
        lower = lower.replacingOccurrences(of: "\\b4th\\b", with: "fourth", options: .regularExpression)
        
        // Expand single digits
        let digitWords = ["0": "zero", "1": "one", "2": "two", "3": "three", "4": "four",
                          "5": "five", "6": "six", "7": "seven", "8": "eight", "9": "nine"]
        for (digit, word) in digitWords {
            lower = lower.replacingOccurrences(of: "\\b\(digit)\\b", with: word, options: .regularExpression)
        }
        
        // Filter out punctuation except apostrophe
        let filtered = lower.filter { char in
            char.isLetter || char.isNumber || char.isWhitespace || char == "'" || char == "\u{2019}"
        }
        
        return filtered.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
    
    /// Breaks normalized text into an ordered list of clean words.
    static func tokenize(_ text: String) -> [String] {
        let cleaned = normalize(text)
        return cleaned.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }
    
    // MARK: - Fuzzy Matching & Levenshtein Distance
    
    /// Calculates Levenshtein edit distance between two strings.
    static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        if s1 == s2 { return 0 }
        
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: b.count + 1), count: a.count + 1)
        
        for i in 0...a.count {
            matrix[i][0] = i
        }
        for j in 0...b.count {
            matrix[0][j] = j
        }
        
        for i in 1...a.count {
            for j in 1...b.count {
                if a[i - 1] == b[j - 1] {
                    matrix[i][j] = matrix[i - 1][j - 1]
                } else {
                    matrix[i][j] = min(
                        matrix[i - 1][j] + 1,     // deletion
                        matrix[i][j - 1] + 1,     // insertion
                        matrix[i - 1][j - 1] + 1  // substitution
                    )
                }
            }
        }
        
        return matrix[a.count][b.count]
    }
    
    /// Evaluates if two words match based on the project specification's fuzzy criteria:
    /// - Word length < 4: exact match (edit distance 0)
    /// - Word length 4-7: edit distance <= 1
    /// - Word length >= 8: edit distance <= 2
    static func wordsMatch(_ w1: String, _ w2: String) -> Bool {
        let norm1 = normalize(w1)
        let norm2 = normalize(w2)
        
        if norm1 == norm2 { return true }
        
        let len = max(norm1.count, norm2.count)
        let dist = levenshteinDistance(norm1, norm2)
        
        if len < 4 {
            return dist == 0
        } else if len <= 7 {
            return dist <= 1
        } else {
            return dist <= 2
        }
    }
}
