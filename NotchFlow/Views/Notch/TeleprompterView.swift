import SwiftUI

// MARK: - Teleprompter Reading View

/// The primary teleprompter display window featuring word-level visual synchronization,
/// auto-scrolling viewport, playback controls, reading guide line, mirror mode,
/// pre-start countdown, and keyboard navigation.
struct TeleprompterView: View {
    @ObservedObject var viewModel: TeleprompterViewModel
    let onDismiss: () -> Void
    var onCollapse: (() -> Void)? = nil
    
    @SwiftUI.State private var showControlsHUD: Bool = true
    
    var body: some View {
        ZStack {
            // Dark reading backdrop
            AppColors.primaryBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: Header Bar
                headerBar
                
                Divider()
                    .background(AppColors.divider)
                
                // MARK: Reading Surface
                ZStack {
                    readingSurface
                    
                    // Reading Guide Line Overlay (Eye-level anchor)
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
                
                // MARK: Bottom HUD Controls
                controlsHUD
            }
        }
        .preferredColorScheme(.dark)
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
                onFontShrink: { viewModel.updateFontSize(delta: -2) }
            )
        )
    }
    
    // MARK: - Header Bar
    
    private var headerBar: some View {
        HStack {
            // Script Title
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
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.secondaryBackground)
    }
    
    // MARK: - Reading Surface
    
    private var readingSurface: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    // Top breathing space
                    Spacer()
                        .frame(height: 40)
                    
                    ForEach(viewModel.script.sections) { section in
                        sectionView(section)
                    }
                    
                    // Bottom padding for comfortable scrolling
                    Spacer()
                        .frame(height: 120)
                }
                .padding(.horizontal, AppSpacing.xxl)
                .frame(maxWidth: .infinity, alignment: .leading)
                // Mirror / Flip text horizontally if enabled
                .scaleEffect(x: viewModel.settings.mirrorText ? -1 : 1, y: 1)
            }
            // Soft cinematic fade at top and bottom edges
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.10),
                        .init(color: .black, location: 0.90),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            // Automatically keep current word visible and centered
            .onChange(of: viewModel.currentWordId) { _, targetWordId in
                if let targetId = targetWordId {
                    withAnimation(AnimationConfig.viewportScroll) {
                        proxy.scrollTo(targetId, anchor: .center)
                    }
                }
            }
        }
    }
    
    private func sectionView(_ section: ScriptSection) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            ForEach(section.sentences) { sentence in
                sentenceFlowView(sentence)
            }
        }
    }
    
    private func sentenceFlowView(_ sentence: ScriptSentence) -> some View {
        let isCurrent = viewModel.isCurrentSentence(sentence)
        
        return FlowLayout(spacing: AppSpacing.sm) {
            ForEach(sentence.words) { word in
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
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMd)
                .fill(isCurrent ? AppColors.surfaceBackground.opacity(0.65) : Color.clear)
        )
        .animation(AnimationConfig.standard, value: isCurrent)
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

// MARK: - Flow Layout for Word Wrapping

/// A simple flow layout wrapping word tokens across multiple lines natively.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 600
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        height = currentY + lineHeight
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
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
