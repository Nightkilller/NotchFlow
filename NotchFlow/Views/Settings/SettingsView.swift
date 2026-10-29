import SwiftUI

// MARK: - Settings View

/// Preferences modal for configuring teleprompter dimensions, typography,
/// default reading mode, and speech recognition locale.
struct SettingsView: View {
    @Binding var settings: ReadingSettings
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("NotchFlow Settings")
                    .font(AppTypography.settingsHeading)
                    .foregroundStyle(AppColors.primaryText)
                
                Spacer()
                
                Button("Done") {
                    SettingsStorageService.save(settings)
                    onDismiss()
                }
                .buttonStyle(.plain)
                .font(AppTypography.buttonLabel)
                .foregroundStyle(AppColors.accent)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, AppSpacing.lg)
            .background(AppColors.secondaryBackground)
            
            Divider()
                .background(AppColors.divider)
            
            // Settings Form
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    
                    // Typography Section
                    settingsSection(title: "Typography") {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            HStack {
                                Text("Font Size: \(Int(settings.fontSize)) pt")
                                    .font(AppTypography.settingsLabel)
                                    .foregroundStyle(AppColors.primaryText)
                                Spacer()
                            }
                            
                            Slider(
                                value: $settings.fontSize,
                                in: AppTypography.teleprompterMinSize...AppTypography.teleprompterMaxSize,
                                step: 2
                            )
                            .tint(AppColors.accent)
                            
                            HStack {
                                Text("Line Spacing: \(String(format: "%.1f", settings.lineSpacing))x")
                                    .font(AppTypography.settingsLabel)
                                    .foregroundStyle(AppColors.primaryText)
                                Spacer()
                            }
                            
                            Slider(value: $settings.lineSpacing, in: 1.2...2.4, step: 0.1)
                                .tint(AppColors.accent)
                        }
                    }
                    
                    // Teleprompter Window Dimensions
                    settingsSection(title: "Notch Reading Area") {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            HStack {
                                Text("Width: \(Int(settings.readingAreaWidth)) pt")
                                    .font(AppTypography.settingsLabel)
                                    .foregroundStyle(AppColors.primaryText)
                                Spacer()
                            }
                            
                            Slider(
                                value: $settings.readingAreaWidth,
                                in: AppSpacing.teleprompterMinWidth...AppSpacing.teleprompterMaxWidth,
                                step: 20
                            )
                            .tint(AppColors.accent)
                            
                            HStack {
                                Text("Height: \(Int(settings.readingAreaHeight)) pt")
                                    .font(AppTypography.settingsLabel)
                                    .foregroundStyle(AppColors.primaryText)
                                Spacer()
                            }
                            
                            Slider(
                                value: $settings.readingAreaHeight,
                                in: AppSpacing.teleprompterMinHeight...AppSpacing.teleprompterMaxHeight,
                                step: 20
                            )
                            .tint(AppColors.accent)
                        }
                    }
                    
                    // Reading Defaults
                    settingsSection(title: "Playback Defaults") {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            HStack {
                                Text("Default Mode")
                                    .font(AppTypography.settingsLabel)
                                    .foregroundStyle(AppColors.primaryText)
                                Spacer()
                                
                                Picker("", selection: $settings.readingMode) {
                                    ForEach(ReadingMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 140)
                            }
                            
                            HStack {
                                Text("Fallback Auto-Scroll Speed: \(Int(settings.autoScrollSpeed)) WPM")
                                    .font(AppTypography.settingsLabel)
                                    .foregroundStyle(AppColors.primaryText)
                                Spacer()
                            }
                            
                            Slider(value: $settings.autoScrollSpeed, in: 80...300, step: 10)
                                .tint(AppColors.accent)
                        }
                    }
                    
                    // Privacy & Offline
                    settingsSection(title: "Privacy & Speech") {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("Apple Speech Framework")
                                .font(AppTypography.settingsLabel)
                                .foregroundStyle(AppColors.primaryText)
                            
                            Text("NotchFlow requests on-device speech processing whenever supported by your Mac and chosen locale. No audio or script data is stored or uploaded to external servers.")
                                .font(AppTypography.editorCaption)
                                .foregroundStyle(AppColors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(AppSpacing.xl)
            }
        }
        .frame(width: 520, height: 580)
        .background(AppColors.primaryBackground)
        .preferredColorScheme(.dark)
    }
    
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColors.secondaryText)
            
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                content()
            }
            .padding(AppSpacing.md)
            .background(AppColors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMd))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMd)
                    .stroke(AppColors.border, lineWidth: 1)
            )
        }
    }
}
