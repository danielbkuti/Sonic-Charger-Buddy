import SwiftUI

// Swipeable character picker. Swiping only changes what's PREVIEWED (used to
// browse states and quote styles) — it never touches the real
// selectedCharacter until you tap "Select". State buttons at the bottom
// animate the previewed card's own sprite locally, in-app — no Live Activity
// involved, so this works even without one running.
struct CharacterPickerView: View {
    @EnvironmentObject var batteryManager: BatteryActivityManager

    private let cardWidth: CGFloat = 100
    private let cardHeight: CGFloat = 130
    private let cardSpacing: CGFloat = 10

    @State private var scrollPosition: SonicCharacter?
    // nil = no character has been picked yet — no Live Activity exists, and
    // no card shows as "active" until the user taps Select.
    @State private var activeCharacter: SonicCharacter? = SonicActivityController.selectedCharacterIfSet

    // Local, in-app animation playback — entirely separate from ActivityKit.
    @State private var previewAnimation: BurstAnimation?
    @State private var previewFrame: Int = 0
    @State private var previewTask: Task<Void, Never>?

    @State private var quoteStyleSelection: String = SonicActivityController.defaultQuoteStyleValue
    @State private var randomFrequencySelection: SonicActivityController.QuoteShuffleFrequency = .daily

    private var previewedCharacter: SonicCharacter { scrollPosition ?? activeCharacter ?? .sonic }

    var body: some View {
        VStack(spacing: 16) {
            Text("Choose Your Character")
                .font(.custom("KarmaFuture-Regular", size: 22))

            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: cardSpacing) {
                        ForEach(SonicCharacter.allCases, id: \.self) { character in
                            characterCard(character)
                                .frame(width: cardWidth, height: cardHeight)
                                .scrollTransition { content, phase in
                                    content
                                        .scaleEffect(phase.isIdentity ? 1.0 : 0.85)
                                        .opacity(phase.isIdentity ? 1.0 : 0.4)
                                }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $scrollPosition)
                .safeAreaPadding(.horizontal, (geometry.size.width - cardWidth) / 2)
            }
            .frame(height: cardHeight)

            Text(previewedCharacter.displayName)
                .font(.custom("KarmaSuture-Regular", size: 18))

            if previewedCharacter == activeCharacter {
                Button("Stop \(previewedCharacter.displayName)") {
                    stopActiveCharacter()
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else {
                Button("Select \(previewedCharacter.displayName)") {
                    selectPreviewedCharacter()
                }
                .buttonStyle(.borderedProminent)
            }

            quoteStylePicker

            Divider()
            Text("Test \(previewedCharacter.displayName)'s states")
                .font(.headline)
            Text("Plays right here in the app — no need to check the Island.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack {
                Button("Rolling") { playLocalPreview(.rolling) }
                Button("Battery Drop") { playLocalPreview(.batteryDropped) }
                Button("90% Transform") { playLocalPreview(.highBattery) }
            }
            .buttonStyle(.bordered)
        }
        .onAppear {
            scrollPosition = activeCharacter ?? .sonic
            syncQuoteStyleState()
        }
        .onChange(of: scrollPosition) { _, _ in
            previewTask?.cancel()
            previewAnimation = nil
            syncQuoteStyleState()
        }
    }

    private var quoteStylePicker: some View {
        VStack(spacing: 8) {
            Picker("Quote Style", selection: $quoteStyleSelection) {
                Text("Default Quotes").tag(SonicActivityController.defaultQuoteStyleValue)
                ForEach(otherCharacters, id: \.self) { other in
                    Text("\(other.displayName) Quotes").tag(other.quoteTag)
                }
                Text("Random").tag(SonicActivityController.randomQuoteStyleValue)
            }
            .pickerStyle(.menu)
            .onChange(of: quoteStyleSelection) { _, newValue in
                SonicActivityController.setQuoteStyle(newValue, for: previewedCharacter)
                if previewedCharacter == activeCharacter {
                    Task { await SonicActivityController.pushRestingUpdate() }
                }
            }

            if quoteStyleSelection == SonicActivityController.randomQuoteStyleValue {
                Picker("Shuffle Frequency", selection: $randomFrequencySelection) {
                    ForEach(SonicActivityController.QuoteShuffleFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.rawValue.capitalized).tag(frequency)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: randomFrequencySelection) { _, newValue in
                    SonicActivityController.setRandomQuoteFrequency(newValue, for: previewedCharacter)
                }
            }
        }
    }

    private var otherCharacters: [SonicCharacter] {
        SonicCharacter.allCases.filter { $0 != previewedCharacter }
    }

    private func syncQuoteStyleState() {
        quoteStyleSelection = SonicActivityController.quoteStyle(for: previewedCharacter)
        randomFrequencySelection = SonicActivityController.randomQuoteFrequency(for: previewedCharacter)
    }

    /// Selecting a character IS how the Live Activity starts — there's no
    /// separate Start button. First selection ever creates it; after that,
    /// selecting a different character just switches which one it shows.
    private func selectPreviewedCharacter() {
        let character = previewedCharacter
        SonicActivityController.selectedCharacter = character
        activeCharacter = character
        batteryManager.isDailyCharacterSwitchEnabled = false

        if batteryManager.isActivityRunning {
            Task { await SonicActivityController.pushRestingUpdate() }
        } else {
            batteryManager.startActivity()
        }
    }

    /// Ends the Live Activity and clears the selection entirely — back to
    /// "nobody selected" until you tap Select again. Not just a UI reset:
    /// clearing the selection is what stops a later background wake from
    /// silently recreating it (see ensureActivityRunning's guard).
    private func stopActiveCharacter() {
        batteryManager.stopActivity()
        SonicActivityController.clearSelectedCharacter()
        activeCharacter = nil
    }

    /// Cycles the previewed card's own image through an animation's frames
    /// locally — no ActivityKit, no network, just SwiftUI state updates.
    private func playLocalPreview(_ animation: BurstAnimation) {
        previewTask?.cancel()
        previewTask = Task { @MainActor in
            for step in 0..<animation.frameCount {
                guard !Task.isCancelled else { return }
                previewAnimation = animation
                previewFrame = step
                try? await Task.sleep(for: .seconds(animation.frameInterval))
            }
            guard !Task.isCancelled else { return }
            previewAnimation = nil
        }
    }

    private func characterCard(_ character: SonicCharacter) -> some View {
        Image(cardImageName(for: character))
            .resizable()
            .interpolation(.none)
            .scaledToFit()
            .frame(width: 80, height: 80)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentTransition(.opacity)
    }

    private func cardImageName(for character: SonicCharacter) -> String {
        if character == previewedCharacter, let previewAnimation {
            return previewAnimation.imageName(forFrame: previewFrame, character: character)
        }
        return character.idleImageName(highBattery: false)
    }
}

#Preview {
    CharacterPickerView()
        .environmentObject(BatteryActivityManager())
}
