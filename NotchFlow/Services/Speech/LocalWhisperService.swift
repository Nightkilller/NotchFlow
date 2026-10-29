import Foundation
import AVFoundation
import Combine

// MARK: - Local Whisper Service (Apple Silicon M4 Metal Accelerated)

/// Orchestrates on-device speech recognition using `whisper.cpp` with Metal GPU acceleration.
/// Processes live microphone audio strictly on-device with zero network transmissions or paid APIs.
@MainActor
final class LocalWhisperService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var isListening: Bool = false
    @Published private(set) var isTranscribing: Bool = false
    @Published private(set) var latestTranscript: String = ""
    @Published private(set) var recentTokens: [String] = []
    @Published private(set) var audioLevel: Float = 0.0
    @Published private(set) var isSpeaking: Bool = false
    @Published private(set) var lastInferenceLatencyMs: Double = 0.0
    @Published var errorMessage: String?
    
    // MARK: - Internal Audio State
    
    private var audioEngine: AVAudioEngine?
    private var onTokensUpdated: (([String], String, Bool, Double) -> Void)?
    
    private var lastSpeechTime: DispatchTime = .now()
    private var speechDecayTimer: AnyCancellable?
    private var transcriptionTimer: AnyCancellable?
    
    // Audio buffer for 16kHz mono accumulation
    private let sampleCollector = AudioSampleCollector()
    private var activeInferenceTask: Task<Void, Never>?
    
    // Binary & Model Paths
    private(set) var whisperCliPath: String?
    private(set) var modelPath: String?
    
    // MARK: - Initialization
    
    init() {
        locateWhisperBinaries()
    }
    
    /// Detects availability of local whisper.cpp executable and GGML model files.
    func locateWhisperBinaries() {
        let fileManager = FileManager.default
        
        // 1. Locate whisper-cli binary
        let potentialBinaryPaths = [
            Bundle.main.resourcePath.map { "\($0)/whisper-cli" },
            "/opt/homebrew/bin/whisper-cli",
            "/usr/local/bin/whisper-cli",
            "/Users/adityagupta/Desktop/Notchyy/bin/whisper-cli",
            fileManager.currentDirectoryPath + "/bin/whisper-cli"
        ].compactMap { $0 }
        
        self.whisperCliPath = potentialBinaryPaths.first { fileManager.isExecutableFile(atPath: $0) }
        
        // 2. Locate GGML base.en model
        let potentialModelPaths = [
            Bundle.main.path(forResource: "ggml-base.en", ofType: "bin"),
            Bundle.main.resourcePath.map { "\($0)/ggml-base.en.bin" },
            NSHomeDirectory() + "/Library/Application Support/NotchFlow/Models/ggml-base.en.bin",
            "/Users/adityagupta/Desktop/Notchyy/Models/ggml-base.en.bin",
            fileManager.currentDirectoryPath + "/Models/ggml-base.en.bin",
            "/opt/homebrew/share/whisper-cpp/models/ggml-base.en.bin"
        ].compactMap { $0 }
        
        self.modelPath = potentialModelPaths.first { fileManager.fileExists(atPath: $0) }
    }
    
    var isModelAvailable: Bool {
        if whisperCliPath == nil || modelPath == nil {
            locateWhisperBinaries()
        }
        return whisperCliPath != nil && modelPath != nil
    }
    
    // MARK: - Start / Stop Listening
    
    /// Starts capturing live microphone audio, segmenting speech windows, and running local Metal Whisper inference.
    func startListening(
        onTokens: @escaping ([String], String, Bool, Double) -> Void
    ) throws {
        guard !isListening else { return }
        locateWhisperBinaries()
        
        guard let cliPath = whisperCliPath, let mPath = modelPath else {
            throw AppError.speechRecognitionUnavailable
        }
        
        self.onTokensUpdated = onTokens
        sampleCollector.reset()
        
        let engine = AVAudioEngine()
        self.audioEngine = engine
        
        let inputNode = engine.inputNode
        var recordingFormat = inputNode.outputFormat(forBus: 0)
        if recordingFormat.sampleRate == 0 || recordingFormat.channelCount == 0 {
            if let fallbackFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) {
                recordingFormat = fallbackFormat
            }
        }
        
        // Timer for RMS audio decay and silence detection
        speechDecayTimer?.cancel()
        speechDecayTimer = Timer.publish(every: 0.08, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.isSpeaking {
                    let elapsed = DispatchTime.now().uptimeNanoseconds - self.lastSpeechTime.uptimeNanoseconds
                    if elapsed > 400_000_000 {
                        self.isSpeaking = false
                    }
                }
                if self.audioLevel > 0.02 {
                    self.audioLevel *= 0.82
                } else {
                    self.audioLevel = 0
                }
            }
            
        // Periodic chunk inference scheduler (runs every 650ms if speech was detected)
        transcriptionTimer?.cancel()
        transcriptionTimer = Timer.publish(every: 0.65, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isListening else { return }
                self.triggerPeriodicInference(cliPath: cliPath, modelPath: mPath)
            }
            
        let collector = self.sampleCollector
        
        // Tap input node on CoreAudio background thread
        Self.installAudioTap(on: inputNode, format: recordingFormat, collector: collector) { [weak self] level, isVoice in
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
        
        self.isListening = true
        AppLogger.speech.info("Local Whisper service started with Apple Silicon Metal acceleration")
    }
    
    /// Stops audio capture and terminates any in-flight inference tasks.
    func stopListening() {
        guard isListening else { return }
        
        speechDecayTimer?.cancel()
        speechDecayTimer = nil
        transcriptionTimer?.cancel()
        transcriptionTimer = nil
        
        activeInferenceTask?.cancel()
        activeInferenceTask = nil
        
        if let engine = audioEngine {
            if engine.inputNode.numberOfInputs > 0 {
                engine.inputNode.removeTap(onBus: 0)
            }
            if engine.isRunning {
                engine.stop()
            }
        }
        
        audioEngine = nil
        sampleCollector.reset()
        onTokensUpdated = nil
        isListening = false
        isSpeaking = false
        audioLevel = 0.0
        
        AppLogger.speech.info("Local Whisper service stopped and resources released")
    }
    
    // MARK: - Script Context Prompt Biasing
    
    /// Upcoming script text used to prime Whisper's decoder language model.
    var scriptPrompt: String = ""
    
    // MARK: - Periodic Inference Trigger
    
    private func triggerPeriodicInference(cliPath: String, modelPath: String) {
        guard !isTranscribing else { return }
        
        // Extract recent 1.5 - 2.5s of 16kHz audio samples
        guard let wavData = sampleCollector.exportRecentWav(maxDurationSeconds: 2.2, minDurationSeconds: 0.6) else {
            return
        }
        
        self.isTranscribing = true
        let tempWavURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("notchflow_chunk_\(UUID().uuidString.prefix(8)).wav")
        let promptText = self.scriptPrompt
        
        activeInferenceTask = Task.detached(priority: .userInitiated) { [weak self] in
            let startTime = DispatchTime.now()
            
            do {
                try wavData.write(to: tempWavURL)
                defer { try? FileManager.default.removeItem(at: tempWavURL) }
                
                let process = Process()
                process.executableURL = URL(fileURLWithPath: cliPath)
                var args = [
                    "-m", modelPath,
                    "-f", tempWavURL.path,
                    "--no-prints",
                    "-nt",
                    "-l", "en",
                    "-t", "4"
                ]
                if !promptText.isEmpty {
                    args.append(contentsOf: ["--prompt", promptText])
                }
                process.arguments = args
                
                let stdoutPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = Pipe() // Suppress stderr noise
                
                try process.run()
                let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                
                let endTime = DispatchTime.now()
                let latencyMs = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000.0
                
                if let rawText = String(data: data, encoding: .utf8) {
                    let cleaned = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    await MainActor.run { [weak self] in
                        guard let self = self, self.isListening else { return }
                        self.isTranscribing = false
                        self.lastInferenceLatencyMs = latencyMs
                        
                        if !cleaned.isEmpty {
                            self.latestTranscript = cleaned
                            let tokens = TextNormalizationService.tokenize(cleaned)
                            self.recentTokens = tokens
                            self.onTokensUpdated?(tokens, cleaned, false, latencyMs)
                        }
                    }
                } else {
                    await MainActor.run { [weak self] in
                        self?.isTranscribing = false
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.isTranscribing = false
                    AppLogger.speech.error("Local Whisper execution error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - CoreAudio Tap Implementation
    
    nonisolated private static func installAudioTap(
        on inputNode: AVAudioNode,
        format: AVAudioFormat,
        collector: AudioSampleCollector,
        onLevel: @escaping @Sendable (Float, Bool) -> Void
    ) {
        var sampleInterval = 0
        var noiseFloor: Float = 0.005
        
        let srcSampleRate = format.sampleRate
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0 else { return }
            
            // Append downsampled 16kHz mono samples into collector
            collector.appendSamples(channelData: channelData, count: frameLength, sourceRate: srcSampleRate)
            
            // Calculate RMS audio energy
            sampleInterval &+= 1
            if sampleInterval % 2 == 0 {
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
                
                let isVoice = (rms > noiseFloor * 1.6 && rms > 0.004) || normalized > 0.06
                if !isVoice {
                    noiseFloor = min(0.02, noiseFloor * 0.98 + rms * 0.02)
                }
                
                onLevel(normalized, isVoice)
            }
        }
    }
}

// MARK: - Audio Sample Collector (Thread-Safe 16kHz PCM Buffer)

/// Collects raw audio samples, downsamples to 16,000 Hz 16-bit mono PCM, and produces standard RIFF WAV files.
final class AudioSampleCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var samples: [Int16] = []
    private let targetSampleRate: Double = 16000.0
    private let maxBufferSamples: Int = 16000 * 5 // 5 seconds max rolling buffer
    
    func appendSamples(channelData: UnsafePointer<Float>, count: Int, sourceRate: Double) {
        lock.lock()
        defer { lock.unlock() }
        
        let step = max(1.0, sourceRate / targetSampleRate)
        var sourceIndex: Double = 0.0
        
        while Int(sourceIndex) < count {
            let sampleFloat = channelData[Int(sourceIndex)]
            let clamped = max(-1.0, min(1.0, sampleFloat))
            let int16Sample = Int16(clamped * 32767.0)
            samples.append(int16Sample)
            sourceIndex += step
        }
        
        // Retain only rolling window
        if samples.count > maxBufferSamples {
            samples.removeFirst(samples.count - maxBufferSamples)
        }
    }
    
    func exportRecentWav(maxDurationSeconds: Double, minDurationSeconds: Double) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        
        let minSamples = Int(minDurationSeconds * targetSampleRate)
        guard samples.count >= minSamples else { return nil }
        
        let maxSamples = Int(maxDurationSeconds * targetSampleRate)
        let slice = samples.suffix(maxSamples)
        let sampleData = slice.withUnsafeBufferPointer { Data(buffer: $0) }
        
        return createWavData(pcm16Data: sampleData, sampleRate: Int(targetSampleRate))
    }
    
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        samples.removeAll(keepingCapacity: true)
    }
    
    private func createWavData(pcm16Data: Data, sampleRate: Int) -> Data {
        var data = Data()
        let totalDataLen = Int32(pcm16Data.count)
        let totalAudioLen = totalDataLen + 36
        let channels: Int16 = 1
        let byteRate = Int32(sampleRate * 2)
        
        // RIFF header
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        data.append(totalAudioLen.littleEndianData)
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"
        
        // fmt chunk
        data.append(contentsOf: [0x66, 0x6d, 0x74, 0x20]) // "fmt "
        data.append(Int32(16).littleEndianData)           // SubChunk1Size (16 for PCM)
        data.append(Int16(1).littleEndianData)            // AudioFormat (1 = PCM)
        data.append(channels.littleEndianData)
        data.append(Int32(sampleRate).littleEndianData)
        data.append(byteRate.littleEndianData)
        data.append(Int16(2).littleEndianData)            // BlockAlign (1 * 16 / 8)
        data.append(Int16(16).littleEndianData)           // BitsPerSample
        
        // data chunk
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        data.append(totalDataLen.littleEndianData)
        data.append(pcm16Data)
        
        return data
    }
}

// MARK: - Little Endian Helper

private extension FixedWidthInteger {
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<Self>.size)
    }
}
