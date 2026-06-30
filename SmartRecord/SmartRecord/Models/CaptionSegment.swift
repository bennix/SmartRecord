import Foundation
import SwiftData

@Model
final class CaptionSegment {
    var startTime: Double
    var endTime: Double
    var text: String
    var languageCode: String
    var confidence: Double
    var isEnabled: Bool

    init(
        startTime: Double,
        endTime: Double,
        text: String,
        languageCode: String,
        confidence: Double = 0,
        isEnabled: Bool = true
    ) {
        let clampedStartTime = max(0, startTime)
        self.startTime = clampedStartTime
        self.endTime = max(clampedStartTime, endTime)
        self.text = text
        self.languageCode = languageCode
        self.confidence = min(max(confidence, 0), 1)
        self.isEnabled = isEnabled
    }

    var duration: Double {
        max(0, endTime - startTime)
    }
}
