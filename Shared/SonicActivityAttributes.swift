import ActivityKit
import Foundation

struct SonicActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var batteryLevel: Double // 0.0 ... 1.0
        var isCharging: Bool
        var animation: BurstAnimation? // nil = idle; set for ~3s after a trigger event
        var frame: Int // only meaningful while animation != nil
        var character: SonicCharacter // which sprite set to render
        var quote: String // resolved quote text, chosen by SonicActivityController
    }

    var startDate: Date
}
