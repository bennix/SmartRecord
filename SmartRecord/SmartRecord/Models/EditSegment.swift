import Foundation
import SwiftData

@Model
final class EditSegment {
    var sourceStartTime: Double
    var sourceEndTime: Double
    var timelineStartTime: Double
    var isEnabled: Bool

    init(sourceStartTime: Double, sourceEndTime: Double, timelineStartTime: Double = 0, isEnabled: Bool = true) {
        let clampedSourceStartTime = max(0, sourceStartTime)
        self.sourceStartTime = clampedSourceStartTime
        self.sourceEndTime = max(clampedSourceStartTime, sourceEndTime)
        self.timelineStartTime = max(0, timelineStartTime)
        self.isEnabled = isEnabled
    }

    var duration: Double {
        max(0, sourceEndTime - sourceStartTime)
    }
}
