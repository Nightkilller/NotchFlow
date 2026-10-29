import Foundation
import Combine

// MARK: - Word Visual State

enum WordVisualState: Equatable, Sendable {
    case completed
    case current
    case upcoming
}

// MARK: - Teleprompter View Model

/// Orchestrates teleprompter playback, current word tracking, manual navigation,
/// and auto-scroll timer progression.
@MainActor
final class TeleprompterViewModel: ObservableObject {
    
    // MARK: - Properties
    
    let script: Script
    
    @Published var position: ReadingPosition
    @Published var isPlaying: Bool = false
    @Published var settings: ReadingSettings
    @Published var elapsedTime: TimeInterval = 0
    
    // Auto-scroll and session timers
    private var playbackTimer: AnyCancellable?
    private var sessionTimer: AnyCancellable?
    
    // Flattened words lookup for rapid indexing
    private let allWords: [ScriptWord]
    
    // MARK: - Initialization
    
    init(script: Script, settings: ReadingSettings = ReadingSettings()) {
        self.script = script
        self.settings = settings
        self.allWords = script.allWords
        self.position = ReadingPosition(
            currentWordIndex: allWords.isEmpty ? -1 : 0,
            totalWords: allWords.count
        )
    }
    
    // MARK: - Computed Properties
    
    var currentWord: ScriptWord? {
        guard position.currentWordIndex >= 0 && position.currentWordIndex < allWords.count else {
            return nil
        }
        return allWords[position.currentWordIndex]
    }
    
    var currentWordId: UUID? {
        currentWord?.id
    }
    
    var currentWordDisplayIndex: Int {
        max(0, position.currentWordIndex + 1)
    }
    
    var totalWordsCount: Int {
        allWords.count
    }
    
    var progressPercent: Int {
        Int((position.progress * 100).rounded())
    }
    
    var elapsedTimeFormatted: String {
        let totalSeconds = Int(elapsedTime)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    // MARK: - Playback Controls
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func play() {
        guard !position.isAtEnd else { return }
        isPlaying = true
        startSessionTimer()
        configureAutoScrollTimer()
    }
    
    func pause() {
        isPlaying = false
        stopAutoScrollTimer()
        stopSessionTimer()
    }
    
    func reset() {
        pause()
        position.moveTo(wordIndex: allWords.isEmpty ? -1 : 0)
        elapsedTime = 0
    }
    
    // MARK: - Word & Sentence Navigation
    
    func stepForward() {
        if position.moveToNextWord() {
            if position.isAtEnd {
                pause()
            }
        }
    }
    
    func stepBackward() {
        position.moveToPreviousWord()
    }
    
    func stepSentenceForward() {
        guard let current = currentWord else {
            stepForward()
            return
        }
        
        // Find next sentence whose first word index is greater than current word
        for section in script.sections {
            for sentence in section.sentences {
                if let firstIdx = sentence.firstWordGlobalIndex, firstIdx > current.globalIndex {
                    position.moveTo(wordIndex: firstIdx)
                    return
                }
            }
        }
        // If no later sentence found, go to end
        position.moveTo(wordIndex: max(0, totalWordsCount - 1))
        pause()
    }
    
    func stepSentenceBackward() {
        guard let current = currentWord else {
            stepBackward()
            return
        }
        
        // Find the sentence containing current word or previous sentence
        var targetIndex: Int = 0
        for section in script.sections {
            for sentence in section.sentences {
                if let firstIdx = sentence.firstWordGlobalIndex,
                   let lastIdx = sentence.lastWordGlobalIndex {
                    if current.globalIndex > firstIdx && current.globalIndex <= lastIdx {
                        // Current word is in middle of sentence -> jump to sentence start
                        position.moveTo(wordIndex: firstIdx)
                        return
                    } else if firstIdx < current.globalIndex {
                        targetIndex = firstIdx
                    }
                }
            }
        }
        position.moveTo(wordIndex: targetIndex)
    }
    
    func jumpToWord(at globalIndex: Int) {
        position.moveTo(wordIndex: globalIndex)
    }
    
    // MARK: - Visual State Query
    
    func visualState(for word: ScriptWord) -> WordVisualState {
        if word.globalIndex < position.currentWordIndex {
            return .completed
        } else if word.globalIndex == position.currentWordIndex {
            return .current
        } else {
            return .upcoming
        }
    }
    
    // MARK: - Speed Tuning
    
    func updateSpeed(delta: Double) {
        let newSpeed = max(60, min(350, settings.autoScrollSpeed + delta))
        settings.autoScrollSpeed = newSpeed
        if isPlaying {
            configureAutoScrollTimer()
        }
    }
    
    // MARK: - Timers
    
    private func configureAutoScrollTimer() {
        stopAutoScrollTimer()
        
        // Only run automatic advancement timer when playing in autoScroll mode
        guard settings.readingMode == .autoScroll else { return }
        
        let wordsPerSecond = max(1.0, settings.autoScrollSpeed / 60.0)
        let interval = 1.0 / wordsPerSecond
        
        playbackTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.stepForward()
            }
    }
    
    private func stopAutoScrollTimer() {
        playbackTimer?.cancel()
        playbackTimer = nil
    }
    
    private func startSessionTimer() {
        guard sessionTimer == nil else { return }
        sessionTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.elapsedTime += 1
            }
    }
    
    private func stopSessionTimer() {
        sessionTimer?.cancel()
        sessionTimer = nil
    }
}
