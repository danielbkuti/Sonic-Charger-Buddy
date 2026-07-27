import SwiftUI

@main
struct SonicBatteryApp: App {
    @StateObject private var batteryManager = BatteryActivityManager()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        BackgroundRefresh.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(batteryManager)
        }
        .onChange(of: scenePhase) { _, newPhase in
            print("SonicBatteryApp: scenePhase -> \(newPhase)")
            batteryManager.handleScenePhaseChange(newPhase)
            if newPhase == .background {
                BackgroundRefresh.schedule()
            }
        }
    }
}
