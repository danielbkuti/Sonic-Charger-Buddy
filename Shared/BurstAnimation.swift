import Foundation

// One case per sprite set, each with its own frame count. imagePrefix must match
// an Asset Catalog imageset named "<prefix><frame>" (e.g. "RollingF0").
//
// .batteryDropped and .highBattery are one-shot bursts: SonicActivityController
// plays through the full frame set exactly once, then returns to rest.
// .rolling is NOT a one-shot burst — it's shown continuously as the "resting"
// state whenever charging and battery < 90% (see SonicLiveActivity.imageName
// and SonicActivityController.pushRestingUpdate). It can still be passed to
// playBurst() directly for manual testing.
enum BurstAnimation: String, Codable, Hashable {
    // Shared with the idle-pose logic in SonicLiveActivity — both the
    // "just transformed" burst trigger and the idle/rolling sprite choice key
    // off the same battery-level threshold.
    static let highBatteryThreshold = 0.90

    case rolling // Sonic Rolling
    case batteryDropped // Sonic Bored
    case highBattery // Super Sonic transformation, crossing 90% while charging

    var imagePrefix: String {
        switch self {
        case .rolling: return "RollingF"
        case .batteryDropped: return "BoredF"
        case .highBattery: return "SuperSonicF"
        }
    }

    var frameCount: Int {
        switch self {
        case .rolling: return 6
        case .batteryDropped: return 19
        case .highBattery: return 15
        }
    }

    // Seconds per frame — tuned per set since frame counts vary a lot.
    var frameInterval: TimeInterval {
        switch self {
        case .rolling: return 0.2
        case .batteryDropped: return 0.15 // 0.2 felt sluggish, 0.1 felt too rushed
        case .highBattery: return 0.2
        }
    }

    func imageName(forFrame frame: Int, character: SonicCharacter) -> String {
        let base = "\(imagePrefix)\(frame % frameCount)"
        return character.assetPrefix.isEmpty ? base : "\(character.assetPrefix)_\(base)"
    }
}
