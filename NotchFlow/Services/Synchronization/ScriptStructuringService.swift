import Foundation
import NaturalLanguage

// MARK: - Script Structuring Service

/// Converts raw input text into a fully structured `Script` model
/// composed of sections (paragraphs), sentences, and words with stable identifiers.
enum ScriptStructuringService {
    
    /// Structures a raw text string into a `Script` object.
    /// - Parameters:
    ///   - rawText: Raw unformatted or typed text.
    ///   - title: Title for the script.
    ///   - existingId: Optional existing UUID to preserve identity across edits.
    /// - Returns: A validated, structured `Script`.
    static func structure(rawText: String, title: String = "Untitled Script", existingId: UUID? = nil) -> Script {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Script(
                title: title,
                rawText: rawText,
                sections: [],
                id: existingId ?? UUID()
            )
        }
        
        // Split text by paragraph breaks (double newline or single newline with content)
        let paragraphStrings = trimmed.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        var sections: [ScriptSection] = []
        var globalWordIndex = 0
        
        for (sectionIdx, paragraph) in paragraphStrings.enumerated() {
            let sentences = parseSentences(
                from: paragraph,
                sectionIndex: sectionIdx,
                startingGlobalWordIndex: &globalWordIndex
            )
            
            if !sentences.isEmpty {
                let section = ScriptSection(
                    title: nil,
                    sentences: sentences,
                    index: sectionIdx
                )
                sections.append(section)
            }
        }
        
        return Script(
            title: title,
            rawText: rawText,
            sections: sections,
            id: existingId ?? UUID()
        )
    }
    
    // MARK: - Internal Sentence & Word Parsing
    
    private static func parseSentences(
        from paragraph: String,
        sectionIndex: Int,
        startingGlobalWordIndex: inout Int
    ) -> [ScriptSentence] {
        var sentenceStrings: [String] = []
        
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = paragraph
        
        tokenizer.enumerateTokens(in: paragraph.startIndex..<paragraph.endIndex) { range, _ in
            let sentence = String(paragraph[range]).trimmingCharacters(in: .whitespaces)
            if !sentence.isEmpty {
                sentenceStrings.append(sentence)
            }
            return true
        }
        
        // Fallback if NLTokenizer found nothing but paragraph is non-empty
        if sentenceStrings.isEmpty && !paragraph.isEmpty {
            sentenceStrings.append(paragraph)
        }
        
        var sentences: [ScriptSentence] = []
        
        for (sentenceIdx, sentenceText) in sentenceStrings.enumerated() {
            // Split into whitespace-delimited tokens while preserving attached punctuation
            let rawWordTokens = sentenceText.split(whereSeparator: { $0.isWhitespace })
            
            var words: [ScriptWord] = []
            for (wordIdxInSentence, token) in rawWordTokens.enumerated() {
                let word = ScriptWord(
                    text: String(token),
                    indexInSentence: wordIdxInSentence,
                    globalIndex: startingGlobalWordIndex
                )
                words.append(word)
                startingGlobalWordIndex += 1
            }
            
            if !words.isEmpty {
                let sentence = ScriptSentence(
                    text: sentenceText,
                    words: words,
                    indexInSection: sentenceIdx
                )
                sentences.append(sentence)
            }
        }
        
        return sentences
    }
}
