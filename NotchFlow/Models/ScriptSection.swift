import Foundation

// MARK: - Script Section

/// A logical section (paragraph or heading group) within a script.
/// Sections provide paragraph-level structure for navigation and display.
struct ScriptSection: Identifiable, Sendable, Equatable, Codable {
    let id: UUID
    /// Optional section title (from markdown headings, document structure, etc.).
    let title: String?
    /// Ordered sentences in this section.
    let sentences: [ScriptSentence]
    /// Index of this section within the script.
    let index: Int

    init(title: String? = nil, sentences: [ScriptSentence], index: Int, id: UUID = UUID()) {
        self.id = id
        self.title = title
        self.sentences = sentences
        self.index = index
    }

    /// All words in this section, flattened.
    var allWords: [ScriptWord] {
        sentences.flatMap(\.words)
    }

    /// The global index of the first word in this section, if any.
    var firstWordGlobalIndex: Int? {
        sentences.first?.firstWordGlobalIndex
    }

    /// The global index of the last word in this section, if any.
    var lastWordGlobalIndex: Int? {
        sentences.last?.lastWordGlobalIndex
    }
}
