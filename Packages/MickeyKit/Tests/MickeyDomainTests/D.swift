import CoreGraphics
import Foundation
import Testing
@testable import MickeyDomain

@Suite("Defaults")
struct DefaultsTests {
    @Test func spotlightDefaults() {
        let s = Settings.defaults.spotlight
        #expect(!s.enabled)
        #expect(s.radius == 150 && s.spotOpacity == 1 && s.backgroundOpacity == 0.6)
        #expect(s.shape == .circle && s.barThickness == 60)
        #expect(!s.hideCursor && !s.dismissOnMove && s.dismissDistance == 40)
        #expect(s.holdKey == nil && s.holdDelay == 0.5)
    }

    @Test func effectDefaults() {
        let d = Settings.defaults
        #expect(d.general.masterEnabled && d.general.showInMenuBar && !d.general.showInDock)
        #expect(d.general.updateRateHz == 60)
        #expect(d.general.menuBarItems == Set(MenuBarItem.allCases))
        #expect(d.ring.radius == 50 && d.ring.thickness == 3 && d.ring.color == .blue && !d.ring.animated)
        #expect(d.click.showOnClicks && d.click.effectType == .singleRing && d.click.size == 100)
        #expect(d.click.soundVolume == 0.5 && d.click.tapKey == nil)
        #expect(d.trail.length == 30 && d.trail.width == 5 && d.trail.opacity == 0.8 && d.trail.spawnRate == 4)
        #expect(d.shake.enabled && d.shake.sensitivity == 0.95)
        #expect(d.hotkeys == HotkeyAction.defaultHotkeys)
    }

    @Test func annotationDefaults() {
        let a = Settings.defaults.annotations
        #expect(!a.enabled && !a.rightOptionTrigger && a.defaultTool == .freehand)
        #expect(a.color == .red && a.strokeWidth == 4 && a.highlighterColor == .yellow)
        #expect(a.highlighterSize == 32 && a.calloutSize == 26 && !a.autoFade && a.autoFadeDelay == 5 && !a.clearOnExit)
    }
}

@Suite("Rules")
struct RulesTests {
    @Test func enablingEffectTurnsMasterOn() {
        var old = Settings.defaults
        old.general.masterEnabled = false
        var new = old
        new.ring.enabled = true
        #expect(SettingsRules.normalize(old: old, new: new).general.masterEnabled)
    }

    @Test func disablingEffectDoesNotTouchMaster() {
        var old = Settings.defaults
        old.general.masterEnabled = false
        old.ring.enabled = true
        var new = old
        new.ring.enabled = false
        #expect(!SettingsRules.normalize(old: old, new: new).general.masterEnabled)
    }

    @Test func holdKeyAndDismissAreExclusive() {
        var old = Settings.defaults
        old.spotlight.dismissOnMove = true
        var new = old
        new.spotlight.holdKey = .rightOption
        let r = SettingsRules.normalize(old: old, new: new)
        #expect(r.spotlight.holdKey == .rightOption && !r.spotlight.dismissOnMove)

        var new2 = r
        new2.spotlight.dismissOnMove = true
        let r2 = SettingsRules.normalize(old: r, new: new2)
        #expect(r2.spotlight.holdKey == nil && r2.spotlight.dismissOnMove)
    }

    @Test func menuBarOrDockStaysOn() {
        let old = Settings.defaults
        var new = old
        new.general.showInMenuBar = false
        let r = SettingsRules.normalize(old: old, new: new)
        #expect(!r.general.showInMenuBar && r.general.showInDock)

        var new2 = r
        new2.general.showInDock = false
        let r2 = SettingsRules.normalize(old: r, new: new2)
        #expect(r2.general.showInMenuBar && !r2.general.showInDock)
    }

    @Test func hotkeyTogglesAndAutoEnables() {
        var s = Settings.defaults
        s.general.masterEnabled = false
        let r = SettingsRules.applying(.toggleSpotlight, to: s)
        #expect(r.spotlight.enabled && r.general.masterEnabled)
        #expect(!SettingsRules.applying(.toggleMaster, to: Settings.defaults).general.masterEnabled)
        #expect(SettingsRules.applying(.toggleAnnotationMode, to: Settings.defaults).annotations.enabled)
    }

