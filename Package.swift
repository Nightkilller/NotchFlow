// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchFlow",
    platforms: [
        // macOS 15.0 (Sequoia) is the minimum to ensure:
        // - NSScreen.safeAreaInsets, auxiliaryTopLeftArea, auxiliaryTopRightArea
        // - SFSpeechRecognizer.supportsOnDeviceRecognition
        // - SFSpeechAudioBufferRecognitionRequest.requiresOnDeviceRecognition
        // - Modern SwiftUI features (Observable macro, etc.)
        // The developer machine runs macOS 27.0, so this is well within range.
        .macOS(.v15)
    ],
    targets: [
        .executableTarget(
            name: "NotchFlow",
            path: "NotchFlow",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "NotchFlowTests",
            dependencies: ["NotchFlow"],
            path: "NotchFlowTests"
        )
    ]
)
