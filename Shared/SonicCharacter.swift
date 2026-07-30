import Foundation
import SwiftUI

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

    // The Dynamic Island's compactTrailing slot shows this character's Chaos
    // Emerald (each character has its own color) instead of the battery
    // percentage iOS shows there by default.
    var chaosEmeraldImageName: String {
        assetPrefix.isEmpty ? "ChaosEmerald" : "\(assetPrefix)_ChaosEmerald"
    }

    // Diagonal light-to-dark gradient (top-leading to bottom-trailing), same
    // style as the app icon's background. Sonic's two stops are sampled
    // directly from AppIcon.png itself; every other character's stops are
    // derived from that same character's Chaos Emerald color (see
    // chaosEmeraldImageName) by lightening/darkening it in HSL space, so the
    // gradient look is consistent without needing hand-picked art per case.
    var themeGradient: LinearGradient {
        let stops: (light: Color, dark: Color)
        switch self {
        case .sonic:
            stops = (Color(red: 0.125, green: 0.541, blue: 0.957), // #208AF4
                      Color(red: 0.125, green: 0.125, blue: 0.545)) // #20208B
        case .shadow:
            stops = (Color(red: 0.227, green: 0.227, blue: 0.227), // #3A3A3A
                      Color(red: 0, green: 0, blue: 0)) // #000000
        case .silver:
            stops = (Color(red: 0.761, green: 0.780, blue: 0.792), // #C2C7CA
                      Color(red: 0.337, green: 0.369, blue: 0.384)) // #565E62
        case .knuckles:
            stops = (Color(red: 0.863, green: 0.502, blue: 0.451), // #DC8073
                      Color(red: 0.416, green: 0.141, blue: 0.102)) // #6A241A
        case .tails:
            stops = (Color(red: 0.894, green: 0.831, blue: 0.384), // #E4D462
                      Color(red: 0.420, green: 0.376, blue: 0.071)) // #6B6012
        case .espio:
            stops = (Color(red: 0.839, green: 0.478, blue: 0.859), // #D67ADB
                      Color(red: 0.408, green: 0.114, blue: 0.427)) // #681D6D
        }
        return LinearGradient(colors: [stops.light, stops.dark], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // User-specified per-character text color, picked to read clearly against
    // that character's own themeGradient.
    var themeTextColor: Color {
        switch self {
        case .sonic: return Color(red: 247/255, green: 215/255, blue: 52/255)
        case .shadow: return Color(red: 169/255, green: 6/255, blue: 35/255)
        case .silver: return Color(red: 0/255, green: 247/255, blue: 246/255)
        case .knuckles: return .white
        case .tails: return Color(red: 24/255, green: 18/255, blue: 236/255)
        case .espio: return Color(red: 0/255, green: 226/255, blue: 26/255)
        }
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
