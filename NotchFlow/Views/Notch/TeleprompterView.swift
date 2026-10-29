import SwiftUI

// MARK: - Teleprompter Reading View

/// The primary teleprompter display window featuring word-level visual synchronization,
/// auto-scrolling viewport, playback controls, and keyboard navigation.
struct TeleprompterView: View {
    @ObservedObject var viewModel: TeleprompterViewModel
    let onDismiss: () -> Void
    
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
                readingSurface
                
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
                onEscape: { onDismiss() }
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
            
            // Reading Mode Picker
            Picker("", selection: $viewModel.settings.readingMode) {
                Text("Auto-Scroll").tag(ReadingMode.autoScroll)
                Text("Manual").tag(ReadingMode.manual)
            }
            .pickerStyle(.segmented)
            .frame(width: 170)
            
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
            }
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
                    .help("Reset to Beginning")
                    
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
                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
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
    
    func makeNSView(context: Context) -> KeyView {
        let view = KeyView()
        view.onSpace = onSpace
        view.onLeft = onLeft
        view.onRight = onRight
        view.onUp = onUp
        view.onDown = onDown
        view.onEscape = onEscape
        return view
    }
    
    func updateNSView(_ nsView: KeyView, context: Context) {
        nsView.onSpace = onSpace
        nsView.onLeft = onLeft
        nsView.onRight = onRight
        nsView.onUp = onUp
        nsView.onDown = onDown
        nsView.onEscape = onEscape
    }
    
    final class KeyView: NSView {
        var onSpace: (() -> Void)?
        var onLeft: (() -> Void)?
        var onRight: (() -> Void)?
        var onUp: (() -> Void)?
        var onDown: (() -> Void)?
        var onEscape: (() -> Void)?
        
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
            default:
                super.keyDown(with: event)
            }
        }
    }
}
