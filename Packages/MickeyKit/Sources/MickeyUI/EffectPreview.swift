import SwiftUI
import MickeyDomain
import MickeyEffects

/// Shows the enabled spotlight and ring on a light and a dark background, as they are configured.
struct EffectPreview: View {
    let settings: MickeyDomain.Settings
    private let height: CGFloat = 140

    var body: some View {
        FeatureCard(title: "Live preview", symbol: "eye", subtitle: "The enabled effects, on a light and a dark background.") {
            Canvas { context, size in draw(in: &context, size: size) }
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
                .accessibilityElement()
                .accessibilityLabel(tr("Preview of the enabled effects"))
            if !settings.spotlight.enabled && !settings.ring.enabled {
                NoteView(text: "Turn on spotlight or Ring to see them here.")
            }
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let bounds = CGRect(origin: .zero, size: size)
        context.fill(Path(CGRect(x: 0, y: 0, width: size.width / 2, height: size.height)), with: .color(Color(white: 0.93)))
        context.fill(Path(CGRect(x: size.width / 2, y: 0, width: size.width / 2, height: size.height)), with: .color(Color(white: 0.16)))
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let scale = EffectPreviewLayout.scale(largest: EffectPreviewLayout.largestRadius(in: settings), height: size.height)

        if settings.spotlight.enabled {
            var spot = settings.spotlight
            spot.radius *= scale
            spot.barThickness *= scale
            let hole = SpotlightHole.make(center: center, in: bounds, settings: spot)
            var dim = Path(bounds)
            dim.addPath(holePath(hole))
            context.fill(dim, with: .color(.black.opacity(spot.backgroundOpacity)), style: FillStyle(eoFill: true))
            if spot.spotOpacity < 1 {
                context.fill(holePath(hole), with: .color(.black.opacity(spot.backgroundOpacity * (1 - spot.spotOpacity))))
            }
        }

        if settings.ring.enabled {
            let ring = settings.ring
            let r = ring.radius * scale
            let path = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
            let width = max(1, ring.thickness)
            let color = Color(nsColor: ring.color.nsColor)
            context.drawLayer { layer in
                if ring.neon { layer.addFilter(.shadow(color: color, radius: 8, x: 0, y: 0)) }
                if ring.contrastOutline {
                    layer.stroke(path, with: .color(Color(nsColor: ring.color.contrastingColor.nsColor)), lineWidth: width + 4)
                }
                layer.stroke(path, with: .color(color), lineWidth: width)
            }
        }
    }

    private func holePath(_ hole: SpotlightHole) -> Path {
        switch hole {
        case .ellipse(let rect): Path(ellipseIn: rect)
        case .band(let rect): Path(rect)
        }
    }
}
