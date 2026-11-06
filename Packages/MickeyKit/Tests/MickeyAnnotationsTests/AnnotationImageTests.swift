import AppKit
import Testing
import MickeyDomain
@testable import MickeyAnnotations

@Suite("Annotation image") @MainActor
struct AnnotationImageTests {
    let canvas = CGRect(x: 0, y: 0, width: 1000, height: 800)

    private func rectangle() -> Annotation {
        Annotation(tool: .rectangle, points: [CGPoint(x: 100, y: 100), CGPoint(x: 300, y: 200)], color: .red, width: 4, createdAt: 0)
    }

    @Test func nothingDrawnGivesNoImage() {
        #expect(AnnotationImage.render([], canvas: canvas) == nil)
    }

    @Test func imageIsCroppedToWhatWasDrawn() throws {
        let image = try #require(AnnotationImage.render([rectangle()], canvas: canvas))
        #expect(image.size.width >= 200 && image.size.width < 260)
        #expect(image.size.height >= 100 && image.size.height < 160)
    }

    @Test func strokeIsOpaqueAndTheRestTransparent() throws {
        let image = try #require(AnnotationImage.render([rectangle()], canvas: canvas))
        let rep = try #require(image.representations.first as? NSBitmapImageRep)
        let center = try #require(rep.colorAt(x: rep.pixelsWide / 2, y: rep.pixelsHigh / 2))
        #expect(center.alphaComponent == 0)
        // The left edge of the rectangle is red: scan the middle row for an opaque pixel.
        let row = rep.pixelsHigh / 2
        let opaque = (0..<rep.pixelsWide).contains { rep.colorAt(x: $0, y: row)?.alphaComponent ?? 0 > 0.9 }
        #expect(opaque)
    }

    @Test func drawingOutsideTheCanvasIsLeftOut() {
        let outside = Annotation(tool: .callout, points: [CGPoint(x: 5000, y: 5000)], color: .red, width: 20, calloutNumber: 1, createdAt: 0)
        #expect(AnnotationImage.render([outside], canvas: canvas) == nil)
    }
}
