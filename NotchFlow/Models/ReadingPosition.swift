import Foundation

// MARK: - Reading Position

/// Tracks the current reading position within a structured script.
/// Used by both the teleprompter view and the synchronization engine.
struct ReadingPosition: Sendable, Equatable {
    /// Index of the current word in the script's flattened word list.
    /// A value of -1 means "not started".
    var currentWordIndex: Int

    /// Total number of words in the script.
    let totalWords: Int

    init(currentWordIndex: Int = -1, totalWords: Int) {
        self.currentWordIndex = currentWordIndex
        self.totalWords = totalWords
    }

    // MARK: Navigation

    /// Whether the position is at the very beginning (before the first word).
    var isAtStart: Bool {
        currentWordIndex <= 0
    }

    /// Whether the position has reached the last word.
    var isAtEnd: Bool {
        guard totalWords > 0 else { return true }
        return currentWordIndex >= totalWords - 1
    }

    /// Whether reading has not yet started.
    var isBeforeStart: Bool {
        currentWordIndex < 0
    }

    /// Progress as a fraction from 0.0 to 1.0.
    var progress: Double {
        guard totalWords > 0 else { return 0 }
        if currentWordIndex < 0 { return 0 }
        return min(1.0, Double(currentWordIndex + 1) / Double(totalWords))
    }

    /// Move to the next word if possible. Returns true if position changed.
    @discardableResult
    mutating func moveToNextWord() -> Bool {
        guard !isAtEnd else { return false }
        currentWordIndex += 1
        return true
    }

    /// Move to the previous word if possible. Returns true if position changed.
    @discardableResult
    mutating func moveToPreviousWord() -> Bool {
        guard currentWordIndex > 0 else { return false }
        currentWordIndex -= 1
        return true
    }

    /// Move to a specific word index, clamped to valid range.
    mutating func moveTo(wordIndex: Int) {
        currentWordIndex = max(-1, min(wordIndex, totalWords - 1))
    }
}
