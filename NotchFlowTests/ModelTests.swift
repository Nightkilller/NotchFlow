import Testing
@testable import NotchFlow

// MARK: - ReadingPosition Tests

@Suite("ReadingPosition")
struct ReadingPositionTests {
    @Test("Initial position is before start")
    func initialPosition() {
        let pos = ReadingPosition(totalWords: 10)
        #expect(pos.currentWordIndex == -1)
        #expect(pos.isBeforeStart)
        #expect(!pos.isAtEnd)
        #expect(pos.progress == 0)
    }

    @Test("Move to next word advances position")
    func moveNext() {
        var pos = ReadingPosition(totalWords: 5)
        let moved = pos.moveToNextWord()
        #expect(moved)
        #expect(pos.currentWordIndex == 0)
        #expect(!pos.isBeforeStart)
    }

    @Test("Move to next word stops at end")
    func moveNextAtEnd() {
        var pos = ReadingPosition(currentWordIndex: 4, totalWords: 5)
        #expect(pos.isAtEnd)
        let moved = pos.moveToNextWord()
        #expect(!moved)
        #expect(pos.currentWordIndex == 4)
    }

    @Test("Move to previous word goes back")
    func movePrevious() {
        var pos = ReadingPosition(currentWordIndex: 3, totalWords: 5)
        let moved = pos.moveToPreviousWord()
        #expect(moved)
        #expect(pos.currentWordIndex == 2)
    }

    @Test("Move to previous word stops at zero")
    func movePreviousAtStart() {
        var pos = ReadingPosition(currentWordIndex: 0, totalWords: 5)
        let moved = pos.moveToPreviousWord()
        #expect(!moved)
        #expect(pos.currentWordIndex == 0)
    }

    @Test("Progress is calculated correctly")
    func progressCalc() {
        var pos = ReadingPosition(totalWords: 10)
        #expect(pos.progress == 0)

        pos.moveTo(wordIndex: 4)
        // 5 words read out of 10 = 0.5
        #expect(pos.progress == 0.5)

        pos.moveTo(wordIndex: 9)
        #expect(pos.progress == 1.0)
    }

    @Test("MoveTo clamps to valid range")
    func moveToClamps() {
        var pos = ReadingPosition(totalWords: 5)

        pos.moveTo(wordIndex: 100)
        #expect(pos.currentWordIndex == 4)

        pos.moveTo(wordIndex: -10)
        #expect(pos.currentWordIndex == -1)
    }

    @Test("Empty script is always at end")
    func emptyScript() {
        let pos = ReadingPosition(totalWords: 0)
        #expect(pos.isAtEnd)
        #expect(pos.progress == 0)
    }
}

// MARK: - ScriptWord Tests

@Suite("ScriptWord")
struct ScriptWordTests {
    @Test("Normalized text strips punctuation and lowercases")
    func normalization() {
        let word = ScriptWord(text: "Hello,", indexInSentence: 0, globalIndex: 0)
        #expect(word.normalizedText == "hello")
    }

    @Test("Normalized text preserves apostrophes")
    func apostrophe() {
        let word = ScriptWord(text: "don't", indexInSentence: 0, globalIndex: 0)
        #expect(word.normalizedText == "don't")
    }

    @Test("Normalized text handles numbers")
    func numbers() {
        let word = ScriptWord(text: "42nd", indexInSentence: 0, globalIndex: 0)
        #expect(word.normalizedText == "42nd")
    }

    @Test("Words have stable unique identities")
    func uniqueIds() {
        let w1 = ScriptWord(text: "hello", indexInSentence: 0, globalIndex: 0)
        let w2 = ScriptWord(text: "hello", indexInSentence: 1, globalIndex: 1)
        #expect(w1.id != w2.id)
    }
}

// MARK: - Script Tests

@Suite("Script")
struct ScriptTests {
    @Test("Estimated duration calculation")
    func estimatedDuration() {
        let script = Script(title: "Test", rawText: "", sections: [])
        // Empty script
        #expect(script.estimatedDuration() == 0)
    }

    @Test("Word count reflects sections")
    func wordCount() {
        let words = (0..<10).map { i in
            ScriptWord(text: "word\(i)", indexInSentence: i, globalIndex: i)
        }
        let sentence = ScriptSentence(text: "test", words: words, indexInSection: 0)
        let section = ScriptSection(sentences: [sentence], index: 0)
        let script = Script(title: "Test", rawText: "test", sections: [section])

        #expect(script.wordCount == 10)
        // 10 words at 150 wpm = 4 seconds
        #expect(script.estimatedDuration(wordsPerMinute: 150) == 4.0)
    }
}
