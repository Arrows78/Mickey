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

    @Test func fnDoesNotDrawWhenTurnedOff() {
        var e = InteractionEngine()
        var s = Settings.defaults
        s.annotations.enabled = true
        s.annotations.fnTrigger = false
        let fn = InputSnapshot.secondaryFnMask
        _ = e.tick(snap(fn, at: 0), settings: s)
        #expect(e.tick(snap(fn, at: 0.5), settings: s).isEmpty)
        #expect(e.tick(snap(fn, at: 2), settings: s).isEmpty)
    }

    @Test func turningFnOffMidHoldEndsTheDrawing() {
        var e = InteractionEngine()
        var s = Settings.defaults
        s.annotations.enabled = true
        let fn = InputSnapshot.secondaryFnMask
        _ = e.tick(snap(fn, at: 0), settings: s)
        #expect(e.tick(snap(fn, at: 0.3), settings: s) == [.beginMomentaryDrawing])
        s.annotations.fnTrigger = false
        #expect(e.tick(snap(fn, at: 0.5), settings: s) == [.endMomentaryDrawing])
    }

    @Test func fnDrawsByDefault() {
        #expect(AnnotationSettings().fnTrigger)
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
        #expect(HotkeyAction.togglePauseRecording.introducedInSchema == 5)
        #expect(HotkeyAction.togglePauseRecording.defaultLetter == "P")
    }

    @Test func presenterToolTurnsMasterOn() {
        var s = Settings(); s.general.masterEnabled = false
        let n = SettingsRules.applying(.toggleLiveZoom, to: s)
        #expect(n.zoom.enabled && n.general.masterEnabled)
    }

    @Test func masterOffHidesPresenterToolsButKeepsTheirSwitches() {
        var s = Settings(); s.zoom.enabled = true; s.loupe.enabled = true; s.focus.enabled = true
        s.keystrokes.enabled = true; s.camera.enabled = true; s.captions.enabled = true
        #expect(SettingsRules.presenterTools(of: s) == s)
        let off = SettingsRules.applying(.toggleMaster, to: s)
        #expect(off.zoom.enabled && !off.general.masterEnabled)
        let shown = SettingsRules.presenterTools(of: off)
        #expect(!shown.zoom.enabled && !shown.loupe.enabled && !shown.focus.enabled)
        #expect(!shown.keystrokes.enabled && !shown.camera.enabled && !shown.captions.enabled)
    }
}

@Suite("Hold-to-draw triggers") struct HoldToDrawTests {
    let fn = InputSnapshot.secondaryFnMask
    func snap(_ flags: UInt64 = 0, at t: TimeInterval, other: Bool = false) -> InputSnapshot {
        InputSnapshot(position: .zero, flags: flags, otherKeyDown: other, time: t)
    }

    @Test func toolShortcutWhileHoldingFnKeepsDrawing() {
        var e = InteractionEngine()
        var s = Settings.defaults
        s.annotations.enabled = true
        _ = e.tick(snap(fn, at: 0), settings: s)
        #expect(e.tick(snap(fn, at: 0.3), settings: s) == [.beginMomentaryDrawing])
        #expect(e.tick(snap(fn, at: 0.5, other: true), settings: s).isEmpty)
        #expect(e.tick(snap(at: 0.6, other: true), settings: s) == [.endMomentaryDrawing])
    }

    @Test func fnNeverDrawsWhileMickeyIsOff() {
        var e = InteractionEngine()
        var s = Settings.defaults
        s.annotations.enabled = true
        s.general.masterEnabled = false
        _ = e.tick(snap(fn, at: 0), settings: s)
        #expect(e.tick(snap(fn, at: 1), settings: s).isEmpty)
        s.general.masterEnabled = true
        _ = e.tick(snap(fn, at: 1.1), settings: s)
        #expect(e.tick(snap(fn, at: 1.5), settings: s) == [.beginMomentaryDrawing])
        s.general.masterEnabled = false
        #expect(e.tick(snap(fn, at: 1.6), settings: s) == [.endMomentaryDrawing])
    }