    @Test func clampingKeepsValuesInRange() {
        var s = Settings.defaults
        s.spotlight.radius = 10_000
        s.trail.length = -3
        s.click.soundVolume = .nan
        let c = s.clamped()
        #expect(c.spotlight.radius == SpotlightSettings.radiusRange.upperBound)
        #expect(c.trail.length == TrailSettings.lengthRange.lowerBound)
        #expect(c.click.soundVolume == 0)
    }

    @Test func triggerNotes() {
        var s = Settings.defaults
        s.click.tapKey = .rightShift
        let notes = SettingsRules.triggerKeyNotes(for: .rightShift, role: .spotlightHold, settings: s)
        #expect(notes.count == 2)
        s.annotations.rightOptionTrigger = true
        #expect(SettingsRules.triggerKeyNotes(for: .rightOption, role: .clickTap, settings: s).count == 1)
        #expect(SettingsRules.triggerKeyNotes(for: nil, role: .clickTap, settings: s).isEmpty)
    }

    @Test func unreachableFeedback() {
        var c = ClickSettings()
        c.feedbackEnabled = true
        c.showOnClicks = false
        #expect(c.feedbackUnreachable(hasShowEffectHotkey: false))
        #expect(!c.feedbackUnreachable(hasShowEffectHotkey: true))
        c.tapKey = .leftControl
        #expect(!c.feedbackUnreachable(hasShowEffectHotkey: false))
    }
}

@Suite("KeyCombo")
struct KeyComboTests {
    @Test func validation() {
        #expect(KeyCombo(keyCode: 40, modifiers: [], keyLabel: "K").validate() == .needsModifier)
        #expect(KeyCombo(keyCode: 40, modifiers: .command, keyLabel: "K").validate() == .commandOnlyReserved)
        #expect(KeyCombo(keyCode: 40, modifiers: .shift, keyLabel: "K").validate() == .shiftOnly)
        #expect(KeyCombo(keyCode: 40, modifiers: [.command, .shift], keyLabel: "K").validate() == nil)
        #expect(KeyCombo(keyCode: 96, modifiers: [], keyLabel: "F5").validate() == nil)
        #expect(KeyCombo(keyCode: 40, modifiers: [.control, .option, .shift, .command], keyLabel: "K").displayString == "⌃⌥⇧⌘K")
    }
}

@Suite("Shake")
struct ShakeTests {
    /// Horizontal zig-zag of `amplitude` points, one sample every 16 ms.
    func zigzag(_ d: inout ShakeDetector, start: TimeInterval, steps: Int, amplitude: Double) -> Bool {
        var detected = false
        for i in 0..<steps {
            let x = 500 + (i % 2 == 0 ? amplitude : -amplitude)
            if d.add(PointerSample(CGPoint(x: x, y: 300 + Double(i % 3)), at: start + Double(i) * 0.016)) { detected = true }
        }
        return detected
    }

    @Test func thresholds() {
        let d = ShakeDetector(sensitivity: 0.95)
        #expect(abs(d.stepThreshold - 0.75) < 1e-9)
        #expect(d.requiredReversals == 3)
        #expect(ShakeDetector(sensitivity: 0.1).requiredReversals == 5)
    }

    @Test func zigzagIsDetected() {
        var d = ShakeDetector(sensitivity: 0.95)
        let v1 = zigzag(&d, start: 10, steps: 12, amplitude: 40)
        #expect(v1)
    }

    @Test func straightLineIsNotDetected() {
        var d = ShakeDetector(sensitivity: 0.95)
        var hit = false
        for i in 0..<30 where d.add(PointerSample(CGPoint(x: Double(i) * 6, y: 0), at: Double(i) * 0.016)) { hit = true }
        #expect(!hit)
    }

    @Test func largeTravelIsNotAShake() {
        var d = ShakeDetector(sensitivity: 0.95)
        var hit = false
        for i in 0..<20 {
            let x = 500 + (i % 2 == 0 ? 20.0 : -20.0)
            if d.add(PointerSample(CGPoint(x: x, y: Double(i) * 60), at: Double(i) * 0.016)) { hit = true }
        }
        #expect(!hit)
    }

    @Test func cooldownPreventsRetrigger() {
        var d = ShakeDetector(sensitivity: 0.95)
        let v2 = zigzag(&d, start: 10, steps: 12, amplitude: 40)
        #expect(v2)
        let v3 = !zigzag(&d, start: 10.5, steps: 12, amplitude: 40)
        #expect(v3)
        let v4 = zigzag(&d, start: 12.0, steps: 12, amplitude: 40)
        #expect(v4)
    }

