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
    let whisperService: LocalWhisperService
    let alignmentService: ScriptAlignmentService
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
    @Published private(set) var latestTranscript: String = ""
    @Published private(set) var audioLevel: Float = 0.0
    @Published private(set) var isSpeaking: Bool = false
    @Published private(set) var latestResult: AlignmentResult?
    @Published private(set) var activeSpeechEngineName: String = "Local Whisper (M4 Metal)"
    @Published private(set) var inferenceLatencyMs: Double = 0.0
    
    // Auto-scroll, countdown, cadence, and session timers
    private var playbackTimer: AnyCancellable?
    private var cadenceTimer: AnyCancellable?
    private var countdownTimer: AnyCancellable?
    private var sessionTimer: AnyCancellable?
    private var positionCancellable: AnyCancellable?
    private var simulationCancellable: AnyCancellable?
    private var speechCancellable: AnyCancellable?
    private var speechErrorCancellable: AnyCancellable?
    private var settingsCancellable: AnyCancellable?
    private var cancellablesSet = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(script: Script, settings: ReadingSettings = ReadingSettings()) {
        self.script = script
        self.settings = settings
        let posService = ReadingPositionService(script: script)
        self.positionService = posService
        self.position = posService.currentPosition
        
        let speech = SpeechRecognitionService()
        self.speechService = speech
        let whisper = LocalWhisperService()
        self.whisperService = whisper
        
        let alignment = ScriptAlignmentService(initialIndex: posService.currentWordIndex)
        alignment.loadScript(words: script.allWords, startIndex: posService.currentWordIndex)
        self.alignmentService = alignment
        
        self.matchingService = ScriptMatchingService(initialPosition: posService.currentWordIndex)
        self.permissionService = SpeechPermissionService()
        
        // Listen to position updates from positionService
        self.positionCancellable = posService.$currentPosition
            .sink { [weak self] newPos in
                guard let self = self else { return }
                self.position = newPos
                self.updateWhisperScriptPrompt()
            }
        
        self.updateWhisperScriptPrompt()
            
        // Listen to simulation state
        self.simulationCancellable = posService.$isSimulating
            .sink { [weak self] simulating in
                self?.isSimulating = simulating
                if simulating {
                    self?.isPlaying = true
                    self?.startSessionTimer()
                }
            }
            
        // Listen to speech listening status from both services
        Publishers.CombineLatest(speech.$isListening, whisper.$isListening)
            .map { $0 || $1 }
            .sink { [weak self] listening in
                self?.isListening = listening
            }
            .store(in: &cancellablesSet)
            
        // Listen to speech error messages
        speech.$errorMessage
            .compactMap { $0 }
            .sink { [weak self] err in
                self?.statusMessage = err
            }
            .store(in: &cancellablesSet)
            
        whisper.$errorMessage
            .compactMap { $0 }
            .sink { [weak self] err in
                self?.statusMessage = err
            }
            .store(in: &cancellablesSet)
            
        // Merge audio levels & voice activity for HUD visualization
        Publishers.CombineLatest(speech.$audioLevel, whisper.$audioLevel)
            .map { max($0, $1) }
            .sink { [weak self] level in
                self?.audioLevel = level
            }
            .store(in: &cancellablesSet)
            
        Publishers.CombineLatest(speech.$isSpeaking, whisper.$isSpeaking)
            .map { $0 || $1 }
            .sink { [weak self] speaking in
                self?.isSpeaking = speaking
            }
            .store(in: &cancellablesSet)
            
        // Listen to reading mode switching during active playback
        self.settingsCancellable = self.$settings
            .map(\.readingMode)
            .removeDuplicates()
            .sink { [weak self] newMode in
                guard let self = self, self.isPlaying else { return }
                switch newMode {
                case .voicePaced:
                    self.stopAutoScrollTimer()
                    self.startVoiceTracking()
                case .autoScroll:
                    self.speechService.stopListening()
                    self.configureAutoScrollTimer()
                case .manual:
                    self.speechService.stopListening()
                    self.stopAutoScrollTimer()
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
        whisperService.stopListening()
        speechService.stopListening()
        stopAutoScrollTimer()
        stopCadenceTimer()
        stopSessionTimer()
    }
    
    func reset() {
        pause()
        positionService.resetToBeginning()
        alignmentService.reset(to: 0)
        matchingService.reset(to: 0)
        latestResult = nil
        latestTranscript = ""
        elapsedTime = 0
    }
    
    // MARK: - Voice Paced Tracking
    
    private func updateWhisperScriptPrompt() {
        let upcoming = script.allWords
            .dropFirst(position.currentWordIndex)
            .prefix(25)
            .map(\.text)
            .joined(separator: " ")
        whisperService.scriptPrompt = upcoming
    }
    
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
            
            // Stop any existing recognition sessions
            self.whisperService.stopListening()
            self.speechService.stopListening()
            self.stopCadenceTimer()
            
            self.alignmentService.reset(to: self.position.currentWordIndex)
            self.matchingService.reset(to: self.position.currentWordIndex)
            
            do {
                switch self.settings.speechEngine {
                case .whisper:
                    if self.whisperService.isModelAvailable {
                        self.statusMessage = nil
                        self.activeSpeechEngineName = "Local Whisper (M4 Metal)"
                        try self.whisperService.startListening { [weak self] tokens, fullTranscript, isFinal, latency in
                            guard let self = self else { return }
                            self.latestTranscript = fullTranscript
                            self.inferenceLatencyMs = latency
                            
                            let res = self.alignmentService.processSpeech(
                                tokens: tokens,
                                fullTranscript: fullTranscript,
                                isFinal: isFinal
                            )
                            self.latestResult = res
                            
                            if res.wordIndex != self.positionService.currentWordIndex {
                                self.positionService.jumpToWord(at: res.wordIndex)
                                if self.positionService.isAtEnd {
                                    self.pause()
                                }
                            }
                        }
                    } else {
                        self.statusMessage = "Whisper model not found at Models/ggml-base.en.bin. Using Apple On-Device Speech."
                        try self.startAppleSpeechFallback()
                    }
                    
                case .appleSpeech:
                    try self.startAppleSpeechFallback()
                    
                case .audioCadence:
                    self.activeSpeechEngineName = "Voice Energy Cadence"
                    try self.speechService.startListening(contextualStrings: []) { _, _ in }
                    self.startCadenceTimer()
                }
                
            } catch {
                self.statusMessage = error.localizedDescription
                self.settings.readingMode = .manual
            }
        }
    }
    
    private func startAppleSpeechFallback() throws {
        self.activeSpeechEngineName = "Apple Speech (On-Device)"
        let vocabulary = self.script.allWords.map(\.text)
        
        try speechService.startListening(contextualStrings: vocabulary) { [weak self] tokens, isFinal in
            guard let self = self else { return }
            let fullTranscript = self.speechService.latestTranscript
            self.latestTranscript = fullTranscript
            
            let res = self.alignmentService.processSpeech(
                tokens: tokens,
                fullTranscript: fullTranscript,
                isFinal: isFinal
            )
            self.latestResult = res
            
            if res.wordIndex != self.positionService.currentWordIndex {
                self.positionService.jumpToWord(at: res.wordIndex)
                if self.positionService.isAtEnd {
                    self.pause()
                }
            }
        }
    }
    
    private func startCadenceTimer() {
        stopCadenceTimer()
        let wpm = max(60, min(350, settings.autoScrollSpeed))
        let interval = 60.0 / wpm
        
        cadenceTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isPlaying, self.settings.readingMode == .voicePaced else { return }
                
                // Advance words in real-time as long as speech energy is detected
                if self.isSpeaking {
                    if self.positionService.advanceWord() {
                        self.alignmentService.reset(to: self.positionService.currentWordIndex)
                        self.matchingService.reset(to: self.positionService.currentWordIndex)
                    } else if self.positionService.isAtEnd {
                        self.pause()
                    }
                }
            }
    }
    
    private func stopCadenceTimer() {
        cadenceTimer?.cancel()
        cadenceTimer = nil
    }
    
    // MARK: - Word & Sentence Navigation
    
    func stepForward() {
        if positionService.advanceWord() {
            alignmentService.reset(to: positionService.currentWordIndex)
            matchingService.reset(to: positionService.currentWordIndex)
            if positionService.isAtEnd {
                pause()
            }
        }
    }
    
    func stepBackward() {
        positionService.retreatWord()
        alignmentService.reset(to: positionService.currentWordIndex)
        matchingService.reset(to: positionService.currentWordIndex)
    }
    
    func stepSentenceForward() {
        positionService.advanceSentence()
        alignmentService.reset(to: positionService.currentWordIndex)
        matchingService.reset(to: positionService.currentWordIndex)
        if positionService.isAtEnd {
            pause()
        }
    }
    
    func stepSentenceBackward() {
        positionService.retreatSentence()
        alignmentService.reset(to: positionService.currentWordIndex)
        matchingService.reset(to: positionService.currentWordIndex)
    }
    
    func jumpToWord(at globalIndex: Int) {
        positionService.jumpToWord(at: globalIndex)
        alignmentService.reset(to: globalIndex)
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
        if isPlaying && settings.readingMode == .voicePaced {
            startCadenceTimer()
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
