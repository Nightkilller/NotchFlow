import SwiftUI

// MARK: - Main Editor View

/// The primary window of NotchFlow.
/// Provides script authoring, live metrics, library navigation,
/// and launches the teleprompter reading view.
struct MainEditorView: View {
    @StateObject private var viewModel = EditorViewModel()

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
                    // Sidebar
                    sidebar

                    Divider()
                        .background(AppColors.divider)

                    // Editor area
                    editorArea
                }
            }
            
            // MARK: Active Session Banner
            if viewModel.isTeleprompterPresented {
                VStack {
                    HStack(spacing: AppSpacing.md) {
                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: 8, height: 8)
                        
                        Text("Notch Teleprompter Active")
                            .font(AppTypography.settingsLabel)
                            .foregroundStyle(AppColors.primaryText)
                        
                        Spacer()
                        
                        Button("Stop Teleprompter") {
                            viewModel.dismissTeleprompter()
                        }
                        .buttonStyle(.plain)
                        .font(AppTypography.buttonLabel)
                        .foregroundStyle(AppColors.accent)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMd))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMd)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
                    .padding(AppSpacing.lg)
                    .shadow(radius: 8)
                    
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
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

            Text("\(viewModel.wordCount) words")
                .font(AppTypography.editorCaption)
                .foregroundStyle(AppColors.secondaryText)

            if viewModel.wordCount > 0 {
                Text("·")
                    .foregroundStyle(AppColors.secondaryText)

                Text(viewModel.estimatedDurationFormatted)
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

            // Current Active Script
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                sidebarItem(title: viewModel.scriptTitle, isSelected: true)
            }

            // Quick Actions
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Button {
                    viewModel.loadSampleScript()
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "sparkles")
                        Text("Load Sample Script")
                    }
                    .font(AppTypography.smallLabel)
                    .foregroundStyle(AppColors.accentSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, AppSpacing.sm)

            Spacer()

            // New script button
            Button {
                viewModel.createNewScript()
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
            Text(title.isEmpty ? "Untitled Script" : title)
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
            // Script title & Start Teleprompter Button
            HStack {
                TextField("Script Title", text: $viewModel.scriptTitle)
                    .textFieldStyle(.plain)
                    .font(AppTypography.editorTitle)
                    .foregroundStyle(AppColors.primaryText)

                Spacer()

                // Start Teleprompter Button
                Button {
                    withAnimation(AnimationConfig.standard) {
                        viewModel.startTeleprompter()
                    }
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "play.fill")
                        Text("Start Teleprompter")
                    }
                    .font(AppTypography.buttonLabel)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.sm)
                    .background(viewModel.canStartTeleprompter ? AppColors.accent : AppColors.surfaceBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMd))
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canStartTeleprompter)
                .opacity(viewModel.canStartTeleprompter ? 1.0 : 0.5)
                .help(viewModel.canStartTeleprompter ? "Start Teleprompter session" : "Enter some text first to start")
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, AppSpacing.md)

            // Text editor
            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.rawText)
                    .font(AppTypography.editorBody)
                    .foregroundStyle(AppColors.primaryText)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.bottom, AppSpacing.lg)

                // Placeholder prompt when empty
                if viewModel.rawText.isEmpty {
                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "text.cursor")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(AppColors.secondaryText.opacity(0.5))

                        Text("Paste or type your script here")
                            .font(AppTypography.editorBody)
                            .foregroundStyle(AppColors.secondaryText)

                        Text("You can also import TXT, PDF, or Markdown files, or click 'Load Sample Script'")
                            .font(AppTypography.editorCaption)
                            .foregroundStyle(AppColors.secondaryText.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                }
            }
        }
        .background(AppColors.primaryBackground)
    }
}
