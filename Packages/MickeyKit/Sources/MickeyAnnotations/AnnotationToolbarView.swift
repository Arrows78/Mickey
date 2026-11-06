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
                .accessibilityLabel(tool.title)
                .accessibilityAddTraits(controller.session.selectedTool == tool ? .isSelected : [])
            }
            Divider().frame(height: 22)
            ForEach(RGBAColor.presets, id: \.self) { color in
                Button { controller.setColor(color) } label: {
                    Circle().fill(Color(nsColor: color.nsColor))
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(Color.white, lineWidth: controller.session.color == color ? 2 : 0.5))
                }
                .buttonStyle(.plain)
                .help(color.presetName ?? "Color")
                .accessibilityLabel(color.presetName ?? "Color")
                .accessibilityAddTraits(controller.session.color == color ? .isSelected : [])
            }
            Divider().frame(height: 22)
            Image(systemName: "lineweight").help("Stroke Width").accessibilityHidden(true)
            Slider(value: Binding(get: { controller.settings.strokeWidth }, set: { controller.setStrokeWidth($0) }),
                   in: AnnotationSettings.strokeWidthRange)
                .frame(width: 80)
                .controlSize(.mini)
                .help("Stroke Width")
                .accessibilityLabel("Stroke Width")
            Divider().frame(height: 22)
            Button { controller.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .buttonStyle(.plain).help("Undo (⌘Z)").accessibilityLabel("Undo").disabled(!controller.session.canUndo)
            Button { controller.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .buttonStyle(.plain).help("Redo (⇧⌘Z)").accessibilityLabel("Redo").disabled(!controller.session.canRedo)
            Button { controller.clearAll() } label: { Image(systemName: "trash") }
                .buttonStyle(.plain).help("Clear All (⌘⌫)").accessibilityLabel("Clear All")
            Button { controller.exit() } label: { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.plain).help("Stop Drawing (Esc)").accessibilityLabel("Stop Drawing")
        }
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.75), in: Capsule())
        .fixedSize()
    }
}
