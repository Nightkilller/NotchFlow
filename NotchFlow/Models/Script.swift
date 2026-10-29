import Foundation

// MARK: - Script

/// The top-level script model.
/// A script is a user-created document that will be displayed in the teleprompter.
/// It is persisted as a JSON file in Application Support.
struct Script: Identifiable, Sendable, Equatable, Codable {
    let id: UUID
    /// User-visible title.
    var title: String
    /// The raw source text as entered or imported by the user.
    var rawText: String
    /// Structured representation for the teleprompter, built from rawText.
    var sections: [ScriptSection]
    /// When the script was created.
    let createdAt: Date
    /// When the script was last modified.
    var modifiedAt: Date

    init(
        title: String,
        rawText: String,
        sections: [ScriptSection] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        id: UUID = UUID()
    ) {
        self.id = id
        self.title = title
        self.rawText = rawText
        self.sections = sections
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    // MARK: - Computed Properties

    /// All words across all sections, in reading order.
    var allWords: [ScriptWord] {
        sections.flatMap(\.allWords)
    }

    /// Total word count.
    var wordCount: Int {
        allWords.count
    }

    /// Estimated reading duration at a given words-per-minute rate.
    func estimatedDuration(wordsPerMinute: Double = 150) -> TimeInterval {
        guard wordsPerMinute > 0 else { return 0 }
        return Double(wordCount) / wordsPerMinute * 60.0
    }

    /// Whether the script has been structured (parsed into sections/sentences/words).
    var isStructured: Bool {
        !sections.isEmpty
    }
}
