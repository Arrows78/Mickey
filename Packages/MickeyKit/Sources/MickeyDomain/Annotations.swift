import CoreGraphics
import Foundation

public struct Annotation: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var tool: AnnotationTool
    /// Path for freehand/highlighter; [start, end] for two-point shapes; [anchor] for text/callout.
    public var points: [CGPoint]
    public var color: RGBAColor
    public var width: Double
    public var text: String?
    public var calloutNumber: Int?
    public var createdAt: TimeInterval

    public init(id: UUID = UUID(), tool: AnnotationTool, points: [CGPoint], color: RGBAColor, width: Double,
                text: String? = nil, calloutNumber: Int? = nil, createdAt: TimeInterval) {
        self.id = id; self.tool = tool; self.points = points; self.color = color; self.width = width
        self.text = text; self.calloutNumber = calloutNumber; self.createdAt = createdAt
    }

    public var boundingBox: CGRect {
        guard let f = points.first else { return .null }
        return points.dropFirst().reduce(CGRect(origin: f, size: .zero)) { $0.union(CGRect(origin: $1, size: .zero)) }
    }
}

/// Drawing state for one draw-mode session: strokes, undo history, current tool.
public struct AnnotationSession: Sendable {
    public private(set) var annotations: [Annotation] = []
    public private(set) var current: Annotation?
    public var selectedTool: AnnotationTool
    public var color: RGBAColor
    public var editingTextID: UUID?
    private var undoStack: [[Annotation]] = []

    public init(tool: AnnotationTool, color: RGBAColor) { selectedTool = tool; self.color = color }

    public var nextCalloutNumber: Int { (annotations.compactMap(\.calloutNumber).max() ?? 0) + 1 }
    public var canUndo: Bool { !undoStack.isEmpty }

    public mutating func begin(at p: CGPoint, time: TimeInterval, settings: AnnotationSettings) {
        let isHighlighter = selectedTool == .highlighter
        let width = isHighlighter ? settings.highlighterSize : settings.strokeWidth
        let color = isHighlighter ? settings.highlighterColor.withAlpha(0.4) : self.color
        switch selectedTool {
        case .text:
            let a = Annotation(tool: .text, points: [p], color: color, width: settings.calloutSize, text: "", createdAt: time)
            commit(a); editingTextID = a.id
        case .callout:
            commit(Annotation(tool: .callout, points: [p], color: color, width: settings.calloutSize,
                              calloutNumber: nextCalloutNumber, createdAt: time))
        default:
            current = Annotation(tool: selectedTool, points: selectedTool.isTwoPoint ? [p, p] : [p],
                                 color: color, width: width, createdAt: time)
        }
    }

    public mutating func drag(to p: CGPoint) {
        guard var c = current else { return }
        if c.tool.isTwoPoint { c.points[1] = p } else if c.points.last != p { c.points.append(p) }
        current = c
    }

    public mutating func end() {
        guard let c = current else { return }
        current = nil
        // Ignore accidental clicks that produced no visible shape.
        let box = c.boundingBox
        if c.tool.isTwoPoint && max(box.width, box.height) < 2 { return }
        commit(c)
    }

    public mutating func setText(_ text: String, for id: UUID) {
        guard let i = annotations.firstIndex(where: { $0.id == id }) else { return }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            annotations.remove(at: i)
        } else {
            annotations[i].text = text
        }
        if editingTextID == id { editingTextID = nil }
    }

    public mutating func undo() {
        guard let previous = undoStack.popLast() else { return }
        annotations = previous
        current = nil
    }

    public mutating func clearAll() {
        guard !annotations.isEmpty else { return }
        undoStack.append(annotations)
        annotations.removeAll()
        current = nil
    }

    /// Removes annotations older than `delay` seconds. Returns true if anything changed.
    @discardableResult
    public mutating func removeExpired(now: TimeInterval, delay: TimeInterval) -> Bool {
        let before = annotations.count
        annotations.removeAll { now - $0.createdAt >= delay && $0.id != editingTextID }
        return annotations.count != before
    }

    private mutating func commit(_ a: Annotation) {
        undoStack.append(annotations)
        if undoStack.count > 100 { undoStack.removeFirst() }
        annotations.append(a)
    }
}

/// Geometry for an arrow head at `end` coming from `start`.
public enum ArrowGeometry {
    public static func head(from start: CGPoint, to end: CGPoint, width: Double) -> (CGPoint, CGPoint) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let length = max(12, width * 4)
        let spread = Double.pi / 7
        let a = CGPoint(x: end.x - length * cos(angle - spread), y: end.y - length * sin(angle - spread))
        let b = CGPoint(x: end.x - length * cos(angle + spread), y: end.y - length * sin(angle + spread))
        return (a, b)
    }
}
