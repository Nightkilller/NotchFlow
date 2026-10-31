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
                TeleprompterView(
                    viewModel: viewModel,
                    onDismiss: onClose,
                    onCollapse: {
                        withAnimation(AnimationConfig.notchTransition) {
                            state = .collapsed
                        }
                    }
                )
                .transition(.scale(scale: 0.96).combined(with: .opacity))
                
            case .closed:
                EmptyView()
            }
        }
        .animation(AnimationConfig.notchTransition, value: state)
    }
}
