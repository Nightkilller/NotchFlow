import SwiftUI

// MARK: - NotchFlow Color Palette
// All colors defined from the design specification.
// Usage: AppColors.primaryBackground, AppColors.accent, etc.

enum AppColors {
    // MARK: Backgrounds
    static let primaryBackground = Color(hex: 0x0B0B0D)
    static let secondaryBackground = Color(hex: 0x151519)
    static let surfaceBackground = Color(hex: 0x1C1C22)
    static let elevatedBackground = Color(hex: 0x222228)

    // MARK: Text
    static let primaryText = Color.white
    static let secondaryText = Color(hex: 0x9B9BA3)
    static let dimmedText = Color(hex: 0x5A5A64)

    // MARK: Accent
    static let accent = Color(hex: 0xFF6B00)
    static let accentSecondary = Color(hex: 0xFFB800)

    /// Accent gradient from primary orange to warm gold.
    static let accentGradient = LinearGradient(
        colors: [accent, accentSecondary],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: Teleprompter Word States
    /// Previously spoken words — dimmed but not invisible.
    static let completedWord = Color(hex: 0x5A5A64)
    /// The word currently being spoken — strong accent highlight.
    static let currentWord = Color(hex: 0xFF6B00)
    /// Words not yet spoken — bright and clearly readable.
    static let upcomingWord = Color.white

    // MARK: Semantic
    static let error = Color(hex: 0xFF4444)
    static let success = Color(hex: 0x44BB66)
    static let warning = Color(hex: 0xFFAA22)

    // MARK: Borders & Dividers
    static let border = Color.white.opacity(0.08)
    static let divider = Color.white.opacity(0.06)
}

// MARK: - Color Hex Initializer

extension Color {
    /// Creates a Color from a hex integer (e.g., 0xFF6B00).
    init(hex: UInt32, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
