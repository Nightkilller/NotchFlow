import Foundation

// MARK: - Script Sentence

/// A sentence within a script section. Contains an ordered list of words.
struct ScriptSentence: Identifiable, Sendable, Equatable, Codable {
    let id: UUID
    /// The original full sentence text, for display in previews/editor.
    let text: String
    /// Ordered words in this sentence.
    let words: [ScriptWord]
    /// Index of this sentence within its parent section.
    let indexInSection: Int

    init(text: String, words: [ScriptWord], indexInSection: Int, id: UUID = UUID()) {
        self.id = id
        self.text = text
        self.words = words
        self.indexInSection = indexInSection
    }

    /// The global index of the first word in this sentence, if any.
    var firstWordGlobalIndex: Int? {
        words.first?.globalIndex
    }

    /// The global index of the last word in this sentence, if any.
    var lastWordGlobalIndex: Int? {
        words.last?.globalIndex
    }
}
