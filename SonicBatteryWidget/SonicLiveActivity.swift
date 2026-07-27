import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

struct SonicLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SonicActivityAttributes.self) { context in
            // Lock screen / notification banner presentation.
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    sonicSprite(for: context.state)
                        .frame(width: 48, height: 48)
                    Spacer()
                    Text(characterSays(for: context.state))
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Text(message(for: context.state))
                    .font(.subheadline)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    sonicSprite(for: context.state)
                        .frame(width: 56, height: 56)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(characterSays(for: context.state))
                        .font(.title3.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.trailing, 10) // trailing region sits flush against the pill's curved edge otherwise
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(message(for: context.state))
                            .font(.subheadline)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(context.state.isCharging ? "Charging" : "On battery")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                sonicSprite(for: context.state)
                    .frame(width: 24, height: 24)
            } compactTrailing: {
                Image("ChaosEmerald")
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            } minimal: {
                sonicSprite(for: context.state)
                    .frame(width: 20, height: 20)
            }
        }
    }

    private func sonicSprite(for state: SonicActivityAttributes.ContentState) -> some View {
        Image(imageName(for: state))
            .resizable()
            .interpolation(.none) // keep pixel art crisp instead of blurred
            .scaledToFit()
            .contentTransition(.opacity)
    }

    // The actual quote text is chosen in SonicActivityController.currentQuote()
    // and travels here via ContentState — the widget just displays it.
    private func message(for state: SonicActivityAttributes.ContentState) -> String {
        state.quote
    }

    private func characterSays(for state: SonicActivityAttributes.ContentState) -> String {
        "\(state.character.displayName.uppercased()) SAYS"
    }

    private func imageName(for state: SonicActivityAttributes.ContentState) -> String {
        if let animation = state.animation {
            return animation.imageName(forFrame: state.frame, character: state.character)
        }
        // Resting: no burst active, so the pose is derived straight from
        // isCharging/batteryLevel rather than tracked as separate state.
        if state.isCharging && state.batteryLevel < BurstAnimation.highBatteryThreshold {
            return BurstAnimation.rolling.imageName(forFrame: state.frame, character: state.character)
        }
        return state.character.idleImageName(highBattery: state.batteryLevel >= BurstAnimation.highBatteryThreshold)
    }
}

// MARK: - Canvas previews
// Renders every Live Activity presentation directly in Xcode, with a picker
// (in the Canvas toolbar) to flip between the sample states below — no phone,
// no build/run cycle, no need to manipulate real battery state.

extension SonicActivityAttributes {
    fileprivate static var preview: SonicActivityAttributes {
        SonicActivityAttributes(startDate: Date())
    }
}

extension SonicActivityAttributes.ContentState {
    fileprivate static var example: SonicActivityAttributes.ContentState {
        .init(batteryLevel: 0.72, isCharging: false, animation: nil, frame: 0, character: .sonic, quote: "The only way to do great work is to love what you do.")
    }

    fileprivate static var exampleCharging: SonicActivityAttributes.ContentState {
        .init(batteryLevel: 0.45, isCharging: true, animation: nil, frame: 2, character: .sonic, quote: "PLACEHOLDER: Gotta keep moving forward!")
    }
}

#Preview("Lock Screen", as: .content, using: SonicActivityAttributes.preview) {
    SonicLiveActivity()
} contentStates: {
    SonicActivityAttributes.ContentState.example
    SonicActivityAttributes.ContentState.exampleCharging
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: SonicActivityAttributes.preview) {
    SonicLiveActivity()
} contentStates: {
    SonicActivityAttributes.ContentState.example
    SonicActivityAttributes.ContentState.exampleCharging
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: SonicActivityAttributes.preview) {
    SonicLiveActivity()
} contentStates: {
    SonicActivityAttributes.ContentState.example
}

#Preview("Dynamic Island Minimal", as: .dynamicIsland(.minimal), using: SonicActivityAttributes.preview) {
    SonicLiveActivity()
} contentStates: {
    SonicActivityAttributes.ContentState.example
}
