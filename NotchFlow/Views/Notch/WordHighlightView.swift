import SwiftUI

// MARK: - Word Highlight View

/// Renders a single word token with Spotify-lyrics-style visual state transitions:
/// - Completed: dimmed gray (#5A5A64)
/// - Current: vibrant orange accent (#FF6B00) with subtle glow
/// - Upcoming: crisp white (#FFFFFF)
struct WordHighlightView: View {
    let word: ScriptWord
    let state: WordVisualState
    let fontSize: CGFloat
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(word.text)
                .font(AppTypography.teleprompterFont(size: fontSize))
                .fontWeight(state == .current ? .bold : .medium)
                .foregroundStyle(textColor)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(
                    Group {
                        if state == .current {
                            RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusSm)
                                .fill(AppColors.accent.opacity(0.20))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusSm)
                                        .stroke(AppColors.accent.opacity(0.4), lineWidth: 1)
                                )
                                .shadow(color: AppColors.accent.opacity(0.3), radius: 6)
                        } else {
                            Color.clear
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .animation(AnimationConfig.wordHighlight, value: state)
    }
    
    private var textColor: Color {
        switch state {
        case .completed:
            AppColors.completedWord
        case .current:
            AppColors.currentWord
        case .upcoming:
            AppColors.upcomingWord
        }
    }
}
