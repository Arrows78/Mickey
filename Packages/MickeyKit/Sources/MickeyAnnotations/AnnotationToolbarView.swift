import SwiftUI
import MickeyDomain
import MickeyEffects

struct AnnotationToolbarView: View {
    let controller: AnnotationController

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AnnotationTool.allCases, id: \.self) { tool in
                Button { controller.select(tool) } label: {
                    Image(systemName: tool.symbolName)
                        .frame(width: 28, height: 28)
                        .background(controller.session.selectedTool == tool ? Color.accentColor.opacity(0.35) : .clear,
                                    in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("\(tool.title)\(tool.shortcutKey.map { " (\(String($0).uppercased()))" } ?? "")")
            }
            Divider().frame(height: 22)
            ForEach(RGBAColor.presets, id: \.self) { color in
                Button { controller.setColor(color) } label: {
                    Circle().fill(Color(nsColor: color.nsColor))
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(Color.white, lineWidth: controller.session.color == color ? 2 : 0.5))
                }
                .buttonStyle(.plain)
            }
            Divider().frame(height: 22)
            Button { controller.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .buttonStyle(.plain).help("Undo (⌘Z)").disabled(!controller.session.canUndo)
            Button { controller.clearAll() } label: { Image(systemName: "trash") }
                .buttonStyle(.plain).help("Clear All (⌘⌫)")
            Button { controller.exit() } label: { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.plain).help("Stop Drawing (Esc)")
        }
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.75), in: Capsule())
        .fixedSize()
    }
}