    @Test func tinyJitterIgnoredAtLowSensitivity() {
        var d = ShakeDetector(sensitivity: 0.1)
        let v5 = !zigzag(&d, start: 0, steps: 20, amplitude: 1)
        #expect(v5)
    }
}

@Suite("Trail")
struct TrailTests {
    @Test func boundedLength() {
        var b = TrailBuffer()
        var s = TrailSettings()
        s.length = 10
        for i in 0..<50 { b.update(position: CGPoint(x: Double(i) * 10, y: 0), time: Double(i) * 0.01, settings: s) }
        #expect(b.points.count == 10)
        #expect(b.opacity(at: 9, time: 0.49, settings: s) > b.opacity(at: 0, time: 0.49, settings: s))
    }

    @Test func pointsExpire() {
        var b = TrailBuffer()
        let s = TrailSettings()
        b.update(position: .zero, time: 0, settings: s)
        b.update(position: CGPoint(x: 50, y: 0), time: 2, settings: s)
        #expect(b.points.count == 1)
    }

    @Test func discreteStylesRespectSpacing() {
        var b = TrailBuffer()
        var s = TrailSettings()
        s.style = .dots
        s.spawnRate = 5 // 20 px spacing
        for i in 0..<10 { b.update(position: CGPoint(x: Double(i) * 5, y: 0), time: Double(i) * 0.01, settings: s) }
        #expect(b.points.count == 3)
    }
}

@Suite("Recognizers")
struct RecognizerTests {
    @Test func loneShortPressIsTap() {
        var r = TapRecognizer()
        r.keyDown(at: 0)
        let v6 = r.keyUp(at: 0.1)
        #expect(v6)
    }

    @Test func longPressOrComboIsNotTap() {
        var r = TapRecognizer()
        r.keyDown(at: 0)
        let v7 = !r.keyUp(at: 1)
        #expect(v7)
        r.keyDown(at: 2)
        r.otherInput()
        let v8 = !r.keyUp(at: 2.1)
        #expect(v8)
        r.otherInput() // ignored while up
        r.keyDown(at: 3)
        let v9 = r.keyUp(at: 3.1)
        #expect(v9)
    }

    @Test func holdBeginsAfterDelay() {
        var h = HoldRecognizer(delay: 0.5)
        let v10 = h.update(isDown: true, at: 0) == nil
        #expect(v10)
        let v11 = h.update(isDown: true, at: 0.4) == nil
        #expect(v11)
        let v12 = h.update(isDown: true, at: 0.5) == .began
        #expect(v12)
        let v13 = h.update(isDown: true, at: 0.6) == nil
        #expect(v13)
        let v14 = h.update(isDown: false, at: 0.7) == .ended
        #expect(v14)
        let v15 = h.update(isDown: false, at: 0.8) == nil
        #expect(v15)
    }

    @Test func shortHoldNeverBegins() {
        var h = HoldRecognizer(delay: 0.5)
        _ = h.update(isDown: true, at: 0)
        let v16 = h.update(isDown: false, at: 0.2) == nil
        #expect(v16)
    }

    @Test func dismissAfterMovingAway() {
        var t = SpotlightDismissTracker()
        t.arm(at: .zero, time: 0)
        let v17 = !t.shouldDismiss(position: CGPoint(x: 100, y: 0), time: 0.1, distance: 40)
        #expect(v17)
        let v18 = !t.shouldDismiss(position: CGPoint(x: 120, y: 0), time: 0.3, distance: 40)
        #expect(v18)
        let v19 = t.shouldDismiss(position: CGPoint(x: 150, y: 0), time: 0.4, distance: 40)
        #expect(v19)
        #expect(!t.isArmed)
    }
}

@Suite("Annotations")
struct AnnotationTests {
    let settings = AnnotationSettings()

    @Test func freehandStrokeAndUndo() {
        var s = AnnotationSession(tool: .freehand, color: .red)
        s.begin(at: .zero, time: 0, settings: settings)
        s.drag(to: CGPoint(x: 10, y: 10))
        s.drag(to: CGPoint(x: 20, y: 5))
        s.end()
        #expect(s.annotations.count == 1 && s.annotations[0].points.count == 3)
        s.undo()
        #expect(s.annotations.isEmpty)
    }

