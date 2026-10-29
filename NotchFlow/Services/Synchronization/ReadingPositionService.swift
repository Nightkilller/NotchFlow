import Foundation
import Combine

// MARK: - Reading Position Service

/// Dedicated domain service for tracking and advancing the user's reading position
/// within a structured script. Independent of SwiftUI.
@MainActor
final class ReadingPositionService: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var currentPosition: ReadingPosition
    @Published private(set) var isSimulating: Bool = false
    
    let script: Script
    private let allWords: [ScriptWord]
    private var simulationCancellable: AnyCancellable?
    
    // MARK: - Initialization
    
    init(script: Script, initialWordIndex: Int = 0) {
        self.script = script
        self.allWords = script.allWords
        let initialClamped = allWords.isEmpty ? -1 : max(-1, min(initialWordIndex, allWords.count - 1))
        self.currentPosition = ReadingPosition(
            currentWordIndex: initialClamped,
            totalWords: allWords.count
        )
    }
    
    // MARK: - Position Queries
    
    var currentWord: ScriptWord? {
        guard currentPosition.currentWordIndex >= 0 && currentPosition.currentWordIndex < allWords.count else {
            return nil
        }
        return allWords[currentPosition.currentWordIndex]
    }
    
    var currentWordIndex: Int {
        currentPosition.currentWordIndex
    }
    
    var totalWords: Int {
        allWords.count
    }
    
    var progress: Double {
        currentPosition.progress
    }
    
    var isAtEnd: Bool {
        currentPosition.isAtEnd
    }
    
    var isAtStart: Bool {
        currentPosition.isAtStart
    }
    
    /// Returns the sentence containing the current word, if any.
    var currentSentence: ScriptSentence? {
        guard let current = currentWord else { return nil }
        for section in script.sections {
            for sentence in section.sentences {
                if let first = sentence.firstWordGlobalIndex,
                   let last = sentence.lastWordGlobalIndex,
                   current.globalIndex >= first && current.globalIndex <= last {
                    return sentence
                }
            }
        }
        return nil
    }
    
    /// Returns whether a given sentence contains the current active reading word.
    func isCurrentSentence(_ sentence: ScriptSentence) -> Bool {
        guard let current = currentWord,
              let first = sentence.firstWordGlobalIndex,
              let last = sentence.lastWordGlobalIndex else {
            return false
        }
        return current.globalIndex >= first && current.globalIndex <= last
    }
    
    /// Returns the visual state (completed, current, upcoming) for a word.
    func visualState(for word: ScriptWord) -> WordVisualState {
        if word.globalIndex < currentPosition.currentWordIndex {
            return .completed
        } else if word.globalIndex == currentPosition.currentWordIndex {
            return .current
        } else {
            return .upcoming
        }
    }
    
    // MARK: - Navigation Operations
    
    @discardableResult
    func advanceWord() -> Bool {
        let changed = currentPosition.moveToNextWord()
        if currentPosition.isAtEnd {
            stopSimulation()
        }
        return changed
    }
    
    @discardableResult
    func retreatWord() -> Bool {
        currentPosition.moveToPreviousWord()
    }
    
    func jumpToWord(at globalIndex: Int) {
        currentPosition.moveTo(wordIndex: globalIndex)
    }
    
    func resetToBeginning() {
        stopSimulation()
        currentPosition.moveTo(wordIndex: allWords.isEmpty ? -1 : 0)
    }
    
    // MARK: - Sentence Navigation
    
    func advanceSentence() {
        guard let current = currentWord else {
            advanceWord()
            return
        }
        
        for section in script.sections {
            for sentence in section.sentences {
                if let first = sentence.firstWordGlobalIndex, first > current.globalIndex {
                    currentPosition.moveTo(wordIndex: first)
                    return
                }
            }
        }
        currentPosition.moveTo(wordIndex: max(0, totalWords - 1))
        stopSimulation()
    }
    
    func retreatSentence() {
        guard let current = currentWord else {
            retreatWord()
            return
        }
        
        var targetIndex = 0
        for section in script.sections {
            for sentence in section.sentences {
                if let first = sentence.firstWordGlobalIndex,
                   let last = sentence.lastWordGlobalIndex {
                    if current.globalIndex > first && current.globalIndex <= last {
                        currentPosition.moveTo(wordIndex: first)
                        return
                    } else if first < current.globalIndex {
                        targetIndex = first
                    }
                }
            }
        }
        currentPosition.moveTo(wordIndex: targetIndex)
    }
    
    // MARK: - Simulated Reading Mode (Debug / Demo Mode)
    
    /// Starts automated simulation stepping word-by-word at the specified WPM rate.
    /// Useful for QA, testing animations, and reading without microphone.
    func startSimulation(wordsPerMinute: Double = 150) {
        stopSimulation()
        guard !allWords.isEmpty && !isAtEnd else { return }
        
        isSimulating = true
        let interval = max(0.05, 60.0 / max(30.0, wordsPerMinute))
        
        simulationCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if !self.advanceWord() {
                    self.stopSimulation()
                }
            }
    }
    
    func stopSimulation() {
        isSimulating = false
        simulationCancellable?.cancel()
        simulationCancellable = nil
    }
    
    func toggleSimulation(wordsPerMinute: Double = 150) {
        if isSimulating {
            stopSimulation()
        } else {
            startSimulation(wordsPerMinute: wordsPerMinute)
        }
    }
}
