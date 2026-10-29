import Foundation
import Combine

// MARK: - Teleprompter View Model

/// Orchestrates teleprompter playback, current word tracking, speech synchronization,
/// auto-scrolling, and manual navigation.
@MainActor
final class TeleprompterViewModel: ObservableObject {
    
    // MARK: - Properties
    
    let script: Script
    let positionService: ReadingPositionService
    let speechService: SpeechRecognitionService
    let matchingService: ScriptMatchingService
    let permissionService: SpeechPermissionService
    
    @Published var position: ReadingPosition
    @Published var isPlaying: Bool = false
    @Published var settings: ReadingSettings
    @Published var elapsedTime: TimeInterval = 0
    @Published var isSimulating: Bool = false
    @Published var isListening: Bool = false
    @Published var statusMessage: String?
    @Published var countdownRemaining: Int? = nil
    
    // Auto-scroll, countdown, and session timers
    private var playbackTimer: AnyCancellable?
    private var countdownTimer: AnyCancellable?
    private var sessionTimer: AnyCancellable?
    private var positionCancellable: AnyCancellable?
    private var simulationCancellable: AnyCancellable?
    private var speechCancellable: AnyCancellable?
    private var speechErrorCancellable: AnyCancellable?
    
    // MARK: - Initialization
    
    init(script: Script, settings: ReadingSettings = ReadingSettings()) {
        self.script = script
        self.settings = settings
        let posService = ReadingPositionService(script: script)
        self.positionService = posService
        self.position = posService.currentPosition
        
        let speech = SpeechRecognitionService()
        self.speechService = speech
        self.matchingService = ScriptMatchingService(initialPosition: posService.currentWordIndex)
        self.permissionService = SpeechPermissionService()
        
        // Listen to position updates from positionService
        self.positionCancellable = posService.$currentPosition
            .sink { [weak self] newPos in
                self?.position = newPos
            }
            
        // Listen to simulation state
        self.simulationCancellable = posService.$isSimulating
            .sink { [weak self] simulating in
                self?.isSimulating = simulating
                if simulating {
                    self?.isPlaying = true
                    self?.startSessionTimer()
                }
            }
            
        // Listen to speech listening status
        self.speechCancellable = speech.$isListening
            .sink { [weak self] listening in
                self?.isListening = listening
            }
            
        // Listen to speech error messages
        self.speechErrorCancellable = speech.$errorMessage
            .compactMap { $0 }
            .sink { [weak self] err in
                self?.statusMessage = err
            }
    }
    
    // MARK: - Computed Properties
    
    var currentWord: ScriptWord? {
        positionService.currentWord
    }
    
    var currentWordId: UUID? {
        currentWord?.id
    }
    
    var currentSentenceId: UUID? {
        positionService.currentSentence?.id
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
        if isPlaying || countdownRemaining != nil {
            pause()
        } else {
            play()
        }
    }
    
    func play() {
        guard !position.isAtEnd else { return }
        
        // Pre-start countdown if starting from beginning and configured
        if settings.countdownSeconds > 0 && position.currentWordIndex <= 0 {
            startCountdown()
        } else {
            beginPlayback()
        }
    }
    
    private func startCountdown() {
        stopCountdown()
        countdownRemaining = settings.countdownSeconds
        
        countdownTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if let current = self.countdownRemaining {
                    if current > 1 {
                        self.countdownRemaining = current - 1
                    } else {
                        self.stopCountdown()
                        self.beginPlayback()
                    }
                }
            }
    }
    
    private func stopCountdown() {
        countdownTimer?.cancel()
        countdownTimer = nil
        countdownRemaining = nil
    }
    
    private func beginPlayback() {
        isPlaying = true
        startSessionTimer()
        
        switch settings.readingMode {
        case .voicePaced:
            startVoiceTracking()
        case .autoScroll:
            configureAutoScrollTimer()
        case .manual:
            break
        }
    }
    
    func pause() {
        stopCountdown()
        isPlaying = false
        positionService.stopSimulation()
        speechService.stopListening()
        stopAutoScrollTimer()
        stopSessionTimer()
    }
    
    func reset() {
        pause()
        positionService.resetToBeginning()
        matchingService.reset(to: 0)
        elapsedTime = 0
    }
    
    // MARK: - Voice Paced Tracking
    
    private func startVoiceTracking() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if !self.permissionService.isFullyAuthorized {
                let granted = await self.permissionService.requestPermissions()
                guard granted else {
                    self.statusMessage = "Microphone access is required for voice-paced reading. Switched to manual."
                    self.settings.readingMode = .manual
                    return
                }
            }
            
            do {
                matchingService.reset(to: position.currentWordIndex)
                try speechService.startListening { [weak self] tokens, isFinal in
                    guard let self = self else { return }
                    let matched = self.matchingService.processSpeechTokens(
                        tokens,
                        in: self.script.allWords,
                        isFinal: isFinal
                    )
                    if matched != self.positionService.currentWordIndex {
                        self.positionService.jumpToWord(at: matched)
                        if self.positionService.isAtEnd {
                            self.pause()
                        }
                    }
                }
            } catch {
                self.statusMessage = error.localizedDescription
                self.settings.readingMode = .manual
            }
        }
    }
    
    // MARK: - Word & Sentence Navigation
    
    func stepForward() {
        if positionService.advanceWord() {
            matchingService.reset(to: positionService.currentWordIndex)
            if positionService.isAtEnd {
                pause()
            }
        }
    }
    
    func stepBackward() {
        positionService.retreatWord()
        matchingService.reset(to: positionService.currentWordIndex)
    }
    
    func stepSentenceForward() {
        positionService.advanceSentence()
        matchingService.reset(to: positionService.currentWordIndex)
        if positionService.isAtEnd {
            pause()
        }
    }
    
    func stepSentenceBackward() {
        positionService.retreatSentence()
        matchingService.reset(to: positionService.currentWordIndex)
    }
    
    func jumpToWord(at globalIndex: Int) {
        positionService.jumpToWord(at: globalIndex)
        matchingService.reset(to: globalIndex)
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
            speechService.stopListening()
            isPlaying = true
            startSessionTimer()
            positionService.startSimulation(wordsPerMinute: settings.autoScrollSpeed)
        }
    }
    
    // MARK: - Speed & Font Tuning
    
    func updateSpeed(delta: Double) {
        let newSpeed = max(60, min(350, settings.autoScrollSpeed + delta))
        settings.autoScrollSpeed = newSpeed
        if isPlaying && settings.readingMode == .autoScroll {
            configureAutoScrollTimer()
        }
        if isSimulating {
            positionService.startSimulation(wordsPerMinute: newSpeed)
        }
    }
    
    func updateFontSize(delta: CGFloat) {
        let newSize = max(AppTypography.teleprompterMinSize, min(AppTypography.teleprompterMaxSize, settings.fontSize + delta))
        settings.fontSize = newSize
    }
    
    // MARK: - Timers
    
    private func configureAutoScrollTimer() {
        stopAutoScrollTimer()
        
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