    @Test func twoPointShapesKeepEndpoints() {
        var s = AnnotationSession(tool: .arrow, color: .red)
        s.begin(at: .zero, time: 0, settings: settings)
        s.drag(to: CGPoint(x: 5, y: 5))
        s.drag(to: CGPoint(x: 50, y: 40))
        s.end()
        #expect(s.annotations[0].points == [.zero, CGPoint(x: 50, y: 40)])
    }

    @Test func clickWithoutDragIsDiscarded() {
        var s = AnnotationSession(tool: .rectangle, color: .red)
        s.begin(at: .zero, time: 0, settings: settings)
        s.end()
        #expect(s.annotations.isEmpty)
    }

    @Test func calloutsAreNumbered() {
        var s = AnnotationSession(tool: .callout, color: .red)
        for i in 0..<3 { s.begin(at: CGPoint(x: Double(i) * 50, y: 0), time: 0, settings: settings) }
        #expect(s.annotations.compactMap(\.calloutNumber) == [1, 2, 3])
    }

    @Test func emptyTextIsRemoved() {
        var s = AnnotationSession(tool: .text, color: .red)
        s.begin(at: .zero, time: 0, settings: settings)
        let id = try! #require(s.editingTextID)
        s.setText("  ", for: id)
        #expect(s.annotations.isEmpty && s.editingTextID == nil)
    }

    @Test func clearAllIsUndoable() {
        var s = AnnotationSession(tool: .callout, color: .red)
        s.begin(at: .zero, time: 0, settings: settings)
        s.clearAll()
        #expect(s.annotations.isEmpty)
        s.undo()
        #expect(s.annotations.count == 1)
    }

    @Test func highlighterUsesItsOwnColorAndSize() {
        var s = AnnotationSession(tool: .highlighter, color: .red)
        s.begin(at: .zero, time: 0, settings: settings)
        s.drag(to: CGPoint(x: 30, y: 0))
        s.end()
        #expect(s.annotations[0].width == 32 && s.annotations[0].color == RGBAColor.yellow.withAlpha(0.4))
    }

    @Test func autoFadeRemovesOldAnnotations() {
        var s = AnnotationSession(tool: .callout, color: .red)
        s.begin(at: .zero, time: 0, settings: settings)
        s.begin(at: CGPoint(x: 9, y: 9), time: 4, settings: settings)
        let v20 = s.removeExpired(now: 5, delay: 5)
        #expect(v20)
        #expect(s.annotations.count == 1)
    }

    @Test func toolShortcuts() {
        #expect(AnnotationTool.forShortcut("F") == .freehand)
        #expect(AnnotationTool.forShortcut("l") == .line)
        #expect(AnnotationTool.forShortcut("z") == nil)
    }
}

@Suite("Review")
struct ReviewTests {
    func context(_ mutate: (inout ReviewPolicy.Context) -> Void = { _ in }) -> ReviewPolicy.Context {
        var st = ReviewState()
        st.launchCount = 10
        st.activeMinutes = 100
        var c = ReviewPolicy.Context(state: st, sessionMinutes: 10, onboardingComplete: true, settingsWindowFrontmost: true,
                                     spotlightVisible: false, drawing: false, askedThisSession: false, now: Date())
        mutate(&c)
        return c
    }

    @Test func eligible() { #expect(ReviewPolicy().blockers(context()).isEmpty) }

    @Test func blockers() {
        let p = ReviewPolicy()
        let fewLaunches = context { $0.state.launchCount = 1 }
        let drawing = context { $0.drawing = true }
        let spotlight = context { $0.spotlightVisible = true }
        let recent = context { $0.state.lastRequest = $0.now.addingTimeInterval(-3600) }
        let noOnboarding = context { $0.onboardingComplete = false }
        #expect(p.blockers(fewLaunches) == [.notQualified])
        #expect(p.blockers(drawing) == [.drawingInProgress])
        #expect(p.blockers(spotlight) == [.spotlightOnScreen])
        #expect(p.blockers(recent) == [.askedRecently])
        #expect(p.blockers(noOnboarding) == [.onboardingIncomplete])
    }
}

@Suite("Geometry")
struct GeometryTests {
    @Test func spotlightHoles() {
        var s = SpotlightSettings()
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let c = CGPoint(x: 300, y: 200)
        let circle = SpotlightHole.make(center: c, in: screen, settings: s)
        #expect(circle.rect == CGRect(x: 150, y: 50, width: 300, height: 300))
        #expect(circle.contains(c) && !circle.contains(CGPoint(x: 460, y: 200)))
        s.shape = .horizontalBar
        #expect(SpotlightHole.make(center: c, in: screen, settings: s).rect == CGRect(x: 0, y: 170, width: 1000, height: 60))
        s.shape = .verticalBar
        #expect(SpotlightHole.make(center: c, in: screen, settings: s).rect == CGRect(x: 270, y: 0, width: 60, height: 800))
    }

