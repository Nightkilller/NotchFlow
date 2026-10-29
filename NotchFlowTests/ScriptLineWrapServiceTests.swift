import Testing
import Foundation
@testable import NotchFlow

@Suite("ScriptLineWrapService")
struct ScriptLineWrapServiceTests {
    
    private func makeWords(_ text: String) -> [ScriptWord] {
        let tokens = text.split(separator: " ").map(String.init)
        return tokens.enumerated().map { idx, token in
            ScriptWord(text: token, indexInSentence: idx, globalIndex: idx)
        }
    }
    
    @Test("Empty words produce empty lines")
    func emptyWords() {
        let lines = ScriptLineWrapService.computeLines(words: [], maxWidth: 500, fontSize: 20)
        #expect(lines.isEmpty)
        
        let activeIdx = ScriptLineWrapService.activeLineIndex(for: 0, in: lines)
        #expect(activeIdx == 0)
    }
    
    @Test("Short text fits on a single line")
    func singleLine() {
        let words = makeWords("Hello world")
        let lines = ScriptLineWrapService.computeLines(words: words, maxWidth: 500, fontSize: 20)
        #expect(lines.count == 1)
        #expect(lines[0].words.count == 2)
        #expect(lines[0].startIndex == 0)
        #expect(lines[0].endIndex == 1)
    }
    
    @Test("Longer text wraps into multiple lines deterministically")
    func multiLineWrapping() {
        let words = makeWords("Welcome to NotchFlow the native speech teleprompter designed for your MacBook Air")
        let lines = ScriptLineWrapService.computeLines(words: words, maxWidth: 300, fontSize: 20)
        #expect(lines.count > 1)
        
        // Every word must be accounted for in reading order
        let flattenedWords = lines.flatMap(\.words)
        #expect(flattenedWords.count == words.count)
        #expect(flattenedWords.map(\.globalIndex) == words.map(\.globalIndex))
    }
    
    @Test("Active line index tracks word position accurately")
    func activeLineTracking() {
        let words = makeWords("Line zero has several words. Line one has more words. Line two concludes.")
        let lines = ScriptLineWrapService.computeLines(words: words, maxWidth: 260, fontSize: 20)
        #expect(lines.count >= 3)
        
        // First word of line 0
        #expect(ScriptLineWrapService.activeLineIndex(for: 0, in: lines) == 0)
        
        // Word in line 1
        let line1FirstWordIndex = lines[1].startIndex
        #expect(ScriptLineWrapService.activeLineIndex(for: line1FirstWordIndex, in: lines) == 1)
        
        // Word in line 2
        let line2FirstWordIndex = lines[2].startIndex
        #expect(ScriptLineWrapService.activeLineIndex(for: line2FirstWordIndex, in: lines) == 2)
        
        // Past end clamped to last line
        #expect(ScriptLineWrapService.activeLineIndex(for: 999, in: lines) == lines.count - 1)
    }
    
    @Test("ScriptLine contains check works correctly")
    func scriptLineContains() {
        let words = makeWords("One two three four five")
        let line = ScriptLine(id: 0, words: words)
        #expect(line.contains(wordIndex: 0))
        #expect(line.contains(wordIndex: 2))
        #expect(line.contains(wordIndex: 4))
        #expect(!line.contains(wordIndex: -1))
        #expect(!line.contains(wordIndex: 5))
    }
}
