import SwiftUI

// MARK: - NotchFlow Typography
// System font configurations for different contexts.
// macOS uses SF Pro by default; we stick with the system font for native feel.

enum AppTypography {
    // MARK: Editor
    static let editorTitle = Font.system(size: 24, weight: .semibold, design: .default)
    static let editorSubtitle = Font.system(size: 16, weight: .medium, design: .default)
    static let editorBody = Font.system(size: 14, weight: .regular, design: .default)
    static let editorCaption = Font.system(size: 12, weight: .regular, design: .default)

    // MARK: Teleprompter
    /// The base teleprompter font size. Users can adjust this via settings.
    static let teleprompterDefaultSize: CGFloat = 28
    static let teleprompterMinSize: CGFloat = 16
    static let teleprompterMaxSize: CGFloat = 56

    /// Returns a teleprompter font at the given size.
    static func teleprompterFont(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    // MARK: UI Controls
    static let buttonLabel = Font.system(size: 13, weight: .medium, design: .default)
    static let smallLabel = Font.system(size: 11, weight: .regular, design: .default)
    static let settingsLabel = Font.system(size: 13, weight: .regular, design: .default)
    static let settingsHeading = Font.system(size: 15, weight: .semibold, design: .default)

    // MARK: Timer
    static let timerDisplay = Font.system(size: 16, weight: .medium, design: .monospaced)
    static let timerLabel = Font.system(size: 11, weight: .regular, design: .default)
}
