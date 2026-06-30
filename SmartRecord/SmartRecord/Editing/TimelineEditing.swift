import Foundation

nonisolated enum TimelineEditing {
    static func split(_ segment: EditSegment, atTimelineTime timelineTime: Double) -> (left: EditSegment, right: EditSegment) {
        let offset = min(max(timelineTime - segment.timelineStartTime, 0), segment.duration)
        let sourceSplit = segment.sourceStartTime + offset
        let left = EditSegment(
            sourceStartTime: segment.sourceStartTime,
            sourceEndTime: sourceSplit,
            timelineStartTime: segment.timelineStartTime,
            isEnabled: segment.isEnabled
        )
        let right = EditSegment(
            sourceStartTime: sourceSplit,
            sourceEndTime: segment.sourceEndTime,
            timelineStartTime: segment.timelineStartTime + left.duration,
            isEnabled: segment.isEnabled
        )
        return (left, right)
    }

    static func trim(_ segment: EditSegment, newSourceStartTime: Double, newSourceEndTime: Double) {
        let lower = segment.sourceStartTime
        let upper = segment.sourceEndTime
        let nextStart = min(max(newSourceStartTime, lower), upper)
        let nextEnd = min(max(newSourceEndTime, nextStart), upper)
        segment.sourceStartTime = nextStart
        segment.sourceEndTime = nextEnd
    }

    static func delete(_ segment: EditSegment, in timeline: EditTimeline) {
        segment.isEnabled = false
        _ = TimelineMapper.normalizedSegments(from: timeline.segments)
    }

    static func replace(_ segment: EditSegment, in timeline: EditTimeline, with replacements: [EditSegment]) {
        guard let index = timeline.segments.firstIndex(where: { $0 === segment }) else { return }
        timeline.segments.remove(at: index)
        timeline.segments.insert(contentsOf: replacements, at: index)
        _ = TimelineMapper.normalizedSegments(from: timeline.segments)
    }
}
