import Testing
@testable import SmartRecord

struct TimelineEditingTests {
    @Test func splitSegmentCreatesTwoSourceRanges() {
        let segment = EditSegment(sourceStartTime: 0, sourceEndTime: 10, timelineStartTime: 0)

        let result = TimelineEditing.split(segment, atTimelineTime: 4)

        #expect(result.left.sourceStartTime == 0)
        #expect(result.left.sourceEndTime == 4)
        #expect(result.right.sourceStartTime == 4)
        #expect(result.right.sourceEndTime == 10)
        #expect(result.right.timelineStartTime == 4)
    }

    @Test func trimEdgesClampsInsideOriginalRange() {
        let segment = EditSegment(sourceStartTime: 5, sourceEndTime: 15, timelineStartTime: 0)

        TimelineEditing.trim(segment, newSourceStartTime: 8, newSourceEndTime: 20)

        #expect(segment.sourceStartTime == 8)
        #expect(segment.sourceEndTime == 15)
    }
}