    @Test func fnFlagFromArrowKeysIsIgnored() {
        var f = FnKeyFilter()
        // ↓ held: the flag appears with a key-down and stays while the key repeats.
        #expect(f.filter(fn, keyDownIsLatest: true) == 0)
        #expect(f.filter(fn, keyDownIsLatest: true) == 0)
        #expect(f.filter(fn, keyDownIsLatest: false) == 0)
        #expect(f.filter(0, keyDownIsLatest: true) == 0)
        // A real Fn press is a modifier change, and a later tool key does not undo it.
        #expect(f.filter(fn, keyDownIsLatest: false) == fn)
        #expect(f.filter(fn, keyDownIsLatest: true) == fn)
    }

    @Test func triggerKeyIsNotAloneWithOtherModifiers() {
        var e = InteractionEngine()
        var s = Settings.defaults
        s.spotlight.enabled = true
        s.spotlight.holdKey = .leftControl
        // Left ⌃ + left ⌥ + left ⌘ held, as while typing a ⌃⌥⌘ hotkey.
        let combo: UInt64 = 0x0004_0000 | 0x0008_0000 | 0x0010_0000 | 0x01 | 0x20 | 0x08
        for i in 0...10 { _ = e.tick(snap(combo, at: Double(i) * 0.1), settings: s) }
        #expect(!e.spotlightVisible(s))
        let control: UInt64 = 0x0004_0000 | 0x01
        _ = e.tick(snap(at: 2), settings: s)
        _ = e.tick(snap(control, at: 2.1), settings: s)
        _ = e.tick(snap(control, at: 2.7), settings: s)
        #expect(e.spotlightVisible(s))
    }

    @Test func annotationHotkeyTurnsMickeyOn() {
        var s = Settings.defaults
        s.annotations.enabled = true
        s.general.masterEnabled = false
        #expect(SettingsRules.applying(.toggleAnnotationMode, to: s).general.masterEnabled)
    }
}

@Suite("Layout-aware hotkeys") struct LayoutHotkeyTests {
    /// French AZERTY: A↔Q and Z↔W swapped, M on the US ";" key.
    let azerty: (Character) -> UInt32? = { c in
        let codes: [Character: UInt32] = ["a": 12, "q": 0, "z": 13, "w": 6, "m": 41, ",": 46]
        return codes[c] ?? HotkeyAction.allCases.first { Character($0.defaultLetter.lowercased()) == c }?.defaultHotkey.keyCode
    }

    @Test func comboIdentityIgnoresLabel() {
        let a = KeyCombo(keyCode: 0, modifiers: [.control, .option, .command], keyLabel: "A")
        let q = KeyCombo(keyCode: 0, modifiers: [.control, .option, .command], keyLabel: "Q")
        #expect(a == q)
        #expect(Set([a, q]).count == 1)
        #expect(q.displayString(keyName: "Z") == "⌃⌥⌘Z")
    }

    @Test func optionOnlyIsRefused() {
        #expect(KeyCombo(keyCode: 40, modifiers: .option, keyLabel: "K").validate() == .optionOnly)
        #expect(KeyCombo(keyCode: 40, modifiers: [.option, .shift], keyLabel: "K").validate() == .optionOnly)
        #expect(KeyCombo(keyCode: 40, modifiers: [.option, .command], keyLabel: "K").validate() == nil)
        #expect(KeyCombo(keyCode: 40, modifiers: .control, keyLabel: "K").validate() == nil)
    }

    @Test func defaultsFollowTheLayout() {
        let d = HotkeyAction.defaultHotkeys(keyCode: azerty)
        #expect(d[.toggleMaster]?.keyCode == 41)
        #expect(d[.toggleCaptions]?.keyCode == 12)
        #expect(d[.toggleLiveZoom]?.keyCode == 13)
        #expect(d[.toggleFocus]?.keyCode == 6)
        #expect(d[.toggleSpotlight] == HotkeyAction.toggleSpotlight.defaultHotkey)
        #expect(Set(d.values).count == HotkeyAction.allCases.count)
    }

