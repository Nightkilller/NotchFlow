import SwiftUI

// MARK: - Teleprompter Debug HUD View

/// Live development debug panel providing transparency into speech recognition,
/// local Metal inference latency, sequence alignment decisions, and jump protection guards.
struct TeleprompterDebugView: View {
    @ObservedObject var viewModel: TeleprompterViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Engine & Status
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.isListening ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text("DEBUG HUD")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppColors.accent)
                }
                
                Spacer()
                
                // Engine Selector
                Picker("", selection: $viewModel.settings.speechEngine) {
                    Text("Whisper M4").tag(SpeechEngineType.whisper)
                    Text("Apple Speech").tag(SpeechEngineType.appleSpeech)
                    Text("Cadence").tag(SpeechEngineType.audioCadence)
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .font(.system(size: 10))
                
                Button {
                    viewModel.settings.showDebugHUD = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppColors.secondaryText)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
                .background(AppColors.divider)
            
            // Grid of telemetry
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                // Row 1: Engine & Model
                GridRow {
                    Text("Engine:")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppColors.secondaryText)
                    Text(viewModel.activeSpeechEngineName)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppColors.primaryText)
                    
                    Text("Model:")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppColors.secondaryText)
                    Text(viewModel.whisperService.modelPath != nil ? "ggml-base.en (Metal)" : "None")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundStyle(AppColors.primaryText)
                }
                
                // Row 2: Latency & Position
                GridRow {
                    Text("Latency:")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppColors.secondaryText)
                    Text(String(format: "%.1f ms", viewModel.inferenceLatencyMs))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(viewModel.inferenceLatencyMs < 200 ? Color.green : Color.yellow)
                    
                    Text("Index:")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppColors.secondaryText)
                    Text("\(viewModel.position.currentWordIndex) / \(max(0, viewModel.totalWordsCount - 1))")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppColors.primaryText)
                }
                
                // Row 3: Latest Heard Speech
                GridRow {
                    Text("Transcript:")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppColors.secondaryText)
                    Text(viewModel.latestTranscript.isEmpty ? "—" : "\"\(viewModel.latestTranscript)\"")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color.cyan)
                        .lineLimit(1)
                        .gridCellColumns(3)
                }
                
                // Row 4: Alignment Decision
                if let result = viewModel.latestResult {
                    GridRow {
                        Text("Decision:")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppColors.secondaryText)
                        Text(formatDecision(result.decision))
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(decisionColor(result.decision))
                            .lineLimit(1)
                            .gridCellColumns(3)
                    }
                    
                    GridRow {
                        Text("Confidence:")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppColors.secondaryText)
                        Text(String(format: "%.1f%%", result.confidence * 100))
                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                            .foregroundStyle(AppColors.primaryText)
                        
                        Text("Matched:")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppColors.secondaryText)
                        Text(result.matchedPhrase.isEmpty ? "—" : "\"\(result.matchedPhrase)\"")
                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                            .foregroundStyle(AppColors.primaryText)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppColors.accent.opacity(0.3), lineWidth: 1)
                )
        )
        .frame(maxWidth: 480)
        .shadow(radius: 4)
    }
    
    private func formatDecision(_ decision: AlignmentDecision) -> String {
        switch decision {
        case .initialStart:
            return "Initial Start"
        case .sequentialAdvance(let words):
            return "Advance (+\(words) word\(words == 1 ? "" : "s"))"
        case .multiWordPhraseMatch(let words, let jump):
            return "Multi-Word Match (\(words) words, jump +\(jump))"
        case .backwardCorrection(let words, let jump):
            return "Backward Correction (\(words) words, jump -\(jump))"
        case .provisionalMatch(let target, let score, let count):
            return "Provisional (index \(target), score \(String(format: "%.2f", score)), count \(count))"
        case .rejectedWeakMatch(let score, let threshold):
            return "Rejected Weak Match (\(String(format: "%.2f", score)) < \(String(format: "%.2f", threshold)))"
        case .rejectedLargeForwardJump(let proposed, let current, let jump):
            return "Rejected Large Jump (from \(current) to \(proposed), +\(jump))"
        case .rejectedBackwardJitter(let proposed, let current):
            return "Rejected Backward Jitter (from \(current) to \(proposed))"
        case .emptyTranscription:
            return "Empty Speech Frame"
        case .staleTranscript:
            return "Duplicate / Stale Transcript"
        case .manualReset(let to):
            return "Manual Navigation Reset (to \(to))"
        case .endOfScriptReached:
            return "End of Script Reached"
        }
    }
    
    private func decisionColor(_ decision: AlignmentDecision) -> Color {
        switch decision {
        case .initialStart, .sequentialAdvance, .multiWordPhraseMatch, .manualReset:
            return Color.green
        case .backwardCorrection:
            return Color.purple
        case .provisionalMatch:
            return Color.yellow
        case .rejectedWeakMatch, .rejectedLargeForwardJump, .rejectedBackwardJitter:
            return Color.red
        case .emptyTranscription, .staleTranscript, .endOfScriptReached:
            return Color.gray
        }
    }
}
