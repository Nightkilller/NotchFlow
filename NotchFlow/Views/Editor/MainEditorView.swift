import SwiftUI

// MARK: - Main Editor View

/// The primary window of NotchFlow.
/// Displays a script editor with a sidebar for script library and a main editing area.
/// This is a placeholder for Phase 0 — it will be fully implemented in Phase 1.
struct MainEditorView: View {
    @SwiftUI.State private var sampleText: String = ""
    @SwiftUI.State private var scriptTitle: String = "Untitled Script"

    var body: some View {
        ZStack {
            AppColors.primaryBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: Title Bar Area
                titleBar

                Divider()
                    .background(AppColors.divider)

                // MARK: Main Content
                HStack(spacing: 0) {
                    // Sidebar placeholder
                    sidebar

                    Divider()
                        .background(AppColors.divider)

                    // Editor area
                    editorArea
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack {
            Image(systemName: "text.word.spacing")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppColors.accent)

            Text("NotchFlow")
                .font(AppTypography.editorSubtitle)
                .foregroundStyle(AppColors.primaryText)

            Spacer()

            Text("\(wordCount) words")
                .font(AppTypography.editorCaption)
                .foregroundStyle(AppColors.secondaryText)

            if !sampleText.isEmpty {
                Text("·")
                    .foregroundStyle(AppColors.secondaryText)

                Text(estimatedDuration)
                    .font(AppTypography.editorCaption)
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.secondaryBackground)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Scripts")
                .font(AppTypography.settingsHeading)
                .foregroundStyle(AppColors.primaryText)
                .padding(.top, AppSpacing.lg)

            // Placeholder script list
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                sidebarItem(title: scriptTitle, isSelected: true)
            }

            Spacer()

            // New script button
            Button {
                scriptTitle = "Untitled Script"
                sampleText = ""
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "plus.circle.fill")
                    Text("New Script")
                }
                .font(AppTypography.buttonLabel)
                .foregroundStyle(AppColors.accent)
            }
            .buttonStyle(.plain)
            .padding(.bottom, AppSpacing.lg)
        }
        .padding(.horizontal, AppSpacing.lg)
        .frame(width: AppSpacing.editorSidebarWidth)
        .background(AppColors.secondaryBackground)
    }

    private func sidebarItem(title: String, isSelected: Bool) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "doc.text")
                .font(.system(size: 12))
            Text(title)
                .font(AppTypography.editorBody)
                .lineLimit(1)
            Spacer()
        }
        .foregroundStyle(isSelected ? AppColors.accent : AppColors.secondaryText)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(
            isSelected
                ? AppColors.accent.opacity(0.1)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusSm))
    }

    // MARK: - Editor Area

    private var editorArea: some View {
        VStack(spacing: 0) {
            // Script title
            HStack {
                TextField("Script Title", text: $scriptTitle)
                    .textFieldStyle(.plain)
                    .font(AppTypography.editorTitle)
                    .foregroundStyle(AppColors.primaryText)

                Spacer()

                // Start Teleprompter button (placeholder — wired in Phase 2)
                Button {
                    // Will open NotchPrompterView in Phase 2
                    AppLogger.app.info("Start Teleprompter tapped — not yet implemented")
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "play.fill")
                        Text("Start")
                    }
                    .font(AppTypography.buttonLabel)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMd))
                }
                .buttonStyle(.plain)
                .disabled(sampleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(
                    sampleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0
                )
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, AppSpacing.md)

            // Text editor
            TextEditor(text: $sampleText)
                .font(AppTypography.editorBody)
                .foregroundStyle(AppColors.primaryText)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.lg)

            // Placeholder prompt when empty
            if sampleText.isEmpty {
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "text.cursor")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(AppColors.secondaryText.opacity(0.5))

                    Text("Paste or type your script here")
                        .font(AppTypography.editorBody)
                        .foregroundStyle(AppColors.secondaryText)

                    Text("You can also import TXT, PDF, or Markdown files")
                        .font(AppTypography.editorCaption)
                        .foregroundStyle(AppColors.secondaryText.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            }
        }
        .background(AppColors.primaryBackground)
    }

    // MARK: - Computed Properties

    private var wordCount: Int {
        sampleText
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .count
    }

    private var estimatedDuration: String {
        let wpm = 150.0
        let minutes = Double(wordCount) / wpm
        if minutes < 1 {
            return "< 1 min"
        } else {
            return String(format: "~%.0f min", minutes.rounded())
        }
    }
}

// Note: #Preview requires Xcode. Test by running: swift run NotchFlow
