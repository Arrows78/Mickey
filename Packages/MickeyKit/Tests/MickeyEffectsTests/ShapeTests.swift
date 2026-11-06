import AppKit
import CoreGraphics
import Testing
import MickeyDomain
@testable import MickeyEffects

@Suite("Shapes") @MainActor
struct ShapeTests {
    let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)

    @Test func dimPathLeavesHoleClear() {
        let hole = SpotlightHole.ellipse(CGRect(x: 100, y: 100, width: 200, height: 200))
        let path = Shapes.dimPath(bounds: bounds, hole: hole)
        #expect(!path.contains(CGPoint(x: 200, y: 200), using: .evenOdd))
        #expect(path.contains(CGPoint(x: 600, y: 500), using: .evenOdd))
    }

    @Test func bandHole() {
        let path = Shapes.dimPath(bounds: bounds, hole: .band(CGRect(x: 0, y: 270, width: 800, height: 60)))
        #expect(!path.contains(CGPoint(x: 700, y: 300), using: .evenOdd))
        #expect(path.contains(CGPoint(x: 700, y: 100), using: .evenOdd))
    }

    @Test func noHoleDimsEverything() {
        #expect(Shapes.dimPath(bounds: bounds, hole: nil).contains(CGPoint(x: 1, y: 1), using: .evenOdd))
    }

    @Test func decorativeShapesAreCentred() {
        for path in [Shapes.star(radius: 10), Shapes.circle(radius: 10), Shapes.heart(size: 20)] {
            let box = path.boundingBox
            #expect(abs(box.midX) < 1.5)
            #expect(box.width > 15 && box.width < 25)
        }
    }

    @Test func colorConversionRoundTrips() {
        let c = RGBAColor(red: 0.25, green: 0.5, blue: 0.75, alpha: 0.5)
        let back = RGBAColor(c.nsColor)
        #expect(abs(back.red - 0.25) < 0.001 && abs(back.alpha - 0.5) < 0.001)
    }
}
