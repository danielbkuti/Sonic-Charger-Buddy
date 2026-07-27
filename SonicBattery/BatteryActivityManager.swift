import ActivityKit
import Combine
import Foundation
import SwiftUI
import UIKit
import UserNotifications

@MainActor
final class BatteryActivityManager: ObservableObject {
    @Published var batteryLevel: Double = 0
    @Published var isActivityRunning = false

    // Single reactive source of truth so the top-right corner icon (in
    // ContentView) and the carousel's "Select" action (in CharacterPickerView,
    // which turns this off) always agree on the current state.
    @Published var isDailyCharacterSwitchEnabled: Bool = SonicActivityController.isDailyCharacterSwitchEnabled {
        didSet {
            SonicActivityController.isDailyCharacterSwitchEnabled = isDailyCharacterSwitchEnabled
        }
    }

    private var activity: Activity<SonicActivityAttributes>?
    private var rollingTimer: Timer?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    // The Dynamic Island doesn't show this app's own Live Activity while this
    // app is frontmost (nothing to look at that isn't already on screen), so
    // there's no point pushing updates until the app actually backgrounds.
    private var isAppActive = true

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryLevel = Double(UIDevice.current.batteryLevel)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryStatusChanged),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryStatusChanged),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // If the app relaunched while a Live Activity from a previous session
        // was still running (e.g. it wasn't cleanly stopped), adopt it instead
        // of assuming there's none — otherwise tapping Start would create a
        // second, duplicate Activity.
        if let existing = Activity<SonicActivityAttributes>.activities.first {
            activity = existing
            isActivityRunning = true
        }
    }

    @objc private func batteryStatusChanged() {
        batteryLevel = Double(UIDevice.current.batteryLevel)
        guard !isAppActive else { return }
        updateRollingTimer()
        Task { await SonicActivityController.evaluateAndReact() }
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            isAppActive = true
            rollingTimer?.invalidate()
            rollingTimer = nil
            SonicActivityController.endExtendedExecution(backgroundTaskID)
            backgroundTaskID = .invalid

        case .background:
            isAppActive = false
            backgroundTaskID = SonicActivityController.beginExtendedExecution()
            Task { await SonicActivityController.evaluateAndReact() }
            updateRollingTimer()

        default:
            break
        }
    }

    // Keeps Rolling smoothly advancing while charging < 90% and the app is
    // backgrounded (see handleScenePhaseChange — never runs while foregrounded).
    // Only reliable for the ~30s extended-execution window granted on
    // backgrounding; BackgroundRefresh's periodic wake covers the rest with
    // occasional nudges.
    private func updateRollingTimer() {
        guard !isAppActive else {
            rollingTimer?.invalidate()
            rollingTimer = nil
            return
        }

        let state = UIDevice.current.batteryState
        let isCharging = state == .charging || state == .full
        let shouldRoll = isCharging && batteryLevel < BurstAnimation.highBatteryThreshold

        guard shouldRoll else {
            rollingTimer?.invalidate()
            rollingTimer = nil
            return
        }
        guard rollingTimer == nil else { return }

        rollingTimer = Timer.scheduledTimer(withTimeInterval: BurstAnimation.rolling.frameInterval, repeats: true) { _ in
            Task { @MainActor in
                await SonicActivityController.pushRestingUpdate()
            }
        }
    }

    func startActivity() {
        Task {
            if let running = await SonicActivityController.ensureActivityRunning() {
                activity = running
                isActivityRunning = true
            }
        }
    }

    func stopActivity() {
        rollingTimer?.invalidate()
        rollingTimer = nil
        SonicActivityController.cancelExpirationWarning()
        Task {
            await activity?.end(nil, dismissalPolicy: .immediate)
            activity = nil
            isActivityRunning = false
        }
    }
}