    @Test func localizingKeepsCustomShortcuts() {
        var s = Settings.defaults
        let custom = KeyCombo(keyCode: 12, modifiers: [.control, .option, .command], keyLabel: "A")
        s.hotkeys[.toggleRing] = custom // the user put Ring on the AZERTY A key
        let l = s.localizingDefaultHotkeys(keyCode: azerty)
        #expect(l.hotkeys[.toggleRing] == custom)
        #expect(l.hotkeys[.toggleCaptions] == HotkeyAction.toggleCaptions.defaultHotkey) // its key is taken: left as it was
        #expect(l.hotkeys[.toggleFocus]?.keyCode == 6)
        #expect(l.hotkeys[.toggleLiveZoom]?.keyCode == 13)
    }

    @Test func annotationsRowShowsNoToggleHotkey() {
        #expect(MenuBarItem.annotations.hotkeyAction == nil)
        #expect(MenuBarItem.ring.hotkeyAction == .toggleRing)
    }
}

@Suite("Automatic Mode") struct AutoModeSessionTests {
    let zoom: Set<String> = ["us.zoom.xos"]
    var base: Settings {
        var s = Settings.defaults
        s.autoMode.enabled = true
        s.ring.enabled = false
        return s
    }

    @Test func restoresWhenTheAppQuits() throws {
        var session = AutoModeSession()
        let appliedStep = session.update(settings: base, running: zoom)
        let applied = try #require(appliedStep)
        #expect(applied.ring.enabled)
        #expect(session.update(settings: applied, running: []) == base)
    }

    @Test func turningAutoModeOffRestoresAndKeepsItOff() throws {
        var session = AutoModeSession()
        let sStep = session.update(settings: base, running: zoom)
        var s = try #require(sStep)
        s.autoMode.enabled = false
        let restoredStep = session.update(settings: s, running: zoom)
        let restored = try #require(restoredStep)
        #expect(!restored.ring.enabled && !restored.autoMode.enabled)
    }

    @Test func changingThePresetReappliesIt() throws {
        var session = AutoModeSession()
        let sStep = session.update(settings: base, running: zoom)
        var s = try #require(sStep)
        s.autoMode.preset = .discreet
        let nextStep = session.update(settings: s, running: zoom)
        let next = try #require(nextStep)
        #expect(!next.ring.enabled && next.autoMode.preset == .discreet)
        #expect(session.update(settings: next, running: []) == { var b = base; b.autoMode.preset = .discreet; return b }())
    }

    @Test func userChangesAreKept() throws {
        var session = AutoModeSession()
        let sStep = session.update(settings: base, running: zoom)
        var s = try #require(sStep)
        s.trail.enabled = true
        #expect(session.settingsToPersist(s) == s)
        #expect(session.update(settings: s, running: []) == nil)
    }

    @Test func presetIsNotSavedAsTheUsersSettings() throws {
        var session = AutoModeSession()
        let appliedStep = session.update(settings: base, running: zoom)
        let applied = try #require(appliedStep)
        #expect(session.settingsToPersist(applied) == base)
    }
}

@Suite("Reduced motion") struct ReducedMotionTests {
    @Test func scaleIsUntouchedByDefault() {
        let s = ReducedMotion.scale(from: 0.2, to: 1, reduced: false)
        #expect(s.from == 0.2 && s.to == 1)
    }

    @Test func reducedMotionHoldsTheEndScale() {
        let s = ReducedMotion.scale(from: 0.2, to: 1.15, reduced: true)
        #expect(s.from == 1.15 && s.to == 1.15)
    }
}

