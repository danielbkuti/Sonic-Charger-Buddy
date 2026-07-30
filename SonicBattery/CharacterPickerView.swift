import SwiftUI

// Swipeable character picker. Swiping only changes what's PREVIEWED (used to
// browse states and quote styles) — it never touches the real
// selectedCharacter until you tap "Select". State testing lives on
// TestStatesView (reached via the 🧪 icon), not on this screen.
struct CharacterPickerView: View {
    @EnvironmentObject var batteryManager: BatteryActivityManager

    private let cardWidth: CGFloat = 100
    private let cardHeight: CGFloat = 130
    private let cardSpacing: CGFloat = 10

    @State private var scrollPosition: SonicCharacter?
    // nil = no character has been picked yet — no Live Activity exists, and
    // no card shows as "active" until the user taps Select.
    @State private var activeCharacter: SonicCharacter? = SonicActivityController.selectedCharacterIfSet

    @State private var quoteStyleSelection: String = SonicActivityController.defaultQuoteStyleValue
    @State private var randomFrequencySelection: SonicActivityController.QuoteShuffleFrequency = .daily

    private var previewedCharacter: SonicCharacter { scrollPosition ?? activeCharacter ?? .sonic }

    var body: some View {
        VStack(spacing: 16) {
            Text("Choose Your Character")
                .font(.custom("KarmaFuture-Regular", size: 22))
                .foregroundStyle(previewedCharacter.themeTextColor)

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
                .foregroundStyle(previewedCharacter.themeTextColor)

            HStack(spacing: 24) {
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

                quoteStyleMenu

                // Takes you to TestStatesView for the currently previewed character.
                NavigationLink(value: previewedCharacter) {
                    Image("SonicIcon")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .foregroundStyle(previewedCharacter.themeTextColor)
                }
            }
            .padding(.top, 16) // moves the whole button bar down by one extra spacing unit

            if quoteStyleSelection == SonicActivityController.randomQuoteStyleValue {
                frequencyPicker
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            previewedCharacter.themeGradient
                .ignoresSafeArea()
        )
        .animation(.easeInOut(duration: 0.3), value: previewedCharacter)
        .onAppear {
            scrollPosition = activeCharacter ?? .sonic
            syncQuoteStyleState()
        }
        .onChange(of: scrollPosition) { _, _ in
            syncQuoteStyleState()
        }
    }

    // A Picker with .menu style always shows the *selected option's* text as
    // its trigger, which would override a fixed icon — Menu's label is fully
    // custom regardless of the current selection, so it's used here instead.
    private var quoteStyleMenu: some View {
        Menu {
            Button("Default Quotes") {
                setQuoteStyle(SonicActivityController.defaultQuoteStyleValue)
            }
            ForEach(otherCharacters, id: \.self) { other in
                Button("\(other.displayName) Quotes") {
                    setQuoteStyle(other.quoteTag)
                }
            }
            Button("Random") {
                setQuoteStyle(SonicActivityController.randomQuoteStyleValue)
            }
        } label: {
            Image("ChatIcon")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 28, height: 28)
                .foregroundStyle(previewedCharacter.themeTextColor)
        }
    }

    private func setQuoteStyle(_ value: String) {
        quoteStyleSelection = value
        SonicActivityController.setQuoteStyle(value, for: previewedCharacter)
        if previewedCharacter == activeCharacter {
            Task { await SonicActivityController.pushRestingUpdate() }
        }
    }

    private var frequencyPicker: some View {
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

    private func characterCard(_ character: SonicCharacter) -> some View {
        Image(character.idleImageName(highBattery: false))
            .resizable()
            .interpolation(.none)
            .scaledToFit()
            .frame(width: 80, height: 80)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentTransition(.opacity)
    }
}

#Preview {
    CharacterPickerView()
        .environmentObject(BatteryActivityManager())
}
