import SwiftUI

// MARK: - Word Highlight View

/// High-performance word token rendering with Spotify-lyrics-style visual state transitions:
/// - Completed: dimmed gray (#5A5A64)
/// - Current: vibrant orange accent (#FF6B00) with subtle pill background
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
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    state == .current
                        ? AppColors.accent.opacity(0.24)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusSm))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.12), value: state)
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
