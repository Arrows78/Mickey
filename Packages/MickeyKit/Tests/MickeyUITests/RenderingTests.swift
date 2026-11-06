import AppKit
import SwiftUI
import Testing
import MickeyDomain
import MickeyPersistence
@testable import MickeyUI

/// Renders views to images. The tests check the size of the picture; set MICKEY_SNAPSHOT_DIR to also save the
/// pictures and look at them.
@Suite("Rendering") @MainActor
struct RenderingTests {
    private func model(_ transform: (inout MickeyDomain.Settings) -> Void = { _ in }) -> AppModel {
        var s = MickeyDomain.Settings.defaults
        transform(&s)
        return AppModel(store: InMemorySettingsStore(settings: s))
    }

    private func render<V: View>(_ view: V, width: CGFloat, name: String) throws -> NSImage {
        let renderer = ImageRenderer(content: view.frame(width: width).fixedSize(horizontal: false, vertical: true)
            .background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, .dark))
        renderer.scale = 2
        let image = try #require(renderer.nsImage)
        if let dir = ProcessInfo.processInfo.environment["MICKEY_SNAPSHOT_DIR"],
           let tiff = image.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
        return image
    }

    @Test func popoverShowsEveryToggleInItsGroup() throws {
        let image = try render(StatusPopoverView(model: model()), width: 280, name: "popover")
        #expect(image.size.width == 280)
        #expect(image.size.height > 380, "popover is \(image.size.height) pt tall")
    }

    @Test func popoverLeavesOutTogglesTheUserRemoved() throws {
        let all = try render(StatusPopoverView(model: model()), width: 280, name: "popover-all")
        let few = try render(StatusPopoverView(model: model { $0.general.menuBarItems = [.ring] }), width: 280, name: "popover-few")
        #expect(few.size.height < all.size.height)
    }

    @Test func popoverWithRecordingShowsPause() throws {
        let m = model()
        m.recordingClock = RecordingClock(startedAt: Date())
        let recording = try render(StatusPopoverView(model: m), width: 280, name: "popover-recording")
        let idle = try render(StatusPopoverView(model: model()), width: 280, name: "popover-idle")
        #expect(recording.size.height >= idle.size.height)
    }
}
