import AppKit
import SwiftUI
import Testing
import MickeyDomain
@testable import MickeyStudio

/// Draws every keystroke style. The tests check the size of the picture; set MICKEY_SNAPSHOT_DIR to also save the
/// pictures and look at them.
@Suite("Keystroke rendering") @MainActor
struct KeystrokeRenderingTests {
    private func render(_ label: String, style: KeystrokeStyle, fontSize: Double = 28) throws -> NSImage {
        let badge = KeystrokeBadge(label: label, style: style, accent: .blue, fontSize: fontSize)
        let renderer = ImageRenderer(content: badge.padding(20).background(Color(white: 0.5)))
        renderer.scale = 2
        let image = try #require(renderer.nsImage)
        if let dir = ProcessInfo.processInfo.environment["MICKEY_SNAPSHOT_DIR"],
           let tiff = image.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("keys-\(style.rawValue).png"))
        }
        return image
    }

    @Test(arguments: KeystrokeStyle.allCases) func everyStyleDrawsAShortcut(style: KeystrokeStyle) throws {
        let image = try render("⌘⇧T ×2", style: style)
        #expect(image.size.width > 60 && image.size.height > 30, "\(style) is \(image.size)")
    }

    @Test func keycapsIsWiderThanTheOtherStylesForSeveralKeys() throws {
        let caps = try render("⌘⇧T", style: .keycaps)
        let minimal = try render("⌘⇧T", style: .minimal)
        #expect(caps.size.width > minimal.size.width)
    }

    @Test func aBiggerTextMakesABiggerBadge() throws {
        let small = try render("⌘K", style: .classic, fontSize: 16)
        let big = try render("⌘K", style: .classic, fontSize: 48)
        #expect(big.size.width > small.size.width && big.size.height > small.size.height)
    }
}
