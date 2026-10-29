import Foundation
import Speech
import AVFoundation

// MARK: - Speech Permission Status

enum SpeechPermissionStatus: Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

// MARK: - Speech Permission Service

/// Manages authorization checks and user requests for both Microphone access
/// and Apple Speech Recognition.
@MainActor
final class SpeechPermissionService: ObservableObject {
    
    @Published private(set) var microphoneStatus: SpeechPermissionStatus = .notDetermined
    @Published private(set) var speechRecognitionStatus: SpeechPermissionStatus = .notDetermined
    
    var isFullyAuthorized: Bool {
        microphoneStatus == .authorized && speechRecognitionStatus == .authorized
    }
    
    init() {
        checkCurrentStatus()
    }
    
    func checkCurrentStatus() {
        // 1. Microphone status
        if #available(macOS 14.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                microphoneStatus = .authorized
            case .denied:
                microphoneStatus = .denied
            case .undetermined:
                microphoneStatus = .notDetermined
            @unknown default:
                microphoneStatus = .denied
            }
        } else {
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                microphoneStatus = .authorized
            case .denied:
                microphoneStatus = .denied
            case .notDetermined:
                microphoneStatus = .notDetermined
            case .restricted:
                microphoneStatus = .restricted
            @unknown default:
                microphoneStatus = .denied
            }
        }
        
        // 2. Speech recognition status
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            speechRecognitionStatus = .authorized
        case .denied:
            speechRecognitionStatus = .denied
        case .restricted:
            speechRecognitionStatus = .restricted
        case .notDetermined:
            speechRecognitionStatus = .notDetermined
        @unknown default:
            speechRecognitionStatus = .denied
        }
    }
    
    /// Requests both microphone and speech recognition permissions.
    func requestPermissions() async -> Bool {
        // Request Microphone
        let micGranted: Bool
        if #available(macOS 14.0, *) {
            micGranted = await AVAudioApplication.requestRecordPermission()
        } else {
            micGranted = await AVCaptureDevice.requestAccess(for: .audio)
        }
        
        // Request Speech Recognition
        let speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        
        checkCurrentStatus()
        return micGranted && speechGranted
    }
}
