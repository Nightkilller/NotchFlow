import SwiftUI

// MARK: - NotchFlow Spacing & Layout Constants

enum AppSpacing {
    // MARK: Base spacing scale (4-point grid)
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48

    // MARK: Corner radii
    static let cornerRadiusSm: CGFloat = 6
    static let cornerRadiusMd: CGFloat = 10
    static let cornerRadiusLg: CGFloat = 16
    static let cornerRadiusXl: CGFloat = 24

    // MARK: Notch & Teleprompter
    /// Default width for the expanded teleprompter reading area.
    static let teleprompterDefaultWidth: CGFloat = 600
    static let teleprompterMinWidth: CGFloat = 400
    static let teleprompterMaxWidth: CGFloat = 900

    /// Default height for the expanded reading area below the notch.
    static let teleprompterDefaultHeight: CGFloat = 260
    static let teleprompterMinHeight: CGFloat = 120
    static let teleprompterMaxHeight: CGFloat = 500

    /// Padding inside the teleprompter reading area.
    static let teleprompterPaddingH: CGFloat = 24
    static let teleprompterPaddingV: CGFloat = 16

    // MARK: Editor
    static let editorSidebarWidth: CGFloat = 240
    static let editorMinWidth: CGFloat = 700
    static let editorMinHeight: CGFloat = 500
}
