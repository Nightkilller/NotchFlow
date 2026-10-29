import SwiftUI

// MARK: - NotchFlow Animation Configuration

enum AnimationConfig {
    // MARK: Standard transitions
    /// Fast micro-interaction (button press, hover state).
    static let fast = Animation.easeInOut(duration: 0.15)

    /// Standard UI transition (panel expand, state change).
    static let standard = Animation.easeInOut(duration: 0.25)

    /// Smooth, noticeable transition (window expand/collapse).
    static let smooth = Animation.easeInOut(duration: 0.35)

    /// Slow, deliberate transition (onboarding, first-reveal).
    static let slow = Animation.easeInOut(duration: 0.5)

    // MARK: Spring animations
    /// Snappy spring for interactive elements.
    static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.8)

    /// Gentle spring for window transitions.
    static let gentle = Animation.spring(response: 0.45, dampingFraction: 0.85)

    // MARK: Teleprompter-specific
    /// Word highlight transition — must be fast enough to not lag behind speech
    /// but smooth enough to be readable.
    static let wordHighlight = Animation.easeOut(duration: 0.12)

    /// Scroll/viewport movement — smooth to avoid jarring jumps.
    static let viewportScroll = Animation.easeInOut(duration: 0.3)

    /// Notch window expand/collapse.
    static let notchTransition = Animation.spring(response: 0.4, dampingFraction: 0.82)
}
