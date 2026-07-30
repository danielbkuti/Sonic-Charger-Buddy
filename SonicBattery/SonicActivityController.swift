import ActivityKit
import Foundation
import UIKit
import UserNotifications

// Central place that decides what the Dynamic Island should show. Called from
// BatteryActivityManager (foreground), BackgroundRefresh (periodic background
// wake), and the Shortcuts-triggered App Intent — so all three paths react
// consistently instead of duplicating the detection logic.
//
// Every animation sequence (a one-shot burst or a resting-state refresh) runs
// as a single owned Task. Starting a new one always cancels whatever's
// currently running first — without this, two overlapping sequences (e.g. a
// stray timer tick landing right as a burst starts, or double-tapping a test
// button) race to call activity.update() and the result looks like skipped
// frames or a single stuck "nudge" instead of a clean animation.
enum SonicActivityController {
    // iOS shows its own full-screen charging overlay for ~2s right after you plug
    // in the cable, which sits on top of the Dynamic Island. Wait it out so the
    // Rolling animation is actually visible instead of hidden behind it.
    static let justPluggedInDelay: Duration = .seconds(2)

    private enum DefaultsKey {
        static let lastIsCharging = "SonicActivityController.lastIsCharging"
        static let lastWasChargingHigh = "SonicActivityController.lastWasChargingHigh"
        static let lastDecile = "SonicActivityController.lastDecile"
        static let rollingFrame = "SonicActivityController.rollingFrame"
        static let lastPausedNotificationBatteryLevel = "SonicActivityController.lastPausedNotificationBatteryLevel"
        static let selectedCharacter = "SonicActivityController.selectedCharacter"
        static let lastQuoteTag = "SonicActivityController.lastQuoteTag"
        static let lastQuoteShuffleDay = "SonicActivityController.lastQuoteShuffleDay"
        static let currentQuoteText = "SonicActivityController.currentQuoteText"
        static let isDailyCharacterSwitchEnabled = "SonicActivityController.isDailyCharacterSwitchEnabled"
        static let lastDailySwitchDay = "SonicActivityController.lastDailySwitchDay"
        static func quoteStyle(for character: SonicCharacter) -> String {
            "SonicActivityController.quoteStyle.\(character.rawValue)"
        }
        static func randomQuoteFrequency(for character: SonicCharacter) -> String {
            "SonicActivityController.randomQuoteFrequency.\(character.rawValue)"
        }
    }

    enum QuoteShuffleFrequency: String, CaseIterable {
        case hourly
        case daily

        var seconds: TimeInterval {
            switch self {
            case .hourly: return 60 * 60
            case .daily: return 24 * 60 * 60
            }
        }
    }

    // Sentinels stored in the quoteStyle UserDefaults slot. Any other stored
    // string is treated as a literal tag to pull quotes from (either the
    // character's own default tag, or another character's, picked explicitly
    // via the picker).
    static let defaultQuoteStyleValue = "__default__"
    static let randomQuoteStyleValue = "__random__"

    // Re-notify based on charging progress, not a clock — only once the battery
    // has actually moved by roughly this much since the last "reopen the app"
    // notification, so it tracks real activity instead of nagging on a timer.
    private static let pausedNotificationMinLevelDelta = 0.05 // 5 percentage points

    private static var currentTask: Task<Void, Never>?

    /// nil until the user has actually picked a character (as opposed to
    /// `selectedCharacter` below, which always returns something — this is
    /// what lets the UI distinguish "nothing chosen yet" from "Sonic is
    /// chosen," since Sonic is also the fallback default.
    static var selectedCharacterIfSet: SonicCharacter? {
        guard let raw = UserDefaults.standard.string(forKey: DefaultsKey.selectedCharacter) else { return nil }
        return SonicCharacter(rawValue: raw)
    }

