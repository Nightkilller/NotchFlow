import SwiftUI

// MARK: - Teleprompter Reading View

/// Clean, professional notch teleprompter with:
/// - Smooth continuous rounded corners (no rectangular black ear flaps or edges).
/// - Dynamic Light/Dark theme switching (Pure Black ↔ Clean White).
/// - Auto-shrink to compact 2-line mode when idle; smooth expansion on hover.
/// - Full edge and corner live-resizing.
struct TeleprompterView: View {
    @ObservedObject var viewModel: TeleprompterViewModel
    @ObservedObject private var windowController = NotchWindowController.shared
    let onDismiss: () -> Void
    var onCollapse: (() -> Void)? = nil
    
    private var isExpanded: Bool {
        windowController.isHoverExpanded || windowController.isPinnedExpanded || windowController.isResizing
    }
    
    private var isLight: Bool {
        viewModel.settings.theme == .light
    }
    
    private var notchTopOffset: CGFloat {
        let notchInfo = DisplayGeometryService.shared.currentNotchInfo
        return notchInfo.hasNotch ? max(notchInfo.topSafeAreaHeight, 6) : 6
    }
    
    private var lines: [ScriptLine] {
        let maxWidth = viewModel.settings.readingAreaWidth - 64
        return ScriptLineWrapService.computeLines(
            words: viewModel.script.allWords,
            maxWidth: maxWidth,
            fontSize: isExpanded ? viewModel.settings.fontSize : 20
        )
    }
    
