import SwiftUI

// MARK: - Notch Container View

/// Root SwiftUI view hosted inside the notch window panel.
/// Dynamically toggles between collapsed pill and expanded teleprompter view.
struct NotchContainerView: View {
    @ObservedObject var viewModel: TeleprompterViewModel
    @Binding var state: NotchWindowState
    let onClose: () -> Void
    
    var body: some View {
        ZStack {
            switch state {
            case .collapsed:
                CollapsedNotchView(
                    viewModel: viewModel,
                    onExpand: {
                        withAnimation(AnimationConfig.notchTransition) {
                            state = .expanded
                        }
                    },
                    onClose: onClose
                )
                .transition(.scale(scale: 0.9).combined(with: .opacity))
                
            case .expanded:
                expandedPrompterView
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                
            case .closed:
                EmptyView()
            }
        }
        .animation(AnimationConfig.notchTransition, value: state)
        .background(
            KeyboardNavigationHelper(
                onSpace: { viewModel.togglePlayPause() },
                onLeft: { viewModel.stepBackward() },
                onRight: { viewModel.stepForward() },
                onUp: { viewModel.stepSentenceBackward() },
                onDown: { viewModel.stepSentenceForward() },
                onEscape: {
                    if state == .expanded {
                        state = .collapsed
                    } else {
                        onClose()
                    }
                }
            )
        )
    }
    
    // MARK: - Expanded Prompter View
    
    private var expandedPrompterView: some View {
        VStack(spacing: 0) {
            // Header Bar with Notch-specific controls
            HStack {
                // Notch Anchor Icon
                Image(systemName: "camera.metering.spot")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                
                Text(viewModel.script.title)
                    .font(AppTypography.settingsHeading)
                    .foregroundStyle(AppColors.primaryText)
                    .lineLimit(1)
                
                Spacer()
                
                // Elapsed time
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "timer")
                        .font(.system(size: 11))
                    Text(viewModel.elapsedTimeFormatted)
                        .font(AppTypography.timerDisplay)
                }
                .foregroundStyle(AppColors.secondaryText)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 2)
                .background(AppColors.surfaceBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusSm))
                
                // Collapse to Notch Pill
                Button {
                    state = .collapsed
                } label: {
                    Image(systemName: "arrow.up.backward.and.arrow.down.forward")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.secondaryText)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("Collapse to Notch Pill")
                
                // Close
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppColors.secondaryText)
                }
                .buttonStyle(.plain)
                .help("Close Teleprompter (Esc)")
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .background(AppColors.secondaryBackground)
            
            Divider()
                .background(AppColors.divider)
            
            // Reading Surface (Reusable Teleprompter View contents)
            TeleprompterView(
                viewModel: viewModel,
                onDismiss: onClose
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLg))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLg)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
    }
}
