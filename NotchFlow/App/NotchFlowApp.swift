import SwiftUI

// MARK: - NotchFlow Application Entry Point

@main
struct NotchFlowApp: App {
    var body: some Scene {
        WindowGroup {
            MainEditorView()
                .frame(
                    minWidth: AppSpacing.editorMinWidth,
                    minHeight: AppSpacing.editorMinHeight
                )
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 650)
    }
}
