import Foundation
import Combine

// MARK: - Teleprompter View Model

/// Orchestrates teleprompter playback, current word tracking, manual navigation,
/// and auto-scroll / simulation timer progression.
@MainActor
final class TeleprompterViewModel: ObservableObject {
    
    // MARK: - Properties
    
    let script: Script
    let positionService: ReadingPositionService
    
    @Published var position: ReadingPosition
    @Published var isPlaying: Bool = false
    @Published var settings: ReadingSettings
    @Published var elapsedTime: TimeInterval = 0
    @Published var isSimulating: Bool = false
    
    // Auto-scroll and session timers
    private var playbackTimer: AnyCancellable?
    private var sessionTimer: AnyCancellable?
    private var positionCancellable: AnyCancellable?
    private var simulationCancellable: AnyCancellable?
    
    // MARK: - Initialization
    
    init(script: Script, settings: ReadingSettings = ReadingSettings()) {
        self.script = script
        self.settings = settings
        let service = ReadingPositionService(script: script)
        self.positionService = service
        self.position = service.currentPosition
        
        // Listen to position updates from the service
        self.positionCancellable = service.$currentPosition
            .sink { [weak self] newPos in
                self?.position = newPos
            }
            
        self.simulationCancellable = service.$isSimulating
            .sink { [weak self] simulating in
                self?.isSimulating = simulating
                if simulating {
                    self?.isPlaying = true
                    self?.startSessionTimer()
                }
            }
    }
    
    // MARK: - Computed Properties
    
    var currentWord: ScriptWord? {
        positionService.currentWord
    }
    
    var currentWordId: UUID? {
        currentWord?.id
    }
    
    var currentWordDisplayIndex: Int {
        max(0, position.currentWordIndex + 1)
    }
    
    var totalWordsCount: Int {
        positionService.totalWords
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
        positionService.stopSimulation()
        stopAutoScrollTimer()
        stopSessionTimer()
    }
    
    func reset() {
        pause()
        positionService.resetToBeginning()
        elapsedTime = 0
    }
    
    // MARK: - Word & Sentence Navigation
    
    func stepForward() {
        if positionService.advanceWord() {
            if positionService.isAtEnd {
                pause()
            }
        }
    }
    
    func stepBackward() {
        positionService.retreatWord()
    }
    
    func stepSentenceForward() {
        positionService.advanceSentence()
        if positionService.isAtEnd {
            pause()
        }
    }
    
    func stepSentenceBackward() {
        positionService.retreatSentence()
    }
    
    func jumpToWord(at globalIndex: Int) {
        positionService.jumpToWord(at: globalIndex)
    }
    
    // MARK: - Visual State Query
    
    func visualState(for word: ScriptWord) -> WordVisualState {
        positionService.visualState(for: word)
    }
    
    func isCurrentSentence(_ sentence: ScriptSentence) -> Bool {
        positionService.isCurrentSentence(sentence)
    }
    
    // MARK: - Simulation Mode (Debug reading without mic)
    
    func toggleSimulation() {
        if isSimulating {
            pause()
        } else {
            isPlaying = true
            startSessionTimer()
            positionService.startSimulation(wordsPerMinute: settings.autoScrollSpeed)
        }
    }
    
    // MARK: - Speed Tuning
    
    func updateSpeed(delta: Double) {
        let newSpeed = max(60, min(350, settings.autoScrollSpeed + delta))
        settings.autoScrollSpeed = newSpeed
        if isPlaying {
            configureAutoScrollTimer()
        }
        if isSimulating {
            positionService.startSimulation(wordsPerMinute: newSpeed)
        }
    }
    
    // MARK: - Timers
    
    private func configureAutoScrollTimer() {
        stopAutoScrollTimer()
        
        // Only run automatic advancement timer when playing in autoScroll mode
        guard settings.readingMode == .autoScroll && !isSimulating else { return }
        
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
