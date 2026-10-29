import AppKit
import Combine

// MARK: - Display Notch Information

/// Geometry measurements of a screen and its physical notch (if present).
struct DisplayNotchInfo: Sendable, Equatable {
    let hasNotch: Bool
    let notchFrame: CGRect
    let notchCenter: CGPoint
    let topSafeAreaHeight: CGFloat
    let screenFrame: CGRect
    let visibleFrame: CGRect
    
    /// Calculates the origin and size for a window anchored to the notch.
    /// - Parameters:
    ///   - width: Desired window width.
    ///   - height: Desired window height.
    ///   - attachDirectlyToTop: If true, top of window touches top of display; if false, begins below the menu bar/notch.
    /// - Returns: Window frame in AppKit screen coordinates (origin at bottom-left).
    func calculateWindowFrame(width: CGFloat, height: CGFloat, attachDirectlyToTop: Bool = true) -> CGRect {
        // Center horizontally on notch
        let originX = notchCenter.x - (width / 2.0)
        
        let originY: CGFloat
        if attachDirectlyToTop {
            // Anchor to top edge of screen, extending downwards
            originY = screenFrame.maxY - height
        } else {
            // Anchor just below the notch / menu bar
            let notchBottomY = screenFrame.maxY - (hasNotch ? notchFrame.height : topSafeAreaHeight)
            originY = notchBottomY - height
        }
        
        return CGRect(
            x: originX.rounded(),
            y: originY.rounded(),
            width: width.rounded(),
            height: height.rounded()
        )
    }
}

// MARK: - Display Geometry Service

/// Detects screen geometry and notch metrics using native macOS AppKit APIs.
/// Automatically observes display reconfiguration events.
@MainActor
final class DisplayGeometryService: ObservableObject {
    
    static let shared = DisplayGeometryService()
    
    @Published private(set) var currentNotchInfo: DisplayNotchInfo
    private var screenNotificationObserver: AnyCancellable?
    
    private init() {
        self.currentNotchInfo = Self.detectNotchGeometry()
        
        // Listen for screen resolution and display topology changes
        self.screenNotificationObserver = NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.recalculateGeometry()
                }
            }
    }
    
    func recalculateGeometry() {
        let newInfo = Self.detectNotchGeometry()
        if newInfo != currentNotchInfo {
            currentNotchInfo = newInfo
            AppLogger.window.info("Display geometry recalculated: hasNotch=\(newInfo.hasNotch), notchWidth=\(newInfo.notchFrame.width)")
        }
    }
    
    // MARK: - Geometry Detection
    
    static func detectNotchGeometry() -> DisplayNotchInfo {
        // Locate screen: prefer the built-in screen with a notch, or fall back to main screen
        let screens = NSScreen.screens
        let targetScreen = screens.first(where: { screen in
            screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
        }) ?? NSScreen.main ?? screens.first
        
        guard let screen = targetScreen else {
            // Fallback default for headless/unlikely environment
            let dummy = CGRect(x: 0, y: 0, width: 1470, height: 956)
            return DisplayNotchInfo(
                hasNotch: false,
                notchFrame: .zero,
                notchCenter: CGPoint(x: 735, y: 956),
                topSafeAreaHeight: 32,
                screenFrame: dummy,
                visibleFrame: dummy
            )
        }
        
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let safeArea = screen.safeAreaInsets
        
        if let topLeft = screen.auxiliaryTopLeftArea,
           let topRight = screen.auxiliaryTopRightArea,
           topRight.minX > topLeft.maxX {
            // Physical notch detected!
            let notchWidth = topRight.minX - topLeft.maxX
            let notchHeight = safeArea.top > 0 ? safeArea.top : (screenFrame.maxY - visibleFrame.maxY)
            let notchCenterX = topLeft.maxX + (notchWidth / 2.0)
            let notchOriginY = screenFrame.maxY - notchHeight
            
            let notchFrame = CGRect(
                x: topLeft.maxX,
                y: notchOriginY,
                width: notchWidth,
                height: notchHeight
            )
            
            return DisplayNotchInfo(
                hasNotch: true,
                notchFrame: notchFrame,
                notchCenter: CGPoint(x: notchCenterX, y: screenFrame.maxY),
                topSafeAreaHeight: safeArea.top,
                screenFrame: screenFrame,
                visibleFrame: visibleFrame
            )
        } else {
            // Standard display without notch (or external monitor)
            let topHeight = max(24.0, safeArea.top > 0 ? safeArea.top : (screenFrame.maxY - visibleFrame.maxY))
            return DisplayNotchInfo(
                hasNotch: false,
                notchFrame: .zero,
                notchCenter: CGPoint(x: screenFrame.midX, y: screenFrame.maxY),
                topSafeAreaHeight: topHeight,
                screenFrame: screenFrame,
                visibleFrame: visibleFrame
            )
        }
    }
}
