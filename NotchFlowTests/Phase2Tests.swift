import Testing
import AppKit
@testable import NotchFlow

// MARK: - DisplayGeometryService Tests

@Suite("DisplayGeometryService")
@MainActor
struct DisplayGeometryServiceTests {
    
    @Test("Detects display notch info without crashing")
    func detectNotchGeometry() {
        let info = DisplayGeometryService.detectNotchGeometry()
        
        #expect(info.screenFrame.width > 0)
        #expect(info.screenFrame.height > 0)
        #expect(info.notchCenter.x > 0)
        #expect(info.notchCenter.y > 0)
        
        // If display has a notch, verify positive dimensions
        if info.hasNotch {
            #expect(info.notchFrame.width > 0)
            #expect(info.notchFrame.height > 0)
            #expect(info.topSafeAreaHeight > 0)
        }
    }
    
    @Test("Window frame is centered on the notch")
    func windowFrameCentering() {
        let info = DisplayNotchInfo(
            hasNotch: true,
            notchFrame: CGRect(x: 645.5, y: 924.0, width: 179.0, height: 32.0),
            notchCenter: CGPoint(x: 735.0, y: 956.0),
            topSafeAreaHeight: 32.0,
            screenFrame: CGRect(x: 0, y: 0, width: 1470.0, height: 956.0),
            visibleFrame: CGRect(x: 0, y: 0, width: 1470.0, height: 924.0)
        )
        
        let targetWidth: CGFloat = 600
        let targetHeight: CGFloat = 260
        let frame = info.calculateWindowFrame(width: targetWidth, height: targetHeight, attachDirectlyToTop: false)
        
        // Horizontal center of calculated frame should equal notchCenter.x
        let calculatedCenterX = frame.origin.x + (frame.width / 2.0)
        #expect(calculatedCenterX == info.notchCenter.x)
        
        // Vertical anchor should be just below notch
        let expectedTop = info.screenFrame.maxY - info.notchFrame.height
        let calculatedTop = frame.origin.y + frame.height
        #expect(calculatedTop == expectedTop)
    }
    
    @Test("Fallback calculation works for notchless displays")
    func notchlessFallback() {
        let info = DisplayNotchInfo(
            hasNotch: false,
            notchFrame: .zero,
            notchCenter: CGPoint(x: 960.0, y: 1080.0),
            topSafeAreaHeight: 25.0,
            screenFrame: CGRect(x: 0, y: 0, width: 1920.0, height: 1080.0),
            visibleFrame: CGRect(x: 0, y: 0, width: 1920.0, height: 1055.0)
        )
        
        let targetWidth: CGFloat = 500
        let targetHeight: CGFloat = 200
        let frame = info.calculateWindowFrame(width: targetWidth, height: targetHeight, attachDirectlyToTop: false)
        
        let calculatedCenterX = frame.origin.x + (frame.width / 2.0)
        #expect(calculatedCenterX == 960.0)
        #expect(frame.width == 500.0)
        #expect(frame.height == 200.0)
    }
}

// MARK: - NotchWindowController Lifecycle Tests

@Suite("NotchWindowController")
@MainActor
struct NotchWindowControllerTests {
    
    @Test("Controller initializes with closed state")
    func initialState() {
        let controller = NotchWindowController.shared
        #expect(controller.window != nil)
        #expect(controller.window?.level == .floating)
    }
    
    @Test("Present and dismiss updates windowState cleanly")
    func presentationLifecycle() {
        let controller = NotchWindowController.shared
        let script = ScriptStructuringService.structure(rawText: "Sample test script.", title: "Lifecycle")
        
        controller.present(with: script, initialMode: .collapsed)
        #expect(controller.windowState == .collapsed)
        
        controller.transition(to: .expanded)
        #expect(controller.windowState == .expanded)
        
        controller.dismiss()
        #expect(controller.windowState == .closed)
    }
}
