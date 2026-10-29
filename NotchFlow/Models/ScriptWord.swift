import Foundation

// MARK: - Script Word

/// A single word in a script, with a stable identity for efficient UI updates.
/// Words preserve the original text (including attached punctuation) for display,
/// and provide a normalized form for speech matching.
struct ScriptWord: Identifiable, Sendable, Equatable, Codable {
    let id: UUID
    /// The original text as authored — includes punctuation, capitalization.
    let text: String
    /// Index of this word within its parent sentence.
    let indexInSentence: Int
    /// Index of this word within the entire script (global position).
    let globalIndex: Int

    init(text: String, indexInSentence: Int, globalIndex: Int, id: UUID = UUID()) {
        self.id = id
        self.text = text
        self.indexInSentence = indexInSentence
        self.globalIndex = globalIndex
    }

    /// Normalized text for speech matching: lowercased, punctuation stripped.
    var normalizedText: String {
        text.lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "'" || $0 == "\u{2019}" }
    }
}
