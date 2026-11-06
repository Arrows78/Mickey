import AppKit
import Testing
import MickeyDomain
@testable import MickeyStudio

@Suite("Region picker") @MainActor
struct RegionPickerTests {
    /// A screen that is not at the origin, to check that the selection comes back in screen coordinates.
    let screen = CGRect(x: 1000, y: 200, width: 800, height: 600)

    private func mouse(_ type: NSEvent.EventType, _ x: Double, _ y: Double) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: CGPoint(x: x, y: y), modifierFlags: [], timestamp: 0, windowNumber: 0,
                           context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
    }

    private func drag(_ view: RegionSelectionView, from a: (Double, Double), to b: (Double, Double)) {
        view.mouseDown(with: mouse(.leftMouseDown, a.0, a.1))
        view.mouseDragged(with: mouse(.leftMouseDragged, b.0, b.1))
        view.mouseUp(with: mouse(.leftMouseUp, b.0, b.1))
    }

    @Test func draggingGivesTheRectangleInScreenCoordinates() {
        let view = RegionSelectionView(screen: screen)
        var result: CGRect??
        view.onFinish = { result = .some($0) }
        drag(view, from: (100, 100), to: (300, 250))
        #expect(result == .some(CGRect(x: 1100, y: 300, width: 200, height: 150)))
    }

    @Test func aTinyDragCancels() {
        let view = RegionSelectionView(screen: screen)
        var result: CGRect??
        view.onFinish = { result = .some($0) }
        drag(view, from: (100, 100), to: (130, 120))
        #expect(result == .some(nil))
    }

    @Test func escapeCancels() throws {
        let view = RegionSelectionView(screen: screen)
        var result: CGRect??
        view.onFinish = { result = .some($0) }
        let esc = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
                                                context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}",
                                                isARepeat: false, keyCode: 53))
        view.keyDown(with: esc)
        #expect(result == .some(nil))
    }

    @Test func theSelectionIsClearAndTheRestIsDimmed() throws {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 300)
        let rep = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 400, pixelsHigh: 300, bitsPerSample: 8, samplesPerPixel: 4,
                                                hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let context = try #require(NSGraphicsContext(bitmapImageRep: rep))
        RegionSelectionView.draw(selection: CGRect(x: 100, y: 100, width: 200, height: 100), in: bounds, context: context.cgContext)
        let inside = try #require(rep.colorAt(x: 200, y: 150))
        let outside = try #require(rep.colorAt(x: 10, y: 10))
        #expect(inside.alphaComponent == 0, "the selection must stay clear")
        #expect(outside.alphaComponent > 0.3 && outside.alphaComponent < 0.4, "the rest is dimmed: \(outside.alphaComponent)")
    }
}