@Suite("Annotation redo") struct AnnotationRedoTests {
    private func session() -> AnnotationSession {
        var s = AnnotationSession(tool: .freehand, color: .red)
        for x in [0.0, 50] {
            s.begin(at: CGPoint(x: x, y: 0), time: 0, settings: AnnotationSettings())
            s.drag(to: CGPoint(x: x + 20, y: 20))
            s.end()
        }
        return s
    }

    @Test func redoRestoresWhatUndoRemoved() {
        var s = session()
        s.undo()
        #expect(s.annotations.count == 1 && s.canRedo)
        s.redo()
        #expect(s.annotations.count == 2 && !s.canRedo)
    }

    @Test func drawingAfterUndoDropsTheRedoHistory() {
        var s = session()
        s.undo()
        s.begin(at: CGPoint(x: 90, y: 0), time: 1, settings: AnnotationSettings())
        s.drag(to: CGPoint(x: 120, y: 30))
        s.end()
        #expect(!s.canRedo)
        s.redo()
        #expect(s.annotations.count == 2)
    }

    @Test func clearAllCanBeUndoneAndRedone() {
        var s = session()
        s.clearAll()
        s.undo()
        #expect(s.annotations.count == 2)
        s.redo()
        #expect(s.annotations.isEmpty)
    }

    @Test func redoWithNothingToRedoChangesNothing() {
        var s = session()
        s.redo()
        #expect(s.annotations.count == 2)
    }
}

@Suite("Recorder options") struct RecorderOptionsTests {
    @Test func wideScreensAreScaledDownToTheQualityWidth() {
        let size = RecordingQuality.hd.outputSize(width: 3024, height: 1964)
        #expect(size.width == 1920)
        #expect(size.height == 1247 / 2 * 2)
    }

    @Test func smallScreensAreNeverScaledUp() {
        let size = RecordingQuality.uhd.outputSize(width: 1440, height: 900)
        #expect(size.width == 1440 && size.height == 900)
    }

    @Test func dimensionsStayEven() {
        let size = RecordingQuality.qhd.outputSize(width: 3441, height: 1441)
        #expect(size.width % 2 == 0 && size.height % 2 == 0)
    }

    @Test func defaultsKeepTheFormerBehavior() {
        let r = RecorderSettings()
        #expect(r.quality == .uhd && r.frameRate == 60)
    }

    @Test func unsupportedFrameRateIsRepaired() {
        var s = Settings.defaults
        s.recorder.frameRate = 24
        #expect(s.clamped().recorder.frameRate == 60)
    }
}

@Suite("Automatic Mode per app") struct AutoModePerAppTests {
    let zoom = "us.zoom.xos", keynote = "com.apple.Keynote"
    var base: Settings {
        var s = Settings.defaults
        s.autoMode.enabled = true
        s.autoMode.preset = .presentation
        s.autoMode.appPresets = ["com.apple.Keynote": .discreet]
        return s
    }

    @Test func anAppWithoutOverrideUsesTheDefaultPreset() {
        #expect(AutoModeRule.preset(running: [zoom], settings: base.autoMode) == .presentation)
    }

    @Test func anAppWithOverrideUsesItsOwnPreset() {
        #expect(AutoModeRule.preset(running: [keynote], settings: base.autoMode) == .discreet)
    }

    @Test func theFirstWatchedAppDecides() {
        #expect(AutoModeRule.preset(running: [zoom, keynote], settings: base.autoMode) == .presentation)
    }

    @Test func nothingRunningFallsBackToTheDefault() {
        #expect(AutoModeRule.preset(running: [], settings: base.autoMode) == .presentation)
    }

    @Test func switchingAppSwitchesPresetAndRestoresAtTheEnd() throws {
        var session = AutoModeSession()
        let firstStep = session.update(settings: base, running: [zoom])
        let first = try #require(firstStep)
        #expect(first.ring.enabled)
        let secondStep = session.update(settings: first, running: [keynote])
        let second = try #require(secondStep)
        #expect(!second.ring.enabled)
        #expect(session.update(settings: second, running: []) == base)
    }