    /// The character every new ContentState push uses. Reads/writes UserDefaults
    /// directly, so a future picker UI (step 6) can just set this — no other
    /// plumbing needed. Falls back to .sonic if nothing's been chosen yet or the
    /// stored value doesn't match a known case (e.g. after removing a character).
    static var selectedCharacter: SonicCharacter {
        get { selectedCharacterIfSet ?? .sonic }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: DefaultsKey.selectedCharacter)
        }
    }

    /// Back to "nobody selected" — call when the user explicitly stops the
    /// Live Activity, so it stays stopped instead of a later background wake
    /// silently recreating it (see ensureActivityRunning's guard).
    static func clearSelectedCharacter() {
        UserDefaults.standard.removeObject(forKey: DefaultsKey.selectedCharacter)
    }

    /// Whether the character auto-rotates to a random new one once per day.
    /// Turning this on (or its daily rotation firing) also resets every
    /// character's quote-tag override back to default — see
    /// applyDailyCharacterSwitchIfNeeded.
    static var isDailyCharacterSwitchEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: DefaultsKey.isDailyCharacterSwitchEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: DefaultsKey.isDailyCharacterSwitchEnabled) }
    }

    /// What a character's quote picker is currently set to: defaultQuoteStyleValue
    /// (its own tag), randomQuoteStyleValue, or a literal tag (its own or a
    /// borrowed one) — see quoteCandidates(for:) for how this resolves to
    /// actual quotes.
    static func quoteStyle(for character: SonicCharacter) -> String {
        UserDefaults.standard.string(forKey: DefaultsKey.quoteStyle(for: character)) ?? defaultQuoteStyleValue
    }

    static func setQuoteStyle(_ value: String, for character: SonicCharacter) {
        let key = DefaultsKey.quoteStyle(for: character)
        if value == defaultQuoteStyleValue {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(value, forKey: key)
        }
    }

    static func randomQuoteFrequency(for character: SonicCharacter) -> QuoteShuffleFrequency {
        let key = DefaultsKey.randomQuoteFrequency(for: character)
        guard let raw = UserDefaults.standard.string(forKey: key), let frequency = QuoteShuffleFrequency(rawValue: raw) else {
            return .daily
        }
        return frequency
    }

    static func setRandomQuoteFrequency(_ frequency: QuoteShuffleFrequency, for character: SonicCharacter) {
        UserDefaults.standard.set(frequency.rawValue, forKey: DefaultsKey.randomQuoteFrequency(for: character))
    }

    /// The pool a character's quote should be drawn from, resolved from its
    /// current style: the full library if Random, otherwise quotes matching
    /// either its own default tag or an explicitly borrowed one.
    private static func quoteCandidates(for character: SonicCharacter) -> [Quote] {
        let style = quoteStyle(for: character)
        if style == randomQuoteStyleValue {
            return QuoteLibrary.all
        }
        let tag = style == defaultQuoteStyleValue ? character.quoteTag : style
        return QuoteLibrary.quotes(forTag: tag)
    }

    private static func resetAllQuoteStyles() {
        for character in SonicCharacter.allCases {
            setQuoteStyle(defaultQuoteStyleValue, for: character)
        }
    }

    /// If daily switching is on and a new calendar day has started since the
    /// last switch, rotates to a random different character and resets tag
    /// overrides. Call this before reading selectedCharacter for a real
    /// (non-preview) push. A no-op otherwise.
    @MainActor
    private static func applyDailyCharacterSwitchIfNeeded() {
        guard isDailyCharacterSwitchEnabled else { return }
        let defaults = UserDefaults.standard
        let lastSwitchDay = defaults.object(forKey: DefaultsKey.lastDailySwitchDay) as? Date
        if let lastSwitchDay, Calendar.current.isDateInToday(lastSwitchDay) { return }

        let others = SonicCharacter.allCases.filter { $0 != selectedCharacter }
        selectedCharacter = others.randomElement() ?? selectedCharacter
        resetAllQuoteStyles()
        defaults.set(Date(), forKey: DefaultsKey.lastDailySwitchDay)
    }

    /// The quote every real (non-preview) ContentState push uses. Reshuffles
    /// to a new random quote from the current character's pool either once
    /// its shuffle interval has elapsed (hourly/daily, only meaningful for
    /// Random style — pinned-tag styles always shuffle daily), or immediately
    /// if the style changed since the last pick — otherwise keeps returning
    /// the same stored quote so it doesn't flicker on every single render
    /// (e.g. every Rolling frame).
    private static func currentQuote() -> String {
        let character = selectedCharacter
        let style = quoteStyle(for: character)
        let candidates = quoteCandidates(for: character)
        guard !candidates.isEmpty else { return "..." }

        let frequency = style == randomQuoteStyleValue ? randomQuoteFrequency(for: character) : .daily

        let defaults = UserDefaults.standard
        let lastStyle = defaults.string(forKey: DefaultsKey.lastQuoteTag)
        let lastShuffleAt = defaults.object(forKey: DefaultsKey.lastQuoteShuffleDay) as? Date
        let storedQuote = defaults.string(forKey: DefaultsKey.currentQuoteText)

        let styleChanged = lastStyle != style
        let intervalElapsed = lastShuffleAt.map { Date().timeIntervalSince($0) >= frequency.seconds } ?? true

        if !styleChanged, !intervalElapsed, let storedQuote, candidates.contains(where: { $0.text == storedQuote }) {
            return storedQuote
        }

        let newQuote = candidates.randomElement()!.text
        defaults.set(style, forKey: DefaultsKey.lastQuoteTag)
        defaults.set(Date(), forKey: DefaultsKey.lastQuoteShuffleDay)
        defaults.set(newQuote, forKey: DefaultsKey.currentQuoteText)
        return newQuote
    }

    /// A transient, non-persisting quote pick for previewing a character in
    /// the carousel that isn't the real selectedCharacter — doesn't touch the
    /// stored shuffle state, so it can't corrupt the real rotation.
    static func previewQuote(for character: SonicCharacter) -> String {
        quoteCandidates(for: character).randomElement()?.text ?? "..."
    }

    /// Returns the single running Activity, creating one if none exists, and
    /// cleaning up any extras if somehow more than one exists (e.g. a prior
    /// app session ended without stopping its Activity, then Start got tapped
    /// again — this is what used to let two Live Activities run at once).
    /// Called both by the Select button and by the Shortcuts-triggered intent,
    /// so "launch if needed, otherwise just refresh" always goes through the
    /// same single path.
    ///
    /// Never auto-creates unless a character has actually been selected —
    /// otherwise a background wake (BackgroundRefresh, the Shortcuts intent)
    /// would silently resurrect an Activity the user explicitly stopped, or
    /// create one before they've ever picked a character.
    @MainActor
    @discardableResult
    static func ensureActivityRunning() async -> Activity<SonicActivityAttributes>? {
        let existing = Activity<SonicActivityAttributes>.activities
        if let first = existing.first {
            for extra in existing.dropFirst() {
                await extra.end(nil, dismissalPolicy: .immediate)
            }
            return first
        }

        guard selectedCharacterIfSet != nil else { return nil }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("SonicActivityController: Live Activities disabled in Settings.")
            return nil
        }

        UIDevice.current.isBatteryMonitoringEnabled = true
        let state = UIDevice.current.batteryState
        let attributes = SonicActivityAttributes(startDate: Date())
        let content = SonicActivityAttributes.ContentState(
            batteryLevel: Double(UIDevice.current.batteryLevel),
            isCharging: state == .charging || state == .full,
            animation: nil,
            frame: 0,
            character: selectedCharacter,
            quote: currentQuote()
        )

        do {
            let newActivity = try Activity.request(attributes: attributes, content: .init(state: content, staleDate: nil))
            scheduleExpirationWarning()
            return newActivity
        } catch {
            print("SonicActivityController: failed to start Activity: \(error)")
            return nil
        }
    }

    @MainActor
    static func evaluateAndReact() async {
        applyDailyCharacterSwitchIfNeeded()

        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = Double(UIDevice.current.batteryLevel)
        let deviceState = UIDevice.current.batteryState
        let isCharging = deviceState == .charging || deviceState == .full
        let isChargingHigh = isCharging && level >= BurstAnimation.highBatteryThreshold

        let defaults = UserDefaults.standard
        let lastIsCharging = defaults.object(forKey: DefaultsKey.lastIsCharging) as? Bool
        let lastWasChargingHigh = defaults.bool(forKey: DefaultsKey.lastWasChargingHigh)
        let currentDecile = Int((level * 10).rounded(.down))
        let lastDecile = defaults.object(forKey: DefaultsKey.lastDecile) as? Int ?? currentDecile

        var triggered: BurstAnimation?
        if currentDecile < lastDecile {
            triggered = .batteryDropped
        }
        if isChargingHigh && !lastWasChargingHigh {
            triggered = .highBattery // takes priority over a same-tick drop
        }
        let justConnected = lastIsCharging == false && isCharging

        print("""
        SonicActivityController.evaluateAndReact:
          level=\(level) deviceState=\(deviceState.rawValue) isCharging=\(isCharging) isChargingHigh=\(isChargingHigh)
          lastIsCharging=\(String(describing: lastIsCharging)) lastWasChargingHigh=\(lastWasChargingHigh)
          currentDecile=\(currentDecile) lastDecile=\(lastDecile)
          triggered=\(String(describing: triggered)) justConnected=\(justConnected)
          runningActivity=\(Activity<SonicActivityAttributes>.activities.first?.id ?? "none")
        """)

        defaults.set(isCharging, forKey: DefaultsKey.lastIsCharging)
        defaults.set(isChargingHigh, forKey: DefaultsKey.lastWasChargingHigh)
        defaults.set(currentDecile, forKey: DefaultsKey.lastDecile)

        if let triggered {
            await playBurst(triggered)
        } else if justConnected {
            await runOwned { try? await Task.sleep(for: justPluggedInDelay) }
            await pushRestingUpdate()
        } else {
            await pushRestingUpdate()
        }
    }

    /// Plays a sprite set's full frame sequence once, then returns to rest.
    /// Also callable directly (e.g. from a "Test" button) regardless of real
    /// battery state — including .rolling, for previewing it on demand.
    /// Cancels and replaces whatever animation sequence is currently running.
    ///
    /// Pass `character` to preview a different character than the real
    /// selectedCharacter (e.g. browsing the carousel) without touching any
    /// persisted state — it reverts to the real character once the burst ends.
    @MainActor
    static func playBurst(_ animation: BurstAnimation, character: SonicCharacter? = nil) async {
        let isPreview = character != nil && character != selectedCharacter
        let resolvedCharacter = character ?? selectedCharacter
        let resolvedQuote = isPreview ? previewQuote(for: resolvedCharacter) : nil

        await runOwned {
            guard let activity = Activity<SonicActivityAttributes>.activities.first else { return }
            for step in 0..<animation.frameCount(for: resolvedCharacter) {
                guard !Task.isCancelled else { return }
                await push(activity: activity, animation: animation, frame: step, character: resolvedCharacter, quote: resolvedQuote)
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .seconds(animation.frameInterval))
            }
        }

        // highBattery ends on its own golden "arrived" pose — hold there instead
        // of immediately re-deriving from live device state, which could yank it
        // straight back to Rolling if the real battery hasn't caught up to 90%
        // yet (or, when previewed via a Test button, hasn't reached it at all).
        guard animation != .highBattery else { return }
        await pushRestingUpdate()
    }

    /// Pushes one frame of whatever the current resting state is: Rolling
    /// (advancing one frame from last time) if charging and < 90%, otherwise
    /// idle. Call this repeatedly (a timer, a periodic wake) to keep Rolling
    /// animating for as long as charging continues. Cancels and replaces
    /// whatever animation sequence is currently running.
    @MainActor
    static func pushRestingUpdate() async {
        await runOwned {
            guard let activity = Activity<SonicActivityAttributes>.activities.first else { return }
            guard !Task.isCancelled else { return }

            let deviceState = UIDevice.current.batteryState
            let isCharging = deviceState == .charging || deviceState == .full
            let level = Double(UIDevice.current.batteryLevel)

            var frame = 0
            if isCharging && level < BurstAnimation.highBatteryThreshold {
                let defaults = UserDefaults.standard
                frame = (defaults.integer(forKey: DefaultsKey.rollingFrame) + 1) % BurstAnimation.rolling.frameCount(for: selectedCharacter)
                defaults.set(frame, forKey: DefaultsKey.rollingFrame)
            }
            guard !Task.isCancelled else { return }
            await push(activity: activity, animation: nil, frame: frame)
        }
    }

    /// Cancels whatever sequence currently owns activity.update() calls, then
    /// runs `body` as the new owner and waits for it to finish.
    @MainActor
    private static func runOwned(_ body: @escaping @MainActor () async -> Void) async {
        currentTask?.cancel()
        let task = Task { @MainActor in
            await body()
        }
        currentTask = task
        await task.value
    }

    @MainActor
    private static func push(
        activity: Activity<SonicActivityAttributes>,
        animation: BurstAnimation?,
        frame: Int,
        character: SonicCharacter? = nil,
        quote: String? = nil
    ) async {
        let deviceState = UIDevice.current.batteryState
        let content = SonicActivityAttributes.ContentState(
            batteryLevel: Double(UIDevice.current.batteryLevel),
            isCharging: deviceState == .charging || deviceState == .full,
            animation: animation,
            frame: frame,
            character: character ?? selectedCharacter,
            quote: quote ?? currentQuote()
        )
        await activity.update(.init(state: content, staleDate: nil))
    }

    /// Asks iOS for extra guaranteed background execution time (~30s, not
    /// controlled by us) so Rolling can keep animating smoothly right after the
    /// app leaves the foreground, instead of dropping straight to occasional
    /// nudges. Caller must eventually pass the result to endExtendedExecution.
    /// If the grant expires while still actively charging < 90%, fires a local
    /// notification prompting the user to reopen the app.
    @discardableResult
    static func beginExtendedExecution() -> UIBackgroundTaskIdentifier {
        var taskID: UIBackgroundTaskIdentifier = .invalid
        taskID = UIApplication.shared.beginBackgroundTask(withName: "SonicBatteryExtendedExecution") {
            notifyIfStillAnimatingOnExpiration()
            UIApplication.shared.endBackgroundTask(taskID)
        }
        return taskID
    }

    static func endExtendedExecution(_ id: UIBackgroundTaskIdentifier) {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
    }

    private static func notifyIfStillAnimatingOnExpiration() {
        let state = UIDevice.current.batteryState
        let isCharging = state == .charging || state == .full
        let level = Double(UIDevice.current.batteryLevel)
        guard isCharging && level < BurstAnimation.highBatteryThreshold else { return }

        let defaults = UserDefaults.standard
        if let lastLevel = defaults.object(forKey: DefaultsKey.lastPausedNotificationBatteryLevel) as? Double,
           abs(level - lastLevel) < pausedNotificationMinLevelDelta {
            return
        }
        defaults.set(level, forKey: DefaultsKey.lastPausedNotificationBatteryLevel)

        let content = UNMutableNotificationContent()
        content.title = "Sonic's taking a break"
        content.body = "Battery's at \(Int(level * 100))% and background time ran out — reopen SonicBattery to keep Rolling going."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "sonic.rolling.paused", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private static let expirationWarningIdentifier = "sonic.activity.expiring"

    // Not an Apple-documented guarantee, just consistently observed behavior:
    // a Live Activity the app never ends tends to get auto-removed by iOS
    // around 8 hours after Activity.request. Warn well before that so there's
    // time to notice and restart it.
    private static let observedActivityLifetime: TimeInterval = 8 * 60 * 60
    private static let expirationWarningBuffer: TimeInterval = 45 * 60

    /// Call once, right after starting the Activity. Fires independently of
    /// whatever else the app is doing — doesn't depend on being woken up.
    static func scheduleExpirationWarning() {
        let content = UNMutableNotificationContent()
        content.title = "Sonic's Live Activity is about to expire"
        content.body = "iOS automatically removes Live Activities after a while. Reopen SonicBattery to restart it before it disappears from the Dynamic Island."
        content.sound = .default

        let fireIn = observedActivityLifetime - expirationWarningBuffer
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireIn, repeats: false)
        let request = UNNotificationRequest(identifier: expirationWarningIdentifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    /// Call when the Activity is intentionally stopped, so a stale "it's about
    /// to expire" warning doesn't show up hours later for an Activity that's
    /// already gone.
    static func cancelExpirationWarning() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [expirationWarningIdentifier])
    }
}