    private var activeLineIndex: Int {
        ScriptLineWrapService.activeLineIndex(
            for: viewModel.position.currentWordIndex,
            in: lines
        )
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Main content layout: compact when auto-shrunk, full when expanded
            if isExpanded {
                expandedPrompterContent
                    .transition(.opacity)
            } else {
                compactReadingView
                    .transition(.opacity)
            }
            
            // Countdown badge if countdown is running
            if let remaining = viewModel.countdownRemaining {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 8, height: 8)
                    Text("Starting in \(remaining)...")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isLight ? Color.black : Color.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isLight ? Color.white.opacity(0.95) : Color.black.opacity(0.85))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppColors.accent.opacity(0.4), lineWidth: 1))
                .padding(.top, notchTopOffset + 8)
                .transition(.scale.combined(with: .opacity))
            }
            
            // Optional Debug HUD overlay (toggled via 'D' key)
            if viewModel.settings.showDebugHUD {
                VStack {
                    Spacer()
                    TeleprompterDebugView(viewModel: viewModel)
                        .padding(.bottom, 50)
                }
                .transition(.opacity)
            }
            
            // Edge resize handles (active when expanded)
            if isExpanded {
                edgeResizeHandles
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Theme background: Pure black in Dark mode, Clean white in Light mode
        .background(isLight ? Color.white : Color.black)
        // Smooth rounded rectangle: zero sharp rectangular corners or ear flaps
        .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 24 : 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: isExpanded ? 24 : 18, style: .continuous)
                .stroke(isLight ? Color.black.opacity(0.09) : Color.white.opacity(0.11), lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(isLight ? 0.22 : 0.65),
            radius: isExpanded ? 24 : 14,
            y: isExpanded ? 10 : 5
        )
        // Hover monitoring: expands on hover, auto-shrinks when cursor leaves
        .onHover { isHovered in
            windowController.setHovered(isHovered)
        }
        // Global keyboard shortcuts
        .background(
            KeyboardNavigationHelper(
                onSpace: { viewModel.togglePlayPause() },
                onLeft: { viewModel.stepBackward() },
                onRight: { viewModel.stepForward() },
                onUp: { viewModel.stepSentenceBackward() },
                onDown: { viewModel.stepSentenceForward() },
                onEscape: { onDismiss() },
                onReset: { viewModel.reset() },
                onSpeedUp: { viewModel.updateSpeed(delta: 10) },
                onSpeedDown: { viewModel.updateSpeed(delta: -10) },
                onFontGrow: { viewModel.updateFontSize(delta: 2) },
                onFontShrink: { viewModel.updateFontSize(delta: -2) },
                onToggleDebug: { viewModel.settings.showDebugHUD.toggle() }
            )
        )
        .animation(.spring(response: 0.32, dampingFraction: 0.84), value: isExpanded)
    }
    
    // MARK: - Compact Reading View (Auto-Shrunk)
    
    private var compactReadingView: some View {
        let linesList = self.lines
        let currentIdx = self.activeLineIndex
        let currentLine = linesList.indices.contains(currentIdx) ? linesList[currentIdx] : nil
        let nextLine = linesList.indices.contains(currentIdx + 1) ? linesList[currentIdx + 1] : nil
        
        return VStack(alignment: .leading, spacing: 3) {
            // Line 1: Active Reading Line
            if let current = currentLine {
                HStack(spacing: 5) {
                    ForEach(current.words) { word in
                        WordHighlightView(
                            word: word,
                            state: viewModel.visualState(for: word),
                            fontSize: 20,
                            theme: viewModel.settings.theme,
                            onTap: { viewModel.jumpToWord(at: word.globalIndex) }
                        )
                        .id(word.id)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
                .id("compact-line-\(current.id)")
            } else {
                Text(viewModel.script.title.isEmpty ? "NotchFlow Teleprompter" : viewModel.script.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isLight ? Color.black.opacity(0.8) : Color.white.opacity(0.8))
            }
            
            // Line 2: Upcoming Preview Line
            if let next = nextLine {
                HStack(spacing: 5) {
                    ForEach(next.words) { word in
                        WordHighlightView(
                            word: word,
                            state: viewModel.visualState(for: word),
                            fontSize: 15,
                            theme: viewModel.settings.theme,
                            onTap: { viewModel.jumpToWord(at: word.globalIndex) }
                        )
                        .id(word.id)
                    }
                }
                .opacity(isLight ? 0.40 : 0.45)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
                .id("compact-line-\(next.id)")
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, notchTopOffset + 2)
        .padding(.bottom, 6)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: currentIdx)
    }
    
    // MARK: - Expanded Prompter Content
    
    private var expandedPrompterContent: some View {
        VStack(spacing: 0) {
            // Top notch bar with top-right timer
            topBar
            
            // Scrolling teleprompter script content
            scriptContentArea
            
            // Bottom controls: progress dots (left), indicator (center), circular buttons (right)
            bottomControlsBar
        }
    }
    
    // MARK: - Top Bar (Timer)
    
    private var topBar: some View {
        HStack {
            Spacer()
            
            // Clean monospaced timer in the top-right corner
            Text(viewModel.elapsedTimeFormatted)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(isLight ? Color.black.opacity(0.55) : Color.white.opacity(0.60))
                .monospacedDigit()
        }
        .padding(.top, max(notchTopOffset, 6) + 4)
        .padding(.trailing, 28)
        .padding(.bottom, 2)
    }
    
    // MARK: - Script Content Area
    
    private var scriptContentArea: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 8) {
                    // Top padding so active line can scroll into the center
                    Spacer()
                        .frame(height: 20)
                    
                    if lines.isEmpty {
                        Text("No script text loaded. Open NotchFlow to write or import a script.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(isLight ? Color.black.opacity(0.45) : Color.white.opacity(0.50))
                            .padding(.vertical, 30)
                    } else {
                        ForEach(lines) { line in
                            HStack(spacing: 5) {
                                ForEach(line.words) { word in
                                    WordHighlightView(
                                        word: word,
                                        state: viewModel.visualState(for: word),
                                        fontSize: viewModel.settings.fontSize,
                                        theme: viewModel.settings.theme,
                                        onTap: {
                                            viewModel.jumpToWord(at: word.globalIndex)
                                        }
                                    )
                                    .id(word.id)
                                }
                            }
                            .id("line-\(line.id)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Bottom padding
                    Spacer()
                        .frame(height: 80)
                }
                .padding(.horizontal, 32)
                .scaleEffect(x: viewModel.settings.mirrorText ? -1 : 1, y: 1)
            }
            // Vertical edge fade mask for smooth readability
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.12),
                        .init(color: .black, location: 0.88),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            // Smoothly auto-scroll line-by-line as active line progresses
            .onChange(of: activeLineIndex) { _, lineIdx in
                withAnimation(AnimationConfig.viewportScroll) {
                    proxy.scrollTo("line-\(lineIdx)", anchor: .center)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Bottom Controls Bar
    
    private var bottomControlsBar: some View {
        HStack(alignment: .center) {
            // Progress dots (Left)
            progressDots
            
            Spacer()
            
            // Home indicator / drag pill (Center)
            Capsule()
                .fill(isLight ? Color.black.opacity(0.18) : Color.white.opacity(0.18))
                .frame(width: 32, height: 4)
            
            Spacer()
            
            // 4 Circular control buttons (Right)
            HStack(spacing: 10) {
                // Restart Button
                circularButton(icon: "backward.end.fill") {
                    viewModel.reset()
                }
                .help("Restart (R)")
                
                // Theme Toggle Button (Light / Dark)
                circularButton(
                    icon: isLight ? "moon.fill" : "sun.max.fill",
                    tint: isLight ? Color.black.opacity(0.80) : Color.white.opacity(0.85)
                ) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.settings.theme = (viewModel.settings.theme == .dark) ? .light : .dark
                        SettingsStorageService.save(viewModel.settings)
                    }
                }
                .help(isLight ? "Switch to Dark Theme" : "Switch to Light Theme")
                
                // Mic / Playback Toggle Button
                circularButton(
                    icon: viewModel.isPlaying ? "mic.fill" : "mic.slash.fill",
                    tint: viewModel.isPlaying ? (isLight ? Color.black : Color.white) : (isLight ? Color.black.opacity(0.40) : Color.white.opacity(0.50))
                ) {
                    viewModel.togglePlayPause()
                }
                .help(viewModel.isPlaying ? "Pause (Space)" : "Start (Space)")
                
                // Close Button
                circularButton(icon: "xmark") {
                    onDismiss()
                }
                .help("Close (Esc)")
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 16)
        .padding(.top, 4)
    }
    
    // MARK: - Circular Button Component
    
    private func circularButton(
        icon: String,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        let buttonTint = tint ?? (isLight ? Color.black.opacity(0.80) : Color.white.opacity(0.85))
        let buttonBg = isLight ? Color.black.opacity(0.07) : Color.white.opacity(0.12)
        
        return Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(buttonTint)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(buttonBg)
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Progress Dots Component
    
    private var progressDots: some View {
        let totalDots = 14
        let progress = max(0, min(1, viewModel.position.progress))
        let filledCount = viewModel.totalWordsCount > 0 ? Int((progress * Double(totalDots)).rounded()) : 0
        
        let filledColor = isLight ? Color.black.opacity(0.75) : Color.white.opacity(0.75)
        let emptyColor = isLight ? Color.black.opacity(0.18) : Color.white.opacity(0.20)
        
        return HStack(spacing: 4) {
            ForEach(0..<totalDots, id: \.self) { index in
                Circle()
                    .fill(index < filledCount ? filledColor : emptyColor)
                    .frame(width: 5, height: 5)
            }
        }
    }
    
    // MARK: - Edge Resize Handles
    
    private var edgeResizeHandles: some View {
        ZStack {
            // Bottom edge handle (resize height)
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.001))
                    .frame(height: 12)
                    .onHover { h in
                        if h { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                if !windowController.isResizing {
                                    windowController.startResize()
                                }
                                windowController.updateResize(deltaWidth: 0, deltaHeight: value.translation.height)
                            }
                            .onEnded { _ in
                                windowController.endResize()
                            }
                    )
            }
            
            // Left edge handle (resize width)
            HStack {
                Rectangle()
                    .fill(Color.white.opacity(0.001))
                    .frame(width: 14)
                    .onHover { h in
                        if h { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                if !windowController.isResizing {
                                    windowController.startResize()
                                }
                                windowController.updateResize(deltaWidth: -value.translation.width * 2, deltaHeight: 0)
                            }
                            .onEnded { _ in
                                windowController.endResize()
                            }
                    )
                Spacer()
            }
            
            // Right edge handle (resize width)
            HStack {
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.001))
                    .frame(width: 14)
                    .onHover { h in
                        if h { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                if !windowController.isResizing {
                                    windowController.startResize()
                                }
                                windowController.updateResize(deltaWidth: value.translation.width * 2, deltaHeight: 0)
                            }
                            .onEnded { _ in
                                windowController.endResize()
                            }
                    )
            }
            
            // Bottom-Right corner handle (resize width + height)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.white.opacity(0.001))
                        .frame(width: 22, height: 22)
                        .onHover { h in
                            if h { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 1)
                                .onChanged { value in
                                    if !windowController.isResizing {
                                        windowController.startResize()
                                    }
                                    windowController.updateResize(deltaWidth: value.translation.width * 2, deltaHeight: value.translation.height)
                                }
                                .onEnded { _ in
                                    windowController.endResize()
                                }
                        )
                }
            }
            
            // Bottom-Left corner handle (resize width + height)
            VStack {
                Spacer()
                HStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.001))
                        .frame(width: 22, height: 22)
                        .onHover { h in
                            if h { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 1)
                                .onChanged { value in
                                    if !windowController.isResizing {
                                        windowController.startResize()
                                    }
                                    windowController.updateResize(deltaWidth: -value.translation.width * 2, deltaHeight: value.translation.height)
                                }
                                .onEnded { _ in
                                    windowController.endResize()
                                }
                        )
                    Spacer()
                }
            }
        }
    }
}