    @Test func timings() {
        #expect(ClickEffectTiming.duration(type: .singleRing, speed: 2) == 0.25)
        #expect(ClickEffectTiming.ringCount(.ripple) == 3)
        #expect(LocatorAnimation.radius(progress: 0) == LocatorAnimation.startRadius)
        #expect(LocatorAnimation.radius(progress: 1) == LocatorAnimation.endRadius)
    }
}

@Suite("Interaction")
struct InteractionTests {
    let rightOption = TriggerKey.rightOption.deviceFlagMask | 0x0008_0000
    func snap(_ flags: UInt64 = 0, x: Double = 100, at t: TimeInterval, other: Bool = false) -> InputSnapshot {
        InputSnapshot(position: CGPoint(x: x, y: 100), flags: flags, otherKeyDown: other, time: t)
    }

    @Test func clickProducesEffectAndSound() {
        var e = InteractionEngine()
        var s = Settings.defaults
        s.click.feedbackEnabled = true
        s.click.soundEnabled = true
        #expect(e.mouseDown(at: .zero, settings: s) == [.clickEffect(.zero), .clickSound])
        s.click.showOnClicks = false
        #expect(e.mouseDown(at: .zero, settings: s) == [.clickSound])
        s.general.masterEnabled = false
        #expect(e.mouseDown(at: .zero, settings: s).isEmpty)
    }

    @Test func spotlightHoldKey() {
        var e = InteractionEngine()
        var s = Settings.defaults
        s.spotlight.enabled = true
        s.spotlight.holdKey = .rightOption
        _ = e.tick(snap(at: 0), settings: s)
        #expect(!e.spotlightVisible(s))
        _ = e.tick(snap(rightOption, at: 0.1), settings: s)
        _ = e.tick(snap(rightOption, at: 0.7), settings: s)
        #expect(e.spotlightVisible(s))
        _ = e.tick(snap(at: 0.8), settings: s)
        #expect(!e.spotlightVisible(s))
    }

    @Test func spotlightWithoutHoldKeyIsAlwaysVisible() {
        var s = Settings.defaults
        s.spotlight.enabled = true
        #expect(InteractionEngine().spotlightVisible(s))
        s.spotlight.hideCursor = true
        #expect(InteractionEngine().shouldHideCursor(s))
    }

    @Test func tapKeyFlashesEffect() {
        var e = InteractionEngine()
        var s = Settings.defaults
        s.click.feedbackEnabled = true
        s.click.tapKey = .rightOption
        _ = e.tick(snap(at: 0), settings: s)
        _ = e.tick(snap(rightOption, at: 0.05), settings: s)
        let up = e.tick(snap(at: 0.15), settings: s)
        #expect(up == [.clickEffect(CGPoint(x: 100, y: 100))])
    }

    @Test func tapCancelledByClickOrLongHold() {
        var e = InteractionEngine()
        var s = Settings.defaults
        s.click.feedbackEnabled = true
        s.click.tapKey = .rightOption
        _ = e.tick(snap(rightOption, at: 0), settings: s)
        _ = e.mouseDown(at: .zero, settings: s)
        let afterClick = e.tick(snap(at: 0.1), settings: s)
        #expect(afterClick.isEmpty)
        _ = e.tick(snap(rightOption, at: 1), settings: s)
        let afterLong = e.tick(snap(at: 2), settings: s)
        #expect(afterLong.isEmpty)
    }

    @Test func fnHoldDraws() {
        var e = InteractionEngine()
        var s = Settings.defaults
        s.annotations.enabled = true
        let fn = InputSnapshot.secondaryFnMask
        #expect(e.tick(snap(fn, at: 0), settings: s).isEmpty)
        #expect(e.tick(snap(fn, at: 0.3), settings: s) == [.beginMomentaryDrawing])
        #expect(e.tick(snap(at: 0.5), settings: s) == [.endMomentaryDrawing])
        s.annotations.enabled = false
        _ = e.tick(snap(fn, at: 1), settings: s)
        #expect(e.tick(snap(fn, at: 2), settings: s).isEmpty)
    }

