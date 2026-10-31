import SwiftUI

// MARK: - Word Highlight View

/// High-performance word token rendering with Spotify-lyrics-style visual state transitions:
/// - Completed: dimmed (gray in dark theme, soft charcoal in light theme)
/// - Current: vibrant orange accent (#FF6B00) with subtle pill background
/// - Upcoming: high contrast (crisp white in dark theme, rich black in light theme)
struct WordHighlightView: View {
    let word: ScriptWord
    let state: WordVisualState
    let fontSize: CGFloat
    var theme: PrompterTheme = .dark
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(word.text)
                .font(AppTypography.teleprompterFont(size: fontSize, weight: .bold))
                .fontWeight(state == .current ? .bold : .semibold)
                .foregroundStyle(textColor)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    state == .current
                        ? AppColors.accent.opacity(theme == .light ? 0.18 : 0.26)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusSm))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.12), value: state)
    }
    
    private var textColor: Color {
        let isLight = theme == .light
        switch state {
        case .completed:
            return isLight ? Color.black.opacity(0.32) : Color.white.opacity(0.40)
        case .current:
            return AppColors.currentWord
        case .upcoming:
            return isLight ? Color.black : Color.white
        }
    }
}
