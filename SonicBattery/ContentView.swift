import SwiftUI

struct ContentView: View {
    @EnvironmentObject var batteryManager: BatteryActivityManager

    // Edit these two to change what the daily-switch icon looks like on/off.
    private let dailySwitchOnIcon = "🔁"
    private let dailySwitchOffIcon = "⏸️"

    var body: some View {
        VStack(spacing: 20) {
            CharacterPickerView()
        }
        .padding()
        .overlay(alignment: .topTrailing) {
            dailySwitchIcon
                .padding()
        }
    }

    private var dailySwitchIcon: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.4)) {
                batteryManager.isDailyCharacterSwitchEnabled.toggle()
            }
        } label: {
            Text(batteryManager.isDailyCharacterSwitchEnabled ? dailySwitchOnIcon : dailySwitchOffIcon)
                .font(.system(size: 28))
                .rotation3DEffect(
                    .degrees(batteryManager.isDailyCharacterSwitchEnabled ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(BatteryActivityManager())
}
