import AppKit
import CoreGraphics
import MickeyDomain

extension RGBAColor {
    public var cgColor: CGColor { CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha) }
    public var nsColor: NSColor { NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha) }

    public init(_ ns: NSColor) {
        let c = ns.usingColorSpace(.sRGB) ?? .white
        self.init(red: c.redComponent, green: c.greenComponent, blue: c.blueComponent, alpha: c.alphaComponent)
    }
}

/// Paths shared by the renderers. All are centred on the origin.
public enum Shapes {
    public static func circle(radius r: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2), transform: nil)
    }

    public static func star(radius r: CGFloat, points: Int = 5) -> CGPath {
        let p = CGMutablePath()
        for i in 0..<(points * 2) {
            let radius = i % 2 == 0 ? r : r * 0.45
            let a = CGFloat(i) * .pi / CGFloat(points) + .pi / 2
            let pt = CGPoint(x: cos(a) * radius, y: sin(a) * radius)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    public static func heart(size s: CGFloat) -> CGPath {
        let p = CGMutablePath()
        let h = s / 2
        p.move(to: CGPoint(x: 0, y: -h))
        p.addCurve(to: CGPoint(x: -h, y: h * 0.3), control1: CGPoint(x: -h * 0.4, y: -h * 0.5), control2: CGPoint(x: -h, y: -h * 0.2))
        p.addArc(center: CGPoint(x: -h / 2, y: h * 0.3), radius: h / 2, startAngle: .pi, endAngle: 0, clockwise: true)
        p.addArc(center: CGPoint(x: h / 2, y: h * 0.3), radius: h / 2, startAngle: .pi, endAngle: 0, clockwise: true)
        p.addCurve(to: CGPoint(x: 0, y: -h), control1: CGPoint(x: h, y: -h * 0.2), control2: CGPoint(x: h * 0.4, y: -h * 0.5))
        p.closeSubpath()
        return p
    }

    /// Arrow pointer with its tip at the origin, pointing up-left, `height` points tall.
    public static func pointer(height h: CGFloat) -> CGPath {
        let u = h / 26
        let pts: [(CGFloat, CGFloat)] = [(0, 0), (0, -22), (5.5, -17), (9.5, -26), (13, -24.5), (9, -15.5), (16, -15.5)]
        let p = CGMutablePath()
        p.move(to: .zero)
        for (x, y) in pts.dropFirst() { p.addLine(to: CGPoint(x: x * u, y: y * u)) }
        p.closeSubpath()
        return p
    }

    /// Full-screen dimming path with the spotlight hole cut out (even-odd fill).
    public static func dimPath(bounds: CGRect, hole: SpotlightHole?) -> CGPath {
        let p = CGMutablePath()
        p.addRect(bounds)
        switch hole {
        case .ellipse(let r)?: p.addEllipse(in: r)
        case .band(let r)?: p.addRect(r)
        case nil: break
        }
        return p
    }

    public static func holePath(_ hole: SpotlightHole) -> CGPath {
        switch hole {
        case .ellipse(let r): CGPath(ellipseIn: r, transform: nil)
        case .band(let r): CGPath(rect: r, transform: nil)
        }
    }
}
