import SwiftUI

struct ContentView: View {
    @EnvironmentObject var batteryManager: BatteryActivityManager

    // Edit these two to change what the daily-switch icon looks like on/off.
    // Both are template images so they can be recolored per character.
    private let dailySwitchOnIcon = "RepeatIcon"
    private let dailySwitchOffIcon = "PauseIcon"

    // Small hovering confirmation shown above the icon when tapped, explaining
    // what just changed (the icon alone doesn't make the on/off meaning obvious).
    @State private var dailySwitchToastMessage: String?
    @State private var dailySwitchToastTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                CharacterPickerView()
            }
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .topTrailing) {
                dailySwitchIcon
                    .padding()
            }
            .navigationDestination(for: SonicCharacter.self) { character in
                TestStatesView(character: character)
            }
        }
    }

    private var dailySwitchIcon: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.4)) {
                batteryManager.isDailyCharacterSwitchEnabled.toggle()
            }
            showDailySwitchToast(
                batteryManager.isDailyCharacterSwitchEnabled
                    ? "Daily character switch turned on"
                    : "Switched to a fixed character"
            )
        } label: {
            Image(batteryManager.isDailyCharacterSwitchEnabled ? dailySwitchOnIcon : dailySwitchOffIcon)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 28, height: 28)
                .foregroundStyle(iconTintCharacter.themeTextColor)
                .rotation3DEffect(
                    .degrees(batteryManager.isDailyCharacterSwitchEnabled ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
        }
        .overlay(alignment: .top) {
            if let dailySwitchToastMessage {
                Text(dailySwitchToastMessage)
                    .font(.caption2.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
                    .fixedSize()
                    .offset(y: -34)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    // No "previewed" character concept exists at this level (that's the
    // carousel's scroll state, private to CharacterPickerView) — this icon
    // tints to whichever character is actually selected/active, falling back
    // to Sonic when nobody's picked one yet.
    private var iconTintCharacter: SonicCharacter {
        SonicActivityController.selectedCharacterIfSet ?? .sonic
    }

    private func showDailySwitchToast(_ message: String) {
        dailySwitchToastTask?.cancel()
        withAnimation { dailySwitchToastMessage = message }
        dailySwitchToastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            withAnimation { dailySwitchToastMessage = nil }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(BatteryActivityManager())
}