    @Test func rightOptionDrawsOnlyWhenEnabled() {
        var e = InteractionEngine()
        var s = Settings.defaults
        s.annotations.enabled = true
        _ = e.tick(snap(rightOption, at: 0), settings: s)
        #expect(e.tick(snap(rightOption, at: 0.5), settings: s).isEmpty)
        s.annotations.rightOptionTrigger = true
        _ = e.tick(snap(at: 0.6), settings: s)
        _ = e.tick(snap(rightOption, at: 0.7), settings: s)
        #expect(e.tick(snap(rightOption, at: 1.0), settings: s) == [.beginMomentaryDrawing])
    }

    @Test func dismissOnMove() {
        var e = InteractionEngine()
        var s = Settings.defaults
        s.spotlight.dismissOnMove = true
        _ = e.tick(snap(x: 0, at: 0), settings: s)
        s.spotlight.enabled = true
        _ = e.tick(snap(x: 0, at: 1), settings: s)
        _ = e.tick(snap(x: 10, at: 1.3), settings: s)
        let far = e.tick(snap(x: 200, at: 1.4), settings: s)
        #expect(far.contains(.disableSpotlight))
    }

    @Test func shakeLocates() {
        var e = InteractionEngine()
        let s = Settings.defaults
        var located = false
        for i in 0..<12 {
            let out = e.tick(snap(x: 500 + (i % 2 == 0 ? 40 : -40), at: Double(i) * 0.016), settings: s)
            if out.contains(where: { if case .locate = $0 { true } else { false } }) { located = true }
        }
        #expect(located)
    }

    @Test func showClickEffectUsesLastPosition() {
        var e = InteractionEngine()
        _ = e.tick(snap(x: 42, at: 0), settings: .defaults)
        #expect(e.showClickEffect(settings: .defaults) == [.clickEffect(CGPoint(x: 42, y: 100))])
    }
}

@Suite("Default hotkeys") struct DefaultHotkeyTests {
    @Test func everyActionHasAUniqueValidDefault() {
        let combos = HotkeyAction.allCases.map(\.defaultHotkey)
        #expect(Set(combos).count == HotkeyAction.allCases.count)
        #expect(combos.allSatisfy { $0.validate() == nil })
    }
}

@Suite("Presenter tools") struct StudioLogicTests {
    @Test func keystrokesHidePlainTypingInShortcutsOnlyMode() {
        #expect(KeystrokeFormatter.format(flags: 0, keyCode: 0, characters: "a", shortcutsOnly: true) == nil)
        #expect(KeystrokeFormatter.format(flags: 0x0002_0000, keyCode: 0, characters: "A", shortcutsOnly: true) == nil)
        #expect(KeystrokeFormatter.format(flags: 0, keyCode: 49, characters: " ", shortcutsOnly: true) == nil)
        #expect(KeystrokeFormatter.format(flags: 0x0010_0000 | 0x0002_0000, keyCode: 6, characters: "z", shortcutsOnly: true) == "⇧⌘Z")
        #expect(KeystrokeFormatter.format(flags: 0, keyCode: 53, characters: "\u{1b}", shortcutsOnly: true) == "⎋")
        #expect(KeystrokeFormatter.format(flags: 0, keyCode: 0, characters: "a", shortcutsOnly: false) == "A")
        #expect(KeystrokeFormatter.format(flags: 0x0004_0000 | 0x0008_0000 | 0x0010_0000, keyCode: 40, characters: "k", shortcutsOnly: true) == "⌃⌥⌘K")
    }

    @Test func keystrokeRepeatsCollapse() {
        var h = KeystrokeHistory()
        h.add("⌘Z", at: 0); h.add("⌘Z", at: 0.4); h.add("⌘Z", at: 0.8)
        #expect(h.entries.count == 1)
        #expect(h.entries[0].label == "⌘Z ×3")
        h.add("⌘Z", at: 3)
        #expect(h.entries.count == 2)
        for i in 0..<6 { h.add("⌘\(i)", at: 4) }
        #expect(h.entries.count == h.maxEntries)
        let changed = h.expire(now: 10, duration: 1.5)
        #expect(changed)
        #expect(h.entries.isEmpty)
    }