    @Test func sameWantedPresetDoesNotReapply() throws {
        var session = AutoModeSession()
        let firstStep = session.update(settings: base, running: [zoom])
        let first = try #require(firstStep)
        #expect(session.update(settings: first, running: [zoom, "com.apple.FaceTime"]) == nil)
    }
}

@Suite("Localization") struct LocalizationTests {
    @Test func aTextWithoutTranslationIsShownAsIs() {
        #expect(tr("A text nobody translated") == "A text nobody translated")
    }

    @Test func placeholdersAreFilledIn() {
        #expect(trf("Settings exported to %@.", "a.json") == "Settings exported to a.json.")
        #expect(trf("Step %lld of %lld", 2, 4) == "Step 2 of 4")
    }

    @Test func displayNamesComeFromTheKeys() {
        #expect(SpotlightShape.circle.title == "Circle")
        #expect(HotkeyAction.toggleRing.title == "Toggle Ring")
        #expect(Permission.camera.title == "Camera")
    }
}

@Suite("Annotation bounds") struct AnnotationBoundsTests {
    private func line(_ a: CGPoint, _ b: CGPoint, width: Double = 4, tool: AnnotationTool = .line) -> Annotation {
        Annotation(tool: tool, points: [a, b], color: .red, width: width, createdAt: 0)
    }

    @Test func noAnnotationsHaveNoBounds() {
        #expect(AnnotationBounds.union([]) == nil)
    }

    @Test func strokeWidthWidensTheBounds() {
        let b = line(CGPoint(x: 10, y: 10), CGPoint(x: 110, y: 60)).drawnBounds
        #expect(b.minX < 10 && b.maxX > 110 && b.minY < 10 && b.maxY > 60)
    }

    @Test func arrowHeadFitsInTheBounds() {
        let arrow = line(CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0), tool: .arrow)
        let plain = line(CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0))
        #expect(arrow.drawnBounds.height > plain.drawnBounds.height)
    }

    @Test func unionCoversEveryAnnotation() throws {
        let a = line(CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 10))
        let b = line(CGPoint(x: 500, y: 400), CGPoint(x: 520, y: 420))
        let u = try #require(AnnotationBounds.union([a, b]))
        #expect(u.contains(a.drawnBounds) && u.contains(b.drawnBounds))
    }

    @Test func calloutBoundsAreItsDisc() {
        let c = Annotation(tool: .callout, points: [CGPoint(x: 100, y: 100)], color: .red, width: 20, calloutNumber: 1, createdAt: 0)
        #expect(c.drawnBounds == CGRect(x: 80, y: 80, width: 40, height: 40))
    }
}

@Suite("Color contrast") struct ColorContrastTests {
    @Test func luminanceBoundsAreBlackAndWhite() {
        #expect(RGBAColor.black.luminance == 0)
        #expect(abs(RGBAColor.white.luminance - 1) < 0.0001)
    }

    @Test func blackOnWhiteIsTheMaximumRatio() {
        #expect(abs(RGBAColor.black.contrastRatio(with: .white) - 21) < 0.001)
        #expect(RGBAColor.white.contrastRatio(with: .white) == 1)
    }

    @Test func lightColorsGetADarkEdgeAndDarkColorsALightOne() {
        #expect(RGBAColor.white.contrastingColor == .black)
        #expect(RGBAColor.yellow.contrastingColor == .black)
        #expect(RGBAColor.black.contrastingColor == .white)
        #expect(RGBAColor(red: 0, green: 0, blue: 0.5).contrastingColor == .white)
    }

    @Test func theEdgeAlwaysReachesAReadableRatio() {
        for color in RGBAColor.presets {
            #expect(color.contrastRatio(with: color.contrastingColor) >= 4.5)
        }
    }

    @Test func outlineIsOffByDefault() {
        #expect(RingSettings().contrastOutline == false)
    }
}

@Suite("Effects preview layout") struct EffectPreviewLayoutTests {
    @Test func smallEffectsAreShownAtRealSize() {
        #expect(EffectPreviewLayout.scale(largest: 40, height: 140) == 1)
    }

