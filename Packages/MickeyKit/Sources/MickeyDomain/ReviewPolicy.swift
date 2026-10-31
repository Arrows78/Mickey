import Foundation

public struct ReviewState: Codable, Equatable, Sendable {
    public var launchCount = 0
    public var activeMinutes = 0.0
    public var lastRequest: Date?
    public init() {}
}

/// Decides whether it is a good moment to ask for an App Store review.
public struct ReviewPolicy: Sendable {
    public var minimumLaunches = 5
    public var minimumActiveMinutes = 30.0
    public var minimumSessionMinutes = 5.0
    public var minimumInterval: TimeInterval = 120 * 24 * 3600

    public init() {}

    public struct Context: Sendable {
        public var state: ReviewState
        public var sessionMinutes: Double
        public var onboardingComplete: Bool
        public var settingsWindowFrontmost: Bool
        public var spotlightVisible: Bool
        public var drawing: Bool
        public var askedThisSession: Bool
        public var now: Date

        public init(state: ReviewState, sessionMinutes: Double, onboardingComplete: Bool, settingsWindowFrontmost: Bool,
                    spotlightVisible: Bool, drawing: Bool, askedThisSession: Bool, now: Date) {
            self.state = state; self.sessionMinutes = sessionMinutes; self.onboardingComplete = onboardingComplete
            self.settingsWindowFrontmost = settingsWindowFrontmost; self.spotlightVisible = spotlightVisible
            self.drawing = drawing; self.askedThisSession = askedThisSession; self.now = now
        }
    }

    public enum Blocker: String, Equatable, Sendable {
        case notQualified = "not qualified yet"
        case sessionTooShallow = "session too shallow"
        case onboardingIncomplete = "onboarding incomplete"
        case settingsNotFrontmost = "settings not frontmost"
        case spotlightOnScreen = "spotlight on screen"
        case drawingInProgress = "drawing in progress"
        case askedRecently = "asked recently"
    }

    /// Empty result means the review may be requested now.
    public func blockers(_ c: Context) -> [Blocker] {
        var b: [Blocker] = []
        if c.state.launchCount < minimumLaunches || c.state.activeMinutes < minimumActiveMinutes { b.append(.notQualified) }
        if c.sessionMinutes < minimumSessionMinutes { b.append(.sessionTooShallow) }
        if !c.onboardingComplete { b.append(.onboardingIncomplete) }
        if !c.settingsWindowFrontmost { b.append(.settingsNotFrontmost) }
        if c.spotlightVisible { b.append(.spotlightOnScreen) }
        if c.drawing { b.append(.drawingInProgress) }
        if c.askedThisSession { b.append(.askedRecently) }
        else if let last = c.state.lastRequest, c.now.timeIntervalSince(last) < minimumInterval { b.append(.askedRecently) }
        return b
    }
}
