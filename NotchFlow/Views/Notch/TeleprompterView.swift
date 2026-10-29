import SwiftUI

// MARK: - Teleprompter Reading View

/// The primary teleprompter display window featuring word-level visual synchronization,
/// auto-scrolling viewport, playback controls, reading guide line, mirror mode,
/// pre-start countdown, and keyboard navigation.
///
/// Features:
/// - Compact 2-Line Notch Attachment: Seamlessly attaches flush beneath the MacBook camera notch,
///   showing only 2 lines (active line + upcoming line) in a hidden-like unobtrusive presentation.
/// - Automatic Line-by-Line Advance: When a line completes in word wrap, it automatically glides to the next line.
/// - Hover Expansion: Hovering the cursor over the notch expands the full prompter controls HUD.
struct TeleprompterView: View {
    @ObservedObject var viewModel: TeleprompterViewModel
    @ObservedObject private var windowController = NotchWindowController.shared
    let onDismiss: () -> Void
    var onCollapse: (() -> Void)? = nil
    
    @SwiftUI.State private var showControlsHUD: Bool = true
    
    private var isExpanded: Bool {
        windowController.isHoverExpanded || windowController.isPinnedExpanded
    }
    
    private var notchTopOffset: CGFloat {
        let notchInfo = DisplayGeometryService.shared.currentNotchInfo
        return notchInfo.hasNotch ? notchInfo.topSafeAreaHeight : 6
    }
    
    private var compactFontSize: CGFloat {
        18
    }
    
    private var allWords: [ScriptWord] {
        viewModel.script.allWords
    }
    
    private var lines: [ScriptLine] {
        let maxWidth = viewModel.settings.readingAreaWidth - 48
        let fontSize = isExpanded ? viewModel.settings.fontSize : compactFontSize
        return ScriptLineWrapService.computeLines(
            words: allWords,
            maxWidth: maxWidth,
            fontSize: fontSize
        )
    }
    
    private var activeLineIndex: Int {
        ScriptLineWrapService.activeLineIndex(
            for: viewModel.position.currentWordIndex,
            in: lines
        )
    }
    
    var body: some View {
        ZStack {
            // Dark reading backdrop
            AppColors.primaryBackground
                .ignoresSafeArea()
            
            if isExpanded {
                expandedPrompterContent
            } else {
                compactTwoLineView
            }
        }
        .preferredColorScheme(.dark)
        // Expand controls when mouse hovers over the notch teleprompter, collapse when it leaves
        .onHover { isHovered in
            windowController.setHovered(isHovered)
        }
        // Global keyboard handling for prompter navigation
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
    }
    
    // MARK: - Compact 2-Line Notch Attachment View
    
