import SwiftUI

// MARK: - Collapsed Notch View

/// A compact, distraction-free indicator that hugs the MacBook notch.
/// Displays minimal session status, play/pause toggle, and an expand button.
struct CollapsedNotchView: View {
    @ObservedObject var viewModel: TeleprompterViewModel
    let onExpand: () -> Void
    let onClose: () -> Void
    
    private var notchTopOffset: CGFloat {
        let notchInfo = DisplayGeometryService.shared.currentNotchInfo
        return notchInfo.hasNotch ? notchInfo.topSafeAreaHeight : 0
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Live Status Indicator Dot
            Circle()
                .fill(viewModel.isPlaying ? AppColors.accent : AppColors.secondaryText)
                .frame(width: 8, height: 8)
                .shadow(color: viewModel.isPlaying ? AppColors.accent.opacity(0.6) : .clear, radius: 4)
            
            // Progress / Elapsed Time
            HStack(spacing: AppSpacing.xs) {
                Text(viewModel.elapsedTimeFormatted)
                    .font(AppTypography.timerDisplay)
                    .foregroundStyle(AppColors.primaryText)
                
                Text("·")
                    .foregroundStyle(AppColors.secondaryText)
                
                Text("\(viewModel.currentWordDisplayIndex)/\(viewModel.totalWordsCount)")
                    .font(AppTypography.editorCaption)
                    .foregroundStyle(AppColors.secondaryText)
            }
            
            // Mini Play / Pause Toggle
            Button {
                viewModel.togglePlayPause()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 22, height: 22)
                    .background(AppColors.surfaceBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(viewModel.isPlaying ? "Pause (Space)" : "Play (Space)")
            
            // Expand to Full Prompter
            Button {
                onExpand()
            } label: {
                Image(systemName: "arrow.down.forward.and.arrow.up.backward")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.primaryText)
                    .frame(width: 22, height: 22)
                    .background(AppColors.surfaceBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Expand Teleprompter")
            
            // Close Button
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppColors.secondaryText)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help("Close Teleprompter (Esc)")
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, notchTopOffset + 6)
        .padding(.bottom, 8)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 18,
                bottomTrailingRadius: 18,
                topTrailingRadius: 0
            )
            .fill(AppColors.secondaryBackground)
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 18,
                    bottomTrailingRadius: 18,
                    topTrailingRadius: 0
                )
                .stroke(AppColors.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 12, y: 6)
        )
    }
}