    @Test func bigEffectsShrinkToFit() {
        let scale = EffectPreviewLayout.scale(largest: 300, height: 140)
        #expect(scale < 1 && 300 * scale <= 140 / 2)
    }

    @Test func nothingShownKeepsRealSize() {
        #expect(EffectPreviewLayout.scale(largest: 0, height: 140) == 1)
    }

    @Test func largestRadiusOnlyCountsEnabledEffects() {
        var s = Settings.defaults
        s.spotlight.enabled = false
        s.ring.enabled = false
        #expect(EffectPreviewLayout.largestRadius(in: s) == 0)
        s.ring.enabled = true
        s.ring.radius = 80
        s.ring.thickness = 4
        #expect(EffectPreviewLayout.largestRadius(in: s) == 84)
        s.spotlight.enabled = true
        s.spotlight.shape = .circle
        s.spotlight.radius = 200
        #expect(EffectPreviewLayout.largestRadius(in: s) == 200)
        s.spotlight.shape = .horizontalBar
        s.spotlight.barThickness = 60
        #expect(EffectPreviewLayout.largestRadius(in: s) == 84)
    }
}

@Suite("Menu bar groups") struct MenuBarGroupTests {
    @Test func everyToggleIsInExactlyOneGroup() {
        let listed = MenuBarGroup.allCases.flatMap(\.items)
        #expect(listed.count == MenuBarItem.allCases.count)
        #expect(Set(listed) == Set(MenuBarItem.allCases))
    }

    @Test func groupsKeepTheDisplayOrder() {
        #expect(MenuBarGroup.cursorEffects.items.first == .spotlight)
        #expect(MenuBarGroup.presenterTools.items.first == .keystrokes)
        #expect(MenuBarGroup.presenterTools.items.last == .captions)
    }

    @Test func titlesComeFromExistingTexts() {
        #expect(MenuBarGroup.cursorEffects.title == "Cursor Effects")
        #expect(MenuBarGroup.presenterTools.title == "Presenter Tools")
    }
}

@Suite("Recording region") struct RecordingRegionTests {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    @Test func theCornersMayBeDraggedInAnyDirection() throws {
        let a = try #require(RecordingRegion.selection(from: CGPoint(x: 300, y: 400), to: CGPoint(x: 100, y: 150), in: screen))
        #expect(a == CGRect(x: 100, y: 150, width: 200, height: 250))
        let b = try #require(RecordingRegion.selection(from: CGPoint(x: 100, y: 150), to: CGPoint(x: 300, y: 400), in: screen))
        #expect(a == b)
    }

    @Test func aSelectionIsKeptInsideTheScreen() throws {
        let r = try #require(RecordingRegion.selection(from: CGPoint(x: 1300, y: 800), to: CGPoint(x: 1800, y: 1200), in: screen))
        #expect(r == CGRect(x: 1300, y: 800, width: 140, height: 100))
    }

    @Test func aTooSmallSelectionIsRefused() {
        #expect(RecordingRegion.selection(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 90, y: 400), in: screen) == nil)
        #expect(RecordingRegion.selection(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 50, y: 50), in: screen) == nil)
        #expect(RecordingRegion.selection(from: CGPoint(x: 2000, y: 50), to: CGPoint(x: 2500, y: 400), in: screen) == nil)
    }

    @Test func screenCaptureKitCountsFromTheTopLeft() {
        let source = RecordingRegion.sourceRect(CGRect(x: 100, y: 100, width: 300, height: 200), in: screen)
        #expect(source == CGRect(x: 100, y: 600, width: 300, height: 200))
    }

    @Test func aSecondDisplayIsRelativeToItself() {
        let second = CGRect(x: 1440, y: -200, width: 1920, height: 1080)
        let source = RecordingRegion.sourceRect(CGRect(x: 1500, y: -100, width: 200, height: 200), in: second)
        #expect(source == CGRect(x: 60, y: 780, width: 200, height: 200))
    }

