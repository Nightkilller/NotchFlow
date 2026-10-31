import AppKit
import SwiftUI
import Combine

// MARK: - Notch Window Presentation State

enum NotchWindowState: Sendable, Equatable {
    case collapsed
    case expanded
    case closed
}

// MARK: - Notch Floating Panel

/// Custom NSPanel subclass that overrides window frame constraints.
/// Standard NSPanel clamps its frame below the macOS menu bar.
/// NotchFloatingPanel permits the window to anchor flush to the physical top of the display (y = screenFrame.maxY - height),
/// seamlessly attaching to the MacBook camera notch.
final class NotchFloatingPanel: NSPanel {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
    
    override var canBecomeKey: Bool {
        false
    }
}

// MARK: - Notch Window Controller

/// Controls the floating, notch-anchored NSPanel window.
/// Handles collapsed and expanded states, display geometry positioning,
/// and smooth frame transitions.
@MainActor
final class NotchWindowController: NSWindowController, ObservableObject {
    
    static let shared = NotchWindowController()
    
    // MARK: - Properties
    
    @Published private(set) var windowState: NotchWindowState = .closed
    @Published private(set) var isHoverExpanded: Bool = true
    @Published private(set) var isPinnedExpanded: Bool = false
    @Published private(set) var isResizing: Bool = false
    
    private var resizeStartWidth: CGFloat = 0
    private var resizeStartHeight: CGFloat = 0
    
    private var teleprompterViewModel: TeleprompterViewModel?
    private var geometryCancellable: AnyCancellable?
    private var unhoverTimer: AnyCancellable?
    private var launchCooldown: Bool = false
    
    // Geometry dimensions
    private let collapsedWidth: CGFloat = 340
    private let collapsedHeight: CGFloat = 52
    /// Compact height calibrated for teleprompter text hugging the notch when auto-shrunk
    private let compactTwoLineHeight: CGFloat = 68
    
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
    
    private static func createNotchPanel() -> NotchFloatingPanel {
        let panel = NotchFloatingPanel(
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
        
        // Enable tracking of mouse moved and hover events
        panel.acceptsMouseMovedEvents = true
        
        // NSWindow.sharingType decision (per spec Section 20):
        panel.sharingType = .readOnly
        
        // Non-activating: clicks inside panel do not steal keyboard focus from the active app
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        
        return panel
    }
    
    // MARK: - Public Lifecycle
    
    /// Presents the teleprompter window anchored to the MacBook notch.
    func present(
        with script: Script,
        settings: ReadingSettings = SettingsStorageService.load(),
        initialMode: NotchWindowState = .expanded,
        autoPlay: Bool = true
    ) {
        self.isHoverExpanded = true
        self.isPinnedExpanded = false
        self.isResizing = false
        self.unhoverTimer?.cancel()
        self.launchCooldown = false
        
        // Auto-shrink after 3 seconds if user is not hovering over the teleprompter
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self, !self.isPinnedExpanded, !self.isResizing else { return }
            let mouseLoc = NSEvent.mouseLocation
            if let win = self.window, !win.frame.contains(mouseLoc) {
                self.isHoverExpanded = false
                self.animateToCurrentFrame()
            }
        }
        
        let vm = TeleprompterViewModel(script: script, settings: settings)
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
        
        if autoPlay {
            vm.play()
        }
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
    
    /// Toggles or updates hover expansion state smoothly.
    func setHovered(_ hovered: Bool) {
        guard !isResizing else { return }
        unhoverTimer?.cancel()
        unhoverTimer = nil
        
        guard windowState == .expanded, !isPinnedExpanded else { return }
        if launchCooldown { return }
        
        if hovered {
            if !isHoverExpanded {
                isHoverExpanded = true
                animateToCurrentFrame()
            }
        } else {
            // Gentle 450ms debounce before auto-shrinking so accidental cursor exits don't abruptly jitter
            unhoverTimer = Just(())
                .delay(for: .milliseconds(450), scheduler: RunLoop.main)
                .sink { [weak self] in
                    guard let self = self, !self.isPinnedExpanded, !self.isResizing else { return }
                    self.isHoverExpanded = false
                    self.animateToCurrentFrame()
                }
        }
    }
    
    // MARK: - Edge Resizing
    
    func startResize() {
        guard let vm = teleprompterViewModel else { return }
        isResizing = true
        unhoverTimer?.cancel()
        unhoverTimer = nil
        resizeStartWidth = vm.settings.readingAreaWidth
        resizeStartHeight = vm.settings.readingAreaHeight
    }
    
    func updateResize(deltaWidth: CGFloat, deltaHeight: CGFloat) {
        guard let vm = teleprompterViewModel, let window = self.window else { return }
        
        let newWidth = max(380, min(950, resizeStartWidth + deltaWidth))
        let newHeight = max(180, min(650, resizeStartHeight + deltaHeight))
        
        vm.settings.readingAreaWidth = newWidth
        vm.settings.readingAreaHeight = newHeight
        
        let targetFrame = calculateFrame(for: .expanded)
        window.setFrame(targetFrame, display: true)
    }
    
    func endResize() {
        isResizing = false
        if let vm = teleprompterViewModel {
            SettingsStorageService.save(vm.settings)
        }
        // Check if mouse is currently hovered
        if let window = self.window {
            let mouseLoc = NSEvent.mouseLocation
            setHovered(window.frame.contains(mouseLoc))
        }
    }
    
    /// Pins the teleprompter in expanded mode so it does not collapse on hover exit.
    func togglePinExpanded() {
        isPinnedExpanded.toggle()
        if !isPinnedExpanded {
            isHoverExpanded = false
        }
        animateToCurrentFrame()
    }
    
    private func animateToCurrentFrame() {
        guard let window = self.window else { return }
        let targetFrame = calculateFrame(for: windowState)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(targetFrame, display: true)
        }
    }
    