    private var compactTwoLineView: some View {
        let linesList = self.lines
        let currentIdx = self.activeLineIndex
        let currentLine = linesList.indices.contains(currentIdx) ? linesList[currentIdx] : nil
        let nextLine = linesList.indices.contains(currentIdx + 1) ? linesList[currentIdx + 1] : nil
        
        return VStack(alignment: .leading, spacing: 4) {
            // Line 1: Active Reading Line
            if let current = currentLine {
                HStack(spacing: 6) {
                    ForEach(current.words) { word in
                        WordHighlightView(
                            word: word,
                            state: viewModel.visualState(for: word),
                            fontSize: compactFontSize,
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
                Text(viewModel.script.title)
                    .font(AppTypography.teleprompterFont(size: compactFontSize))
                    .foregroundStyle(AppColors.secondaryText)
            }
            
            // Line 2: Upcoming Next Line
            if let next = nextLine {
                HStack(spacing: 6) {
                    ForEach(next.words) { word in
                        WordHighlightView(
                            word: word,
                            state: viewModel.visualState(for: word),
                            fontSize: compactFontSize,
                            onTap: { viewModel.jumpToWord(at: word.globalIndex) }
                        )
                        .id(word.id)
                    }
                }
                .opacity(0.65)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
                .id("compact-line-\(next.id)")
            } else {
                HStack(spacing: 4) {
                    Text("• End of Script •")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.secondaryText.opacity(0.45))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, AppSpacing.xl)
        .padding(.top, notchTopOffset + 2)
        .padding(.bottom, 6)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: currentIdx)
    }
    
    // MARK: - Expanded Prompter Content
    
    private var expandedPrompterContent: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar
            
            Divider()
                .background(AppColors.divider)
            
            // Status message banner
            if let msg = viewModel.statusMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.yellow)
                    Text(msg)
                        .font(AppTypography.smallLabel)
                        .foregroundStyle(AppColors.primaryText)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        viewModel.statusMessage = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9))
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, 4)
                .background(Color.yellow.opacity(0.15))
            }
            
            // Reading Surface
            ZStack {
                readingSurface
                
                // Reading Guide Line Overlay
                if viewModel.settings.showReadingGuide {
                    readingGuideLine
                }
                
                // Countdown Overlay (3... 2... 1... Speak!)
                if let remaining = viewModel.countdownRemaining {
                    countdownOverlay(seconds: remaining)
                }
            }
            
            Divider()
                .background(AppColors.divider)
            
            // Bottom HUD Controls
            controlsHUD
            
            // Debug HUD Overlay
            if viewModel.settings.showDebugHUD {
                TeleprompterDebugView(viewModel: viewModel)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Header Bar
    
    private var headerBar: some View {
        HStack {
            Text(viewModel.script.title)
                .font(AppTypography.settingsHeading)
                .foregroundStyle(AppColors.primaryText)
                .lineLimit(1)
            
            Spacer()
            
            // Listening indicator if in voice-paced mode
            if viewModel.isListening {
                HStack(spacing: 4) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.accent)
                    Text("Listening")
                        .font(AppTypography.smallLabel)
                        .foregroundStyle(AppColors.accent)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(AppColors.accent.opacity(0.12))
                .clipShape(Capsule())
            }
            
            // Reading Mode Picker
            Picker("", selection: $viewModel.settings.readingMode) {
                Text("Voice").tag(ReadingMode.voicePaced)
                Text("Auto").tag(ReadingMode.autoScroll)
                Text("Manual").tag(ReadingMode.manual)
            }
            .pickerStyle(.segmented)
            .frame(width: 190)
            
            // Simulation / Debug Mode Button
            Button {
                viewModel.toggleSimulation()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.isSimulating ? "sparkles" : "play.badge.sparkle")
                        .font(.system(size: 11))
                    Text(viewModel.isSimulating ? "Simulating" : "Simulate")
                        .font(AppTypography.smallLabel)
                }
                .foregroundStyle(viewModel.isSimulating ? AppColors.accent : AppColors.secondaryText)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 4)
                .background(
                    viewModel.isSimulating
                        ? AppColors.accent.opacity(0.15)
                        : AppColors.surfaceBackground
                )
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusSm))
            }
            .buttonStyle(.plain)
            .help("Debug mode: Simulates speech-paced reading without a microphone")
            
            // Elapsed Time Display
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "timer")
                    .font(.system(size: 11))
                Text(viewModel.elapsedTimeFormatted)
                    .font(AppTypography.timerDisplay)
            }
            .foregroundStyle(AppColors.secondaryText)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xxs)
            .background(AppColors.surfaceBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusSm))
            
            // Debug HUD Button
            Button {
                viewModel.settings.showDebugHUD.toggle()
            } label: {
                Image(systemName: viewModel.settings.showDebugHUD ? "wrench.and.screwdriver.fill" : "wrench.and.screwdriver")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(viewModel.settings.showDebugHUD ? AppColors.accent : AppColors.secondaryText)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Toggle Alignment & Whisper Debug HUD (D)")
            
            // Pin / Lock Expanded Button
            Button {
                windowController.togglePinExpanded()
            } label: {
                Image(systemName: windowController.isPinnedExpanded ? "pin.fill" : "pin")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(windowController.isPinnedExpanded ? AppColors.accent : AppColors.secondaryText)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(windowController.isPinnedExpanded ? "Unpin (Auto-collapse to 2 lines when cursor leaves)" : "Pin Controls Expanded")
            
            // Collapse Button (if hosted inside notch container)
            if let onCollapse = onCollapse {
                Button {
                    onCollapse()
                } label: {
                    Image(systemName: "arrow.up.backward.and.arrow.down.forward")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.secondaryText)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("Collapse to Notch Pill")
            }
            
            // Close / Exit Button
            Button {
                viewModel.pause()
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(AppColors.secondaryText)
            }
            .buttonStyle(.plain)
            .help("Close Teleprompter (Esc)")
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, notchTopOffset + AppSpacing.xs)
        .padding(.bottom, AppSpacing.sm)
        .background(AppColors.secondaryBackground)
    }
    
    // MARK: - Reading Surface
    
    private var readingSurface: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 10) {
                    Spacer()
                        .frame(height: 24)
                    
                    ForEach(lines) { line in
                        HStack(spacing: 6) {
                            ForEach(line.words) { word in
                                WordHighlightView(
                                    word: word,
                                    state: viewModel.visualState(for: word),
                                    fontSize: viewModel.settings.fontSize,
                                    onTap: {
                                        viewModel.jumpToWord(at: word.globalIndex)
                                    }
                                )
                                .id(word.id)
                            }
                        }
                        .id("expanded-line-\(line.id)")
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusSm)
                                .fill(line.id == activeLineIndex ? AppColors.surfaceBackground.opacity(0.4) : Color.clear)
                        )
                    }
                    
                    Spacer()
                        .frame(height: 100)
                }
                .padding(.horizontal, AppSpacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
                .scaleEffect(x: viewModel.settings.mirrorText ? -1 : 1, y: 1)
            }
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.08),
                        .init(color: .black, location: 0.92),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            // Smoothly auto-scroll line-by-line as active line progresses
            .onChange(of: activeLineIndex) { _, lineIdx in
                withAnimation(AnimationConfig.viewportScroll) {
                    proxy.scrollTo("expanded-line-\(lineIdx)", anchor: .center)
                }
            }
        }
    }
    
    // MARK: - Reading Guide Line (Eye-Level)
    
    private var readingGuideLine: some View {
        GeometryReader { geo in
            let guideY = geo.size.height * 0.38
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AppColors.accent.opacity(0.8))
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.accent.opacity(0.4),
                                AppColors.accent.opacity(0.1),
                                AppColors.accent.opacity(0.4)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                
                Image(systemName: "chevron.left")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AppColors.accent.opacity(0.8))
            }
            .padding(.horizontal, AppSpacing.lg)
            .position(x: geo.size.width / 2, y: guideY)
            .allowsHitTesting(false)
        }
    }
    
    // MARK: - Countdown Overlay
    
    private func countdownOverlay(seconds: Int) -> some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()
            
            VStack(spacing: AppSpacing.sm) {
                Text("\(seconds)")
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.accent)
                    .shadow(color: AppColors.accent.opacity(0.6), radius: 18)
                    .transition(.scale.combined(with: .opacity))
                    .id("countdown-\(seconds)")
                
                Text("Get Ready to Speak")
                    .font(AppTypography.settingsHeading)
                    .foregroundStyle(AppColors.primaryText)
                
                Button("Skip Countdown") {
                    viewModel.play()
                }
                .buttonStyle(.plain)
                .font(AppTypography.smallLabel)
                .foregroundStyle(AppColors.secondaryText)
                .padding(.top, AppSpacing.xs)
            }
        }
        .transition(.opacity)
        .animation(AnimationConfig.standard, value: seconds)
    }
    
    // MARK: - Controls HUD
    
    private var controlsHUD: some View {
        VStack(spacing: AppSpacing.sm) {
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.surfaceBackground)
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.accentGradient)
                        .frame(
                            width: max(0, geo.size.width * CGFloat(viewModel.position.progress)),
                            height: 4
                        )
                }
            }
            .frame(height: 4)
            .padding(.horizontal, AppSpacing.lg)
            
            // Voice Activity Cadence Meter & Live Feedback
            if viewModel.settings.readingMode == .voicePaced && viewModel.isPlaying {
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(viewModel.isSpeaking ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                            .scaleEffect(viewModel.isSpeaking ? 1.3 : 1.0)
                            .animation(.spring(response: 0.2), value: viewModel.isSpeaking)
                        
                        Text(viewModel.isSpeaking ? "Speaking" : "Paused (Speak to advance)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(viewModel.isSpeaking ? Color.green : AppColors.secondaryText)
                    }
                    
                    // Reactive audio level bar
                    GeometryReader { barGeo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(AppColors.surfaceBackground)
                                .frame(height: 4)
                            Capsule()
                                .fill(viewModel.isSpeaking ? Color.green : AppColors.accent)
                                .frame(width: max(4, barGeo.size.width * CGFloat(viewModel.audioLevel)), height: 4)
                                .animation(.easeOut(duration: 0.08), value: viewModel.audioLevel)
                        }
                    }
                    .frame(width: 48, height: 4)
                    
                    if !viewModel.latestTranscript.isEmpty {
                        Text("• \"\(viewModel.latestTranscript)\"")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(AppColors.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 3)
                .background(AppColors.surfaceBackground.opacity(0.85))
                .clipShape(Capsule())
            } else if viewModel.isListening && !viewModel.latestTranscript.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                    Text("Heard: \"\(viewModel.latestTranscript)\"")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.primaryText)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 2)
                .background(AppColors.surfaceBackground.opacity(0.85))
                .clipShape(Capsule())
            }
            
            // Primary Controls Row
            HStack {
                // Word count metrics
                Text("Word \(viewModel.currentWordDisplayIndex) of \(viewModel.totalWordsCount) (\(viewModel.progressPercent)%)")
                    .font(AppTypography.editorCaption)
                    .foregroundStyle(AppColors.secondaryText)
                
                Spacer()
                
                // Navigation Buttons
                HStack(spacing: AppSpacing.md) {
                    // Reset
                    Button {
                        viewModel.reset()
                    } label: {
                        Image(systemName: "backward.end.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .help("Reset to Beginning (R)")
                    
                    // Step Backward
                    Button {
                        viewModel.stepBackward()
                    } label: {
                        Image(systemName: "backward.frame.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(AppColors.primaryText)
                    }
                    .buttonStyle(.plain)
                    .help("Previous Word (←)")
                    
                    // Play / Pause Toggle
                    Button {
                        viewModel.togglePlayPause()
                    } label: {
                        Image(systemName: (viewModel.isPlaying || viewModel.countdownRemaining != nil) ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(AppColors.accent)
                    }
                    .buttonStyle(.plain)
                    .help(viewModel.isPlaying ? "Pause (Space)" : "Play (Space)")
                    
                    // Step Forward
                    Button {
                        viewModel.stepForward()
                    } label: {
                        Image(systemName: "forward.frame.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(AppColors.primaryText)
                    }
                    .buttonStyle(.plain)
                    .help("Next Word (→)")
                }
                
                Spacer()
                
                // Speed controls
                HStack(spacing: AppSpacing.xs) {
                    Button {
                        viewModel.updateSpeed(delta: -10)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 20, height: 20)
                            .background(AppColors.surfaceBackground)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Decrease Speed (-)")
                    
                    Text("\(Int(viewModel.settings.autoScrollSpeed)) WPM")
                        .font(AppTypography.timerDisplay)
                        .foregroundStyle(AppColors.primaryText)
                        .frame(width: 68)
                    
                    Button {
                        viewModel.updateSpeed(delta: +10)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 20, height: 20)
                            .background(AppColors.surfaceBackground)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Increase Speed (+)")
                }
                .foregroundStyle(AppColors.secondaryText)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.sm)
        }
        .padding(.top, AppSpacing.sm)
        .background(AppColors.secondaryBackground)
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
