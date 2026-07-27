import AppIntents
import UIKit

// Called from Shortcuts Personal Automations ("When Charger Connected" / "When
// Charger Disconnected", with "Ask Before Running" turned off). It doesn't need
// to know which automation fired it — it just re-checks real battery/charging
// state, which SonicActivityController compares against what it last saw.
struct RefreshSonicActivityIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Sonic Battery Activity"
    static var description = IntentDescription(
        "Checks battery/charging state and plays the Sonic burst animation if something changed."
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        // Extra execution headroom so a triggered Rolling/burst has room to
        // finish even though this runs without the app UI ever opening.
        let taskID = SonicActivityController.beginExtendedExecution()
        // "Launch if needed, otherwise just refresh": ensureActivityRunning
        // starts a fresh Activity only if none exists (e.g. it expired or was
        // manually stopped since last charge); if one's already running, this
        // is a no-op and evaluateAndReact just updates it in place.
        await SonicActivityController.ensureActivityRunning()
        await SonicActivityController.evaluateAndReact()
        SonicActivityController.endExtendedExecution(taskID)
        return .result()
    }
}