    @Test func zoomKeepsThePointerFixed() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        for p in [CGPoint(x: 0, y: 0), CGPoint(x: 500, y: 400), CGPoint(x: 1000, y: 800), CGPoint(x: 250, y: 700)] {
            let src = MagnifierGeometry.zoomSource(pointer: p, screen: screen, factor: 2)
            #expect(src.width == 500 && src.height == 400)
            #expect(screen.contains(src.insetBy(dx: 0.001, dy: 0.001)))
            // The pointer's point in the source maps back onto the pointer once magnified.
            let mapped = CGPoint(x: (p.x - src.minX) * 2, y: (p.y - src.minY) * 2)
            #expect(abs(mapped.x - p.x) < 0.001 && abs(mapped.y - p.y) < 0.001)
        }
        let frame = MagnifierGeometry.imageFrame(source: CGRect(x: 250, y: 200, width: 500, height: 400), screen: screen,
                                                  viewSize: CGSize(width: 1000, height: 800))
        #expect(frame == CGRect(x: -500, y: -400, width: 2000, height: 1600))
    }

    @Test func focusPicksTheFrontmostAppsTopWindow() {
        let windows = [
            WindowInfo(pid: 9, layer: 25, bounds: CGRect(x: 0, y: 0, width: 300, height: 24)),
            WindowInfo(pid: 5, layer: 0, bounds: CGRect(x: 10, y: 10, width: 20, height: 20)),
            WindowInfo(pid: 5, layer: 0, bounds: CGRect(x: 100, y: 50, width: 400, height: 300)),
            WindowInfo(pid: 7, layer: 0, bounds: CGRect(x: 0, y: 0, width: 800, height: 600)),
        ]
        #expect(FocusSelector.focusRect(windows: windows, frontmostPID: 5, primaryScreenHeight: 1000)
                == CGRect(x: 100, y: 650, width: 400, height: 300))
        #expect(FocusSelector.focusRect(windows: windows, frontmostPID: 42, primaryScreenHeight: 1000) == nil)
    }

    @Test func captionsKeepTheEndAtAWordBoundary() {
        #expect(CaptionText.tail(of: "hello world", maxChars: 40) == "hello world")
        #expect(CaptionText.tail(of: "one two three four", maxChars: 10) == "four")
        #expect(CaptionText.tail(of: "  spaced  ", maxChars: 20) == "spaced")
    }

    @Test func recordingNamesAndElapsedTime() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let date = cal.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 9, minute: 5, second: 7))!
        #expect(RecordingNaming.fileName(for: date, calendar: cal) == "Mickey Recording 2026-11-01 at 09.05.07.mov")
        #expect(RecordingNaming.elapsed(65) == "1:05")
        #expect(RecordingNaming.elapsed(3725) == "1:02:05")
    }

    @Test func presetsTurnMickeyOnAndKeepAppearance() {
        var s = Settings(); s.general.masterEnabled = false; s.ring.color = .red
        let p = Preset.presentation.apply(to: s)
        #expect(p.general.masterEnabled && p.ring.enabled && p.click.feedbackEnabled)
        #expect(p.spotlight.holdKey != nil && !p.spotlight.dismissOnMove)
        #expect(p.ring.color == .red)
        let d = Preset.discreet.apply(to: s)
        #expect(!d.click.showOnClicks && d.click.tapKey != nil && !d.ring.enabled)
        #expect(Preset.tutorial.apply(to: s).keystrokes.enabled)
    }

    @Test func autoModeWatchesApps() {
        #expect(AutoModeRule.shouldActivate(running: ["us.zoom.xos", "x"], watched: AutoModeSettings.defaultBundleIDs))
        #expect(!AutoModeRule.shouldActivate(running: ["com.apple.Safari"], watched: AutoModeSettings.defaultBundleIDs))
    }

    @Test func newActionsHaveUniqueDefaults() {
        let combos = HotkeyAction.allCases.map(\.defaultHotkey)
        #expect(Set(combos).count == combos.count)
        #expect(HotkeyAction.toggleRecording.introducedInSchema == 3)
    }

    @Test func presenterToolsIgnoreTheMasterSwitch() {
        var s = Settings(); s.general.masterEnabled = false
        let n = SettingsRules.applying(.toggleLoupe, to: s)
        #expect(n.loupe.enabled && !n.general.masterEnabled)
    }
}
