import SwiftUI

// Reached by tapping the 🧪 icon on the character picker (placeholder for a
// custom template-image icon). Shows one character's sprite full-size and
// lets you preview its animations locally, in-app — no ActivityKit, no need
// to check the Dynamic Island. Owns its own preview state since the carousel
// on the picker screen isn't visible from here.
struct TestStatesView: View {
    let character: SonicCharacter

    @State private var previewAnimation: BurstAnimation?
    @State private var previewFrame: Int = 0
    @State private var previewTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 16) {
            Image(imageName)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 180, height: 180)
                .contentTransition(.opacity)

            Text("Test \(character.displayName)'s states")
                .font(.headline)
                .foregroundStyle(character.themeTextColor)
            Text("Plays right here in the app — no need to check the Island.")
                .font(.caption)
                .foregroundStyle(character.themeTextColor.opacity(0.8))
                .multilineTextAlignment(.center)

            HStack {
                Button("Rolling") { play(.rolling) }
                Button("Battery Drop") { play(.batteryDropped) }
                Button("90% Transform") { play(.highBattery) }
            }
            .buttonStyle(.bordered)
            .tint(character.themeTextColor)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(character.themeGradient.ignoresSafeArea())
        .navigationTitle("\(character.displayName) States")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var imageName: String {
        if let previewAnimation {
            return previewAnimation.imageName(forFrame: previewFrame, character: character)
        }
        return character.idleImageName(highBattery: false)
    }

    private func play(_ animation: BurstAnimation) {
        previewTask?.cancel()
        previewTask = Task { @MainActor in
            for step in 0..<animation.frameCount(for: character) {
                guard !Task.isCancelled else { return }
                previewAnimation = animation
                previewFrame = step
                try? await Task.sleep(for: .seconds(animation.frameInterval))
            }
            guard !Task.isCancelled else { return }
            previewAnimation = nil
        }
    }
}

#Preview {
    NavigationStack {
        TestStatesView(character: .sonic)
    }
}
