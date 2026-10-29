import AppKit
import SwiftUI
import Combine

// MARK: - Notch Window Presentation State

enum NotchWindowState: Sendable, Equatable {
    case collapsed
    case expanded
    case closed
}

// MARK: - Notch Window Controller

/// Controls the floating, notch-anchored NSPanel window.
/// Handles collapsed and expanded states, display geometry positioning,
/// and smooth frame transitions.
@MainActor
final class NotchWindowController: NSWindowController {
    
    static let shared = NotchWindowController()
    
    // MARK: - Properties
    
    @Published private(set) var windowState: NotchWindowState = .closed
    private var teleprompterViewModel: TeleprompterViewModel?
    private var geometryCancellable: AnyCancellable?
    
    // Geometry dimensions
    private let collapsedWidth: CGFloat = 340
    private let collapsedHeight: CGFloat = 52
    
    // MARK: - Initialization
    
    private init() {
        let panel = Self.createNotchPanel()
        super.init(window: panel)
        
        // Observe display changes to update window frame in real time
        self.geometryCancellable = DisplayGeometryService.shared.$currentNotchInfo
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.repositionWindow()
                }
            }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Panel Configuration
    
    private static func createNotchPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: 340, height: 52),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Window level: floating above standard windows
        panel.level = .floating
        
        // Visible on all Spaces and over full-screen apps
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        
        // Transparency and appearance
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        
        // NSWindow.sharingType decision (per spec Section 20):
        // .readOnly allows the window to be captured by standard OS screen capture / recording
        // without allowing modifications. NotchFlow makes no invisibility claims.
        panel.sharingType = .readOnly
        
        // Non-activating: clicks inside panel do not steal keyboard focus from the active app
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        
        return panel
    }
    
    // MARK: - Public Lifecycle
    
    /// Presents the teleprompter window anchored to the MacBook notch.
    func present(with script: Script, initialMode: NotchWindowState = .expanded) {
        let vm = TeleprompterViewModel(script: script)
        self.teleprompterViewModel = vm
        
        let containerView = NotchContainerView(
            viewModel: vm,
            state: Binding(
                get: { self.windowState },
                set: { self.transition(to: $0) }
            ),
            onClose: { [weak self] in
                self?.dismiss()
            }
        )
        
        window?.contentView = NSHostingView(rootView: containerView)
        
        let targetFrame = calculateFrame(for: initialMode)
        window?.setFrame(targetFrame, display: true)
        window?.makeKeyAndOrderFront(nil)
        
        self.windowState = initialMode
        AppLogger.window.info("Notch teleprompter presented in \(String(describing: initialMode)) mode")
    }
    
    /// Transitions between collapsed and expanded states with smooth animation.
    func transition(to newState: NotchWindowState) {
        guard newState != windowState, let window = self.window else { return }
        
        if newState == .closed {
            dismiss()
            return
        }
        
        let targetFrame = calculateFrame(for: newState)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.32
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(targetFrame, display: true)
        }
        
        self.windowState = newState
    }
    
    /// Dismisses and hides the notch window, pausing playback.
    func dismiss() {
        teleprompterViewModel?.pause()
        window?.orderOut(nil)
        windowState = .closed
        teleprompterViewModel = nil
        AppLogger.window.info("Notch teleprompter dismissed")
    }
    
    // MARK: - Positioning Calculations
    
    private func calculateFrame(for state: NotchWindowState) -> CGRect {
        let notchInfo = DisplayGeometryService.shared.currentNotchInfo
        
        let width: CGFloat
        let height: CGFloat
        
        switch state {
        case .collapsed:
            width = collapsedWidth
            height = collapsedHeight
        case .expanded:
            if let vm = teleprompterViewModel {
                width = vm.settings.readingAreaWidth
                height = vm.settings.readingAreaHeight
            } else {
                width = AppSpacing.teleprompterDefaultWidth
                height = AppSpacing.teleprompterDefaultHeight
            }
        case .closed:
            return .zero
        }
        
        // Anchor directly to the notch area
        return notchInfo.calculateWindowFrame(width: width, height: height, attachDirectlyToTop: false)
    }
    
    private func repositionWindow() {
        guard windowState != .closed, let window = self.window else { return }
        let targetFrame = calculateFrame(for: windowState)
        window.setFrame(targetFrame, display: true)
    }
}