    @Test func theWholeScreenSelectionRoundTrips() throws {
        let all = try #require(RecordingRegion.selection(from: .zero, to: CGPoint(x: 1440, y: 900), in: screen))
        #expect(RecordingRegion.sourceRect(all, in: screen) == CGRect(x: 0, y: 0, width: 1440, height: 900))
    }

    @Test func theAreaIsWholeScreenByDefault() {
        #expect(RecorderSettings().area == .screen)
    }
}

@Suite("Zoom controller") struct ZoomControllerTests {
    private func settings(_ transform: (inout ZoomSettings) -> Void = { _ in }) -> ZoomSettings {
        var z = ZoomSettings()
        z.enabled = true
        z.factor = 3
        z.animationDuration = 0.5
        z.holdDuration = 1
        transform(&z)
        return z
    }

    /// Asks for the level on every frame (60 per second) from `from` to `to`, as the app does, and returns the last one.
    @discardableResult
    private func run(_ c: inout ZoomController, _ z: ZoomSettings, from: Double, to: Double, reduceMotion: Bool = false) -> Double {
        var t = from
        var level = 1.0
        while t <= to + 1e-9 {
            level = c.level(at: t, settings: z, reduceMotion: reduceMotion)
            t += 1.0 / 60
        }
        return level
    }

    @Test func aDisabledZoomStaysAtOne() {
        var c = ZoomController()
        #expect(run(&c, ZoomSettings(), from: 0, to: 2) == 1)
        #expect(c.isIdle)
    }

    @Test func theZoomGlidesToItsFactor() {
        var c = ZoomController()
        let z = settings()
        run(&c, z, from: 0, to: 0.1)
        let early = c.level(at: 0.1, settings: z, reduceMotion: false)
        let middle = run(&c, z, from: 0.1, to: 0.25)
        let late = run(&c, z, from: 0.25, to: 0.4)
        #expect(1 < early && early < middle && middle < late && late < 3)
        #expect(abs(middle - 2) < 0.05, "halfway is halfway: \(middle)")
        #expect(run(&c, z, from: 0.4, to: 0.6) == 3)
        #expect(!c.isIdle)
    }

    @Test func theEasingStartsAndEndsSlowly() {
        #expect(ZoomController.ease(0) == 0 && ZoomController.ease(1) == 1)
        #expect(ZoomController.ease(0.1) < 0.1 && ZoomController.ease(0.9) > 0.9)
    }

    @Test func reduceMotionJumpsStraightThere() {
        var c = ZoomController()
        #expect(c.level(at: 0, settings: settings(), reduceMotion: true) == 3)
        var off = settings(); off.enabled = false
        #expect(c.level(at: 0.01, settings: off, reduceMotion: true) == 1)
        #expect(c.isIdle)
    }

    @Test func turningTheZoomOffGlidesBackOut() {
        var c = ZoomController()
        let on = settings()
        #expect(run(&c, on, from: 0, to: 1) == 3)
        var off = on; off.enabled = false
        let out = run(&c, off, from: 1.0, to: 1.25)
        #expect(out > 1 && out < 3, "on its way out: \(out)")
        #expect(!c.isIdle)
        #expect(run(&c, off, from: 1.25, to: 2) == 1)
        #expect(c.isIdle)
    }

    @Test func changingTheFactorWhileZoomedGlidesFromWhereItIs() {
        var c = ZoomController()
        let z = settings()
        run(&c, z, from: 0, to: 1)
        var bigger = z; bigger.factor = 5
        let next = run(&c, bigger, from: 1.0, to: 1.25)
        #expect(next > 3 && next < 5, "between the two factors: \(next)")
        #expect(run(&c, bigger, from: 1.25, to: 2) == 5)
    }

