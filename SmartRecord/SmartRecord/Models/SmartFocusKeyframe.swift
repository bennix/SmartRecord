import Foundation
import SwiftData

enum SmartFocusKeyframeSource: String, Codable, CaseIterable {
    case detectedClick
    case userEdited
}

@Model
final class SmartFocusKeyframe {
    var time: Double
    var nx: Double
    var ny: Double
    var zoomScale: Double
    var holdDuration: Double
    var transitionDuration: Double
    var sourceRawValue: String

    init(
        time: Double,
        nx: Double,
        ny: Double,
        zoomScale: Double,
        holdDuration: Double = 1.2,
        transitionDuration: Double = 0.25,
        source: SmartFocusKeyframeSource = .userEdited
    ) {
        self.time = max(0, time)
        self.nx = min(max(nx, 0), 1)
        self.ny = min(max(ny, 0), 1)
        self.zoomScale = min(max(zoomScale, 1), 2.4)
        self.holdDuration = max(0.1, holdDuration)
        self.transitionDuration = max(0.05, transitionDuration)
        self.sourceRawValue = source.rawValue
    }

    var source: SmartFocusKeyframeSource {
        get { SmartFocusKeyframeSource(rawValue: sourceRawValue) ?? .userEdited }
        set { sourceRawValue = newValue.rawValue }
    }
}