// MARK: - AppKit Key Event Handler for Global Shortcuts

struct KeyboardNavigationHelper: NSViewRepresentable {
    var onSpace: () -> Void
    var onLeft: () -> Void
    var onRight: () -> Void
    var onUp: () -> Void
    var onDown: () -> Void
    var onEscape: () -> Void
    var onReset: (() -> Void)? = nil
    var onSpeedUp: (() -> Void)? = nil
    var onSpeedDown: (() -> Void)? = nil
    var onFontGrow: (() -> Void)? = nil
    var onFontShrink: (() -> Void)? = nil
    var onToggleDebug: (() -> Void)? = nil
    
    func makeNSView(context: Context) -> KeyView {
        let view = KeyView()
        updateKeyView(view)
        return view
    }
    
    func updateNSView(_ nsView: KeyView, context: Context) {
        updateKeyView(nsView)
    }
    
    private func updateKeyView(_ view: KeyView) {
        view.onSpace = onSpace
        view.onLeft = onLeft
        view.onRight = onRight
        view.onUp = onUp
        view.onDown = onDown
        view.onEscape = onEscape
        view.onReset = onReset
        view.onSpeedUp = onSpeedUp
        view.onSpeedDown = onSpeedDown
        view.onFontGrow = onFontGrow
        view.onFontShrink = onFontShrink
        view.onToggleDebug = onToggleDebug
    }
    
