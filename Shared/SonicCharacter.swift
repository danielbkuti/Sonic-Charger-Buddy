import Foundation

// The set of characters the user will eventually be able to pick from in-app
// (step 4/5/6 of the character-selection feature — this file is just the model).
//
// .sonic's assetPrefix is empty on purpose: the sprites already in the asset
// catalog (RollingF0, BoredF0, IdleLowBattery, etc.) were made before this
// enum existed, so Sonic keeps those exact names rather than needing every
// existing asset renamed. Future characters need their own sprite sets named
// "<assetPrefix>_<existing name>" (e.g. "Shadow_RollingF0") once that art exists.
enum SonicCharacter: String, Codable, Hashable, CaseIterable {
    case sonic
    case shadow
    case silver
    case knuckles
    case tails
    case espio

    var assetPrefix: String {
        switch self {
        case .sonic: return ""
        case .shadow: return "Shadow"
        case .silver: return "Silver"
        case .knuckles: return "Knuckles"
        case .tails: return "Tails"
        case .espio: return "Espio"
        }
    }

    var displayName: String {
        switch self {
        case .sonic: return "Sonic"
        case .shadow: return "Shadow"
        case .silver: return "Silver"
        case .knuckles: return "Knuckles"
        case .tails: return "Tails"
        case .espio: return "Espio"
        }
    }

    // Idle poses aren't part of BurstAnimation (they're not a burst), so they
    // need the same "prefix only if non-empty" naming rule spelled out here
    // rather than reusing BurstAnimation.imageName.
    func idleImageName(highBattery: Bool) -> String {
        let base = highBattery ? "IdleHighBattery" : "IdleLowBattery"
        return assetPrefix.isEmpty ? base : "\(assetPrefix)_\(base)"
    }

    // Which tag in Quotes.json this character's quotes come from — matched
    // against a Quote's `tags` array in QuoteLibrary.quotes(forTag:).
    // TODO: only .sonic's tag ("cheerful") is real — the rest are placeholders
    // reusing it so nothing breaks; replace each with the real tag you want.
    var quoteTag: String {
        switch self {
        case .sonic: return "speed"
        case .shadow: return "chaos"
        case .silver: return "time"
        case .knuckles: return "power"
        case .tails: return "learn"
        case .espio: return "sight"
        }
    }
}
