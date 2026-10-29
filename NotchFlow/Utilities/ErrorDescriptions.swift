import Foundation

// MARK: - NotchFlow Error Descriptions

/// Human-readable error descriptions for common failure scenarios.
/// Used by views to display actionable error messages.
enum AppError: LocalizedError, Sendable {
    // MARK: Import
    case unsupportedFileType(String)
    case fileReadFailed(String)
    case pdfExtractionFailed
    case emptyDocument
    case importFailed(String)

    // MARK: Speech
    case microphonePermissionDenied
    case speechRecognitionPermissionDenied
    case speechRecognitionUnavailable
    case speechRecognitionFailed(String)

    // MARK: Storage
    case saveFailed(String)
    case loadFailed(String)
    case scriptNotFound(UUID)
    case corruptedData

    // MARK: General
    case noScript
    case invalidState(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType(let ext):
            "The file type \"\(ext)\" is not supported. NotchFlow can import TXT, PDF, and Markdown files."
        case .fileReadFailed(let name):
            "Could not read the file \"\(name)\". Check that the file exists and is accessible."
        case .pdfExtractionFailed:
            "Could not extract text from this PDF. The file may be image-only or corrupted."
        case .emptyDocument:
            "The document appears to be empty. Please check the file and try again."
        case .importFailed(let detail):
            "Import failed: \(detail)"
        case .microphonePermissionDenied:
            "Microphone access is required for voice-paced reading. Open System Settings → Privacy & Security → Microphone to grant access."
        case .speechRecognitionPermissionDenied:
            "Speech recognition permission is required for voice tracking. Open System Settings → Privacy & Security → Speech Recognition to grant access."
        case .speechRecognitionUnavailable:
            "Speech recognition is not available on this device or for the selected language."
        case .speechRecognitionFailed(let detail):
            "Speech recognition encountered an error: \(detail)"
        case .saveFailed(let detail):
            "Could not save the script: \(detail)"
        case .loadFailed(let detail):
            "Could not load the script: \(detail)"
        case .scriptNotFound:
            "The requested script could not be found. It may have been deleted."
        case .corruptedData:
            "The saved data appears to be corrupted. The script may need to be re-imported."
        case .noScript:
            "No script is loaded. Create or import a script first."
        case .invalidState(let detail):
            "An unexpected state occurred: \(detail)"
        }
    }
}