    final class KeyView: NSView {
        var onSpace: (() -> Void)?
        var onLeft: (() -> Void)?
        var onRight: (() -> Void)?
        var onUp: (() -> Void)?
        var onDown: (() -> Void)?
        var onEscape: (() -> Void)?
        var onReset: (() -> Void)?
        var onSpeedUp: (() -> Void)?
        var onSpeedDown: (() -> Void)?
        var onFontGrow: (() -> Void)?
        var onFontShrink: (() -> Void)?
        var onToggleDebug: (() -> Void)?
        
        override var acceptsFirstResponder: Bool { true }
        
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.makeFirstResponder(self)
        }
        
        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 49: // Space
                onSpace?()
            case 123: // Left Arrow
                onLeft?()
            case 124: // Right Arrow
                onRight?()
            case 126: // Up Arrow
                onUp?()
            case 125: // Down Arrow
                onDown?()
            case 53: // Escape
                onEscape?()
            case 15: // 'R' or 'r'
                onReset?()
            case 2: // 'D' or 'd' (Toggle Debug HUD)
                onToggleDebug?()
            case 24: // '+' or '='
                onSpeedUp?()
            case 27: // '-' or '_'
                onSpeedDown?()
            case 30: // ']'
                onFontGrow?()
            case 33: // '['
                onFontShrink?()
            default:
                super.keyDown(with: event)
            }
        }
    }
}
