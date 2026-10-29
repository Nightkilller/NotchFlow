import Foundation
import Speech
import AVFoundation
import Combine

// MARK: - Speech Recognition Service

/// Manages the microphone audio engine, speech recognition task, on-device transcription,
/// voice activity detection (VAD), and streaming partial and final recognition tokens.
@MainActor
final class SpeechRecognitionService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var isListening: Bool = false
    @Published private(set) var latestTranscript: String = ""
    @Published private(set) var recentTokens: [String] = []
    @Published private(set) var audioLevel: Float = 0.0
    @Published private(set) var isSpeaking: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Internal Audio & Recognition State
    
    private var audioEngine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private var onTokensUpdated: (([String], Bool) -> Void)?
    private var lastSpeechTime: DispatchTime = .now()
    private var speechDecayTimer: AnyCancellable?
    
    // MARK: - Initialization
    
    init(locale: Locale = Locale.current) {
        if let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable {
            self.speechRecognizer = recognizer
        } else if let fallback = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) {
            self.speechRecognizer = fallback
        } else {
            self.speechRecognizer = SFSpeechRecognizer()
        }
    }
    
    func setLocale(_ locale: Locale) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
    }
    
    // MARK: - Start / Stop Listening
    
    /// Starts microphone audio streaming and real-time speech transcription.
    /// - Parameters:
    ///   - contextualStrings: Key vocabulary terms from the script to prime the recognition language model.
    ///   - onTokens: Closure invoked whenever new partial or final speech tokens are recognized.
    func startListening(
        contextualStrings: [String] = [],
        onTokens: @escaping ([String], Bool) -> Void
    ) throws {
        guard !isListening else { return }
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw AppError.speechRecognitionUnavailable
        }
        
        self.onTokensUpdated = onTokens
        
        let engine = AVAudioEngine()
        self.audioEngine = engine
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.taskHint = .dictation
        
        // Prime the recognizer with vocabulary from the user's script
        if !contextualStrings.isEmpty {
            let uniqueTerms = Array(Set(contextualStrings.map { TextNormalizationService.normalize($0) }.filter { !$0.isEmpty })).prefix(100)
            request.contextualStrings = Array(uniqueTerms)
        }
        
        // Restrict strictly to on-device recognition when supported so voice data NEVER leaves the Mac
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        } else {
            request.requiresOnDeviceRecognition = false
        }
        
        self.recognitionRequest = request
        
        let inputNode = engine.inputNode
        var recordingFormat = inputNode.outputFormat(forBus: 0)
        if recordingFormat.sampleRate == 0 || recordingFormat.channelCount == 0 {
            if let fallbackFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) {
                recordingFormat = fallbackFormat
            }
        }
        
        // Start speech decay timer (runs at 12Hz to detect pauses and smooth visual audio levels)
        speechDecayTimer?.cancel()
        speechDecayTimer = Timer.publish(every: 0.08, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.isSpeaking {
                    let elapsed = DispatchTime.now().uptimeNanoseconds - self.lastSpeechTime.uptimeNanoseconds
                    // 350ms of silence indicates a natural pause / breathing
                    if elapsed > 350_000_000 {
                        self.isSpeaking = false
                    }
                }
                if self.audioLevel > 0.02 {
                    self.audioLevel *= 0.82
                } else {
                    self.audioLevel = 0
                }
            }
        
        // Install tap in a nonisolated static context with RMS Voice Activity Detection
        Self.installAudioTap(on: inputNode, format: recordingFormat, request: request) { [weak self] level, isVoice in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.audioLevel = max(self.audioLevel * 0.35, level)
                if isVoice {
                    self.lastSpeechTime = .now()
                    if !self.isSpeaking {
                        self.isSpeaking = true
                    }
                }
            }
        }
        
        engine.prepare()
        try engine.start()
        
        self.recognitionTask = Self.createRecognitionTask(recognizer: recognizer, request: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let result = result {
                    let transcript = result.bestTranscription.formattedString
                    if transcript != self.latestTranscript || result.isFinal {
                        self.latestTranscript = transcript
                        let tokens = TextNormalizationService.tokenize(transcript)
                        self.recentTokens = tokens
                        self.onTokensUpdated?(tokens, result.isFinal)
                    }
                }
                
                if let error = error {
                    AppLogger.speech.error("Recognition task error: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                    // If error occurs while listening, stop cleanly
                    if self.isListening {
                        self.stopListening()
                    }
                }
            }
        }
        
        self.isListening = true
        AppLogger.speech.info("Speech recognition started successfully with Voice Activity Detection")
    }
    
    /// Stops audio capture and terminates the recognition task immediately.
    func stopListening() {
        guard isListening else { return }
        
        speechDecayTimer?.cancel()
        speechDecayTimer = nil
        isSpeaking = false
        audioLevel = 0.0
        
        // Remove audio tap safely
        if let engine = audioEngine {
            if engine.inputNode.numberOfInputs > 0 {
                engine.inputNode.removeTap(onBus: 0)
            }
            if engine.isRunning {
                engine.stop()
            }
        }
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        onTokensUpdated = nil
        isListening = false
        
        AppLogger.speech.info("Speech recognition stopped and microphone released")
    }
    
    /// Installs an audio tap without @MainActor isolation so the CoreAudio callback avoids dispatch queue assertions.
    nonisolated private static func installAudioTap(
        on inputNode: AVAudioNode,
        format: AVAudioFormat,
        request: SFSpeechAudioBufferRecognitionRequest,
        onLevel: @escaping @Sendable (Float, Bool) -> Void
    ) {
        var sampleInterval = 0
        var noiseFloor: Float = 0.005
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
            
            sampleInterval &+= 1
            if sampleInterval % 2 == 0 {
                if let channelData = buffer.floatChannelData?[0] {
                    let frameLength = Int(buffer.frameLength)
                    if frameLength > 0 {
                        var sum: Float = 0
                        var i = 0
                        while i < frameLength {
                            let s = channelData[i]
                            sum += s * s
                            i += 4
                        }
                        let rms = sqrt(sum / Float(max(1, frameLength / 4)))
                        let dB = 20 * log10(max(rms, 0.00001))
                        let normalized = max(0, min(1, (dB + 45) / 35))
                        
                        // Adaptive voice activity detection (works reliably even with soft voices)
                        let isVoice = (rms > noiseFloor * 1.6 && rms > 0.004) || normalized > 0.06
                        if !isVoice {
                            noiseFloor = min(0.02, noiseFloor * 0.98 + rms * 0.02)
                        }
                        
                        onLevel(normalized, isVoice)
                    }
                }
            }
        }
    }
    
    /// Creates recognition task in nonisolated context to prevent actor assertion on recognition daemon callbacks.
    nonisolated private static func createRecognitionTask(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        handler: @escaping (SFSpeechRecognitionResult?, (any Error)?) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request, resultHandler: handler)
    }
}
