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
        TeleprompterView(
            viewModel: viewModel,
            onDismiss: onClose,
            onCollapse: {
                withAnimation(AnimationConfig.notchTransition) {
                    state = .collapsed
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLg))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLg)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
    }
}