    /// Dismisses and hides the notch window, pausing playback.
    func dismiss() {
        unhoverTimer?.cancel()
        unhoverTimer = nil
        isHoverExpanded = false
        isPinnedExpanded = false
        teleprompterViewModel?.pause()
        window?.orderOut(nil)
        windowState = .closed
        teleprompterViewModel = nil
        AppLogger.window.info("Notch teleprompter dismissed")
    }
    
    // MARK: - Positioning Calculations
    
    private func calculateFrame(for state: NotchWindowState) -> CGRect {
        let notchInfo = DisplayGeometryService.shared.currentNotchInfo
        let notchTopInset = notchInfo.hasNotch ? notchInfo.topSafeAreaHeight : 8
        
        let width: CGFloat
        let height: CGFloat
        
        switch state {
        case .collapsed:
            width = notchInfo.hasNotch ? max(collapsedWidth, notchInfo.notchFrame.width + 120) : collapsedWidth
            height = collapsedHeight + notchTopInset
        case .expanded:
            if let vm = teleprompterViewModel {
                width = vm.settings.readingAreaWidth
                if isHoverExpanded || isPinnedExpanded || isResizing {
                    height = vm.settings.readingAreaHeight + notchTopInset
                } else {
                    // Auto-shrink to compact mode hugging the notch
                    height = compactTwoLineHeight + notchTopInset
                }
            } else {
                width = AppSpacing.teleprompterDefaultWidth
                let effectiveH = (isHoverExpanded || isPinnedExpanded || isResizing) ? AppSpacing.teleprompterDefaultHeight : compactTwoLineHeight
                height = effectiveH + notchTopInset
            }
        case .closed:
            return .zero
        }
        
        // Anchor directly to top edge of screen so window extends naturally from the physical notch
        return notchInfo.calculateWindowFrame(width: width, height: height, attachDirectlyToTop: true)
    }
    
    private func repositionWindow() {
        guard windowState != .closed, let window = self.window else { return }
        let targetFrame = calculateFrame(for: windowState)
        window.setFrame(targetFrame, display: true)
    }
}
