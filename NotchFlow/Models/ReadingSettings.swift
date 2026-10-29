import Foundation

// MARK: - Reading Settings

/// User-configurable settings for the teleprompter reading experience.
/// Persisted via UserDefaults (see SettingsStorageService).
struct ReadingSettings: Sendable, Equatable, Codable {
    /// Teleprompter font size in points.
    var fontSize: CGFloat = 28
    /// Line spacing multiplier (1.0 = tight, 2.0 = double).
    var lineSpacing: CGFloat = 1.6
    /// Width of the reading area in points.
    var readingAreaWidth: CGFloat = 600
    /// Height of the expanded reading area in points.
    var readingAreaHeight: CGFloat = 260
    /// Fallback auto-scroll speed in words per minute (used when speech is off).
    var autoScrollSpeed: Double = 150
    /// Number of visible lines in the teleprompter.
    var visibleLines: Int = 4
    /// Whether to show the reading guide line.
    var showReadingGuide: Bool = true
    /// Whether to mirror/flip text horizontally (for physical teleprompter setups).
    var mirrorText: Bool = false
    /// Pre-start countdown duration in seconds. 0 = no countdown.
    var countdownSeconds: Int = 3
    /// The reading mode.
    var readingMode: ReadingMode = .voicePaced
    /// The local speech recognition engine used for voice-paced synchronization.
    var speechEngine: SpeechEngineType = .whisper
    /// Whether to display the live development debug HUD panel.
    var showDebugHUD: Bool = false
}

// MARK: - Speech Engine Type

/// The local speech recognition engine used for real-time script synchronization.
enum SpeechEngineType: String, Sendable, Codable, CaseIterable, Identifiable {
    /// Local open-source whisper.cpp inference with Apple Silicon Metal acceleration.
    case whisper = "Local Whisper (M4 Metal)"
    /// Native Apple Dictation / Speech Recognition engine.
    case appleSpeech = "Apple Speech (On-Device)"
    /// Voice energy cadence pacing fallback.
    case audioCadence = "Voice Energy Cadence"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .whisper: "Free local whisper.cpp powered by Apple Silicon M4 GPU (100% offline & private)"
        case .appleSpeech: "Apple Neural Engine on-device speech dictation"
        case .audioCadence: "Advances text at selected speed whenever voice activity is detected"
        }
    }
}

// MARK: - Reading Mode

/// How the teleprompter advances through the script.
enum ReadingMode: String, Sendable, Codable, CaseIterable, Identifiable {
    /// Follows the user's voice via speech recognition.
    case voicePaced = "Voice-Paced"
    /// Scrolls at a fixed words-per-minute rate.
    case autoScroll = "Auto-Scroll"
    /// Only advances via manual controls (keyboard/click).
    case manual = "Manual"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .voicePaced: "Follows your voice using speech recognition"
        case .autoScroll: "Scrolls at a steady, configurable speed"
        case .manual: "You control the position with keyboard shortcuts"
        }
    }
}