    @Test func aClickZoomsInThenBackOutAfterTheHold() {
        var c = ZoomController()
        let z = settings { $0.trigger = .onClick }
        #expect(run(&c, z, from: 0, to: 1) == 1)
        #expect(c.isIdle)
        c.click(at: 1, settings: z)                                  // in by 1.5, held until 2.5, back at 3.0
        #expect(run(&c, z, from: 1, to: 1.6) == 3)
        #expect(run(&c, z, from: 1.6, to: 2.4) == 3)
        let leaving = run(&c, z, from: 2.4, to: 2.75)
        #expect(leaving > 1 && leaving < 3, "on its way out: \(leaving)")
        #expect(run(&c, z, from: 2.75, to: 4) == 1)
        #expect(c.isIdle)
    }

    @Test func anotherClickExtendsTheHold() {
        var c = ZoomController()
        let z = settings { $0.trigger = .onClick }
        c.click(at: 1, settings: z)
        run(&c, z, from: 1, to: 2.4)
        c.click(at: 2.4, settings: z)                                // it would have left at 2.5
        #expect(run(&c, z, from: 2.4, to: 3.5) == 3)
        #expect(run(&c, z, from: 3.5, to: 5) == 1)
    }

    @Test func clicksDoNothingInAlwaysModeOrWhenDisabled() {
        var always = ZoomController()
        always.click(at: 0, settings: settings())
        #expect(run(&always, settings(), from: 0, to: 1) == 3)
        let disabled = settings { $0.trigger = .onClick; $0.enabled = false }
        var off = ZoomController()
        off.click(at: 0, settings: disabled)
        #expect(run(&off, disabled, from: 0, to: 1) == 1)
        #expect(off.isIdle)
    }

    @Test func defaultsKeepTheFormerBehaviorWithAGlide() {
        let z = ZoomSettings()
        #expect(z.trigger == .always && z.animationDuration == 0.35 && z.holdDuration == 1.5)
    }

    @Test func outOfRangeValuesAreRepaired() {
        var s = Settings.defaults
        s.zoom.animationDuration = 99
        s.zoom.holdDuration = -3
        let c = s.clamped()
        #expect(c.zoom.animationDuration == ZoomSettings.animationDurationRange.upperBound)
        #expect(c.zoom.holdDuration == ZoomSettings.holdDurationRange.lowerBound)
    }
}

@Suite("Keystroke styles") struct KeystrokeStyleTests {
    @Test func modifiersAreKeysOfTheirOwn() {
        #expect(KeystrokeLabel.keys(of: "⌘⇧T").keys == ["⌘", "⇧", "T"])
        #expect(KeystrokeLabel.keys(of: "⌃⌥⌘M").keys == ["⌃", "⌥", "⌘", "M"])
    }

    @Test func namedKeysStayWhole() {
        #expect(KeystrokeLabel.keys(of: "⌘Space").keys == ["⌘", "Space"])
        #expect(KeystrokeLabel.keys(of: "F5").keys == ["F5"])
        #expect(KeystrokeLabel.keys(of: "⌥↩").keys == ["⌥", "↩"])
    }

    @Test func aRepeatCountIsSeparated() {
        let r = KeystrokeLabel.keys(of: "⌘K ×3")
        #expect(r.keys == ["⌘", "K"] && r.repeats == "×3")
        #expect(KeystrokeLabel.keys(of: "⌘K").repeats == nil)
    }

    @Test func aKeyThatLooksLikeARepeatIsNotOne() {
        #expect(KeystrokeLabel.keys(of: "⌘×").keys == ["⌘", "×"])
        #expect(KeystrokeLabel.keys(of: "⌘ ×").repeats == nil)
    }

    @Test func anEmptyLabelHasNoKeys() {
        #expect(KeystrokeLabel.keys(of: "").keys.isEmpty)
    }

    @Test func classicIsTheDefaultAndOnlyGlassAndNeonUseTheAccent() {
        #expect(KeystrokeSettings().style == .classic)
        #expect(KeystrokeStyle.allCases.filter(\.usesAccent) == [.glass, .neon])
    }
}
