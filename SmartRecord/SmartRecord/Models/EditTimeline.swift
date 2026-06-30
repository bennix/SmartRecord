import Foundation
import SwiftData

@Model
final class EditTimeline {
    @Relationship(deleteRule: .cascade) var segments: [EditSegment]
    @Relationship(deleteRule: .cascade) var annotations: [AnnotationItem]
    @Relationship(deleteRule: .cascade) var smartFocusKeyframes: [SmartFocusKeyframe]
    @Relationship(deleteRule: .cascade) var captions: [CaptionSegment]
    @Relationship(deleteRule: .cascade) var exportSettings: ExportSettings?

    init(sourceDuration: Double) {
        self.segments = [EditSegment(sourceStartTime: 0, sourceEndTime: max(0, sourceDuration))]
        self.annotations = []
        self.smartFocusKeyframes = []
        self.captions = []
        self.exportSettings = ExportSettings()
    }

    var duration: Double {
        TimelineMapper(segments: segments).duration
    }
}
