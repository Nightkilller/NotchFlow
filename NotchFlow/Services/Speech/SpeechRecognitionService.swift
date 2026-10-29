import Foundation
import Speech
import AVFoundation

// MARK: - Speech Recognition Service

/// Manages the microphone audio engine, speech recognition task, on-device transcription,
/// and streaming partial and final recognition tokens.
@MainActor
final class SpeechRecognitionService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var isListening: Bool = false
    @Published private(set) var latestTranscript: String = ""
    @Published private(set) var recentTokens: [String] = []
    @Published var errorMessage: String?
    
    // MARK: - Internal Audio & Recognition State
    
    private var audioEngine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private var onTokensUpdated: (([String], Bool) -> Void)?
    
    // MARK: - Initialization
    
    init(locale: Locale = Locale(identifier: "en-US")) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
    }
    
    func setLocale(_ locale: Locale) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
    }
    
    // MARK: - Start / Stop Listening
    
    /// Starts microphone audio streaming and real-time speech transcription.
    /// - Parameter onTokens: Closure invoked whenever new partial or final speech tokens are recognized.
    func startListening(onTokens: @escaping ([String], Bool) -> Void) throws {
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
        
        // Automatic on-device recognition when available; do not hard-require to prevent error 1700
        request.requiresOnDeviceRecognition = false
        
        self.recognitionRequest = request
        
        let inputNode = engine.inputNode
        var recordingFormat = inputNode.outputFormat(forBus: 0)
        if recordingFormat.sampleRate == 0 || recordingFormat.channelCount == 0 {
            if let fallbackFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) {
                recordingFormat = fallbackFormat
            }
        }
        
        // Install tap to stream audio buffers directly into speech recognition
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        engine.prepare()
        try engine.start()
        
        self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
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
        AppLogger.speech.info("Speech recognition started successfully")
    }
    
    /// Stops audio capture and terminates the recognition task immediately.
    func stopListening() {
        guard isListening else { return }
        
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
}
