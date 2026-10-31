import AppKit
import StoreKit
import MickeyDomain
import MickeyPersistence

/// Counts launches and active usage, and asks for an App Store review when `ReviewPolicy` allows it.
final class ReviewTracker {
    private let store: SettingsStore
    private let policy = ReviewPolicy()
    private var state: ReviewState
    private let sessionStart = Date()
    private var askedThisSession = false
    private var timer: Timer?
    private var isActive: () -> Bool = { false }

    init(store: SettingsStore) {
        self.store = store
        state = store.loadReviewState()
    }

    /// Records the launch, then adds one active minute for every minute `isActive` holds.
    func start(isActive: @escaping () -> Bool) {
        self.isActive = isActive
        state.launchCount += 1
        store.saveReviewState(state)
        let t = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isActive() else { return }
                self.state.activeMinutes += 1
                self.store.saveReviewState(self.state)
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func requestIfAppropriate(onboardingComplete: Bool, settingsWindowFrontmost: Bool, spotlightVisible: Bool,
                              drawing: Bool, presentingFrom controller: NSViewController?) {
        let context = ReviewPolicy.Context(state: state, sessionMinutes: Date().timeIntervalSince(sessionStart) / 60,
                                           onboardingComplete: onboardingComplete,
                                           settingsWindowFrontmost: settingsWindowFrontmost,
                                           spotlightVisible: spotlightVisible, drawing: drawing,
                                           askedThisSession: askedThisSession, now: Date())
        guard policy.blockers(context).isEmpty, let controller else { return }
        askedThisSession = true
        state.lastRequest = Date()
        store.saveReviewState(state)
        AppStore.requestReview(in: controller)
    }
}
