import Testing
@testable import SmartRecord

struct TimelineMapperTests {
    @Test func mapsSourceTimesAcrossDeletedMiddleSegment() {
        let segments = [
            EditSegment(sourceStartTime: 0, sourceEndTime: 5, timelineStartTime: 0),
            EditSegment(sourceStartTime: 8, sourceEndTime: 12, timelineStartTime: 5)
        ]
        let mapper = TimelineMapper(segments: segments)

        #expect(mapper.timelineTime(forSourceTime: 2) == 2)
        #expect(mapper.timelineTime(forSourceTime: 9) == 6)
        #expect(mapper.timelineTime(forSourceTime: 6) == nil)
        #expect(mapper.sourceTime(forTimelineTime: 6.5) == 9.5)
    }

    @Test func normalizesTimelineStartsFromEnabledSegments() {
        let segments = [
            EditSegment(sourceStartTime: 3, sourceEndTime: 7, timelineStartTime: 99),
            EditSegment(sourceStartTime: 10, sourceEndTime: 12, timelineStartTime: 0, isEnabled: false),
            EditSegment(sourceStartTime: 20, sourceEndTime: 25, timelineStartTime: 1)
        ]

        let normalized = TimelineMapper.normalizedSegments(from: segments)

        #expect(normalized.count == 2)
        #expect(normalized[0].timelineStartTime == 0)
        #expect(normalized[1].timelineStartTime == 4)
    }
}
