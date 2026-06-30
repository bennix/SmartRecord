import Foundation

nonisolated struct TimelineSegment: Equatable {
    let sourceStartTime: Double
    let sourceEndTime: Double
    let timelineStartTime: Double

    var duration: Double { max(0, sourceEndTime - sourceStartTime) }
    var timelineEndTime: Double { timelineStartTime + duration }
}

nonisolated struct TimelineMapper {
    let segments: [TimelineSegment]

    init(segments: [EditSegment]) {
        self.segments = Self.normalizedSegments(from: segments).map {
            TimelineSegment(
                sourceStartTime: $0.sourceStartTime,
                sourceEndTime: $0.sourceEndTime,
                timelineStartTime: $0.timelineStartTime
            )
        }
    }

    init(timelineSegments: [TimelineSegment]) {
        self.segments = timelineSegments.sorted { $0.timelineStartTime < $1.timelineStartTime }
    }

    var duration: Double {
        segments.last?.timelineEndTime ?? 0
    }

    func timelineTime(forSourceTime sourceTime: Double) -> Double? {
        guard let segment = segments.first(where: { $0.sourceStartTime <= sourceTime && sourceTime <= $0.sourceEndTime }) else {
            return nil
        }
        return segment.timelineStartTime + (sourceTime - segment.sourceStartTime)
    }

    func sourceTime(forTimelineTime timelineTime: Double) -> Double? {
        guard let segment = segments.first(where: { $0.timelineStartTime <= timelineTime && timelineTime <= $0.timelineEndTime }) else {
            return nil
        }
        return segment.sourceStartTime + (timelineTime - segment.timelineStartTime)
    }

    static func normalizedSegments(from segments: [EditSegment]) -> [EditSegment] {
        let enabled = segments
            .filter { $0.isEnabled && $0.duration > 0 }
            .sorted { $0.sourceStartTime < $1.sourceStartTime }
        var cursor = 0.0
        for segment in enabled {
            segment.timelineStartTime = cursor
            cursor += segment.duration
        }
        return enabled
    }
}
