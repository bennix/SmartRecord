import Testing
@testable import SmartRecord

struct RecordingClockTests {
    @Test func elapsedIsZeroAtStart() {
        let clock = RecordingClock(startTicks: 1000, ticksPerSecond: 1_000_000)
        #expect(abs(clock.elapsed(atTicks: 1000) - 0) < 1e-9)
    }

    @Test func elapsedConvertsTicksToSeconds() {
        let clock = RecordingClock(startTicks: 1000, ticksPerSecond: 1_000_000)
        // 500_000 ticks later = 0.5 s
        #expect(abs(clock.elapsed(atTicks: 1000 + 500_000) - 0.5) < 1e-9)
    }

    @Test func elapsedNeverNegative() {
        let clock = RecordingClock(startTicks: 2000, ticksPerSecond: 1_000_000)
        #expect(clock.elapsed(atTicks: 1000) == 0)
    }

    @Test func elapsedUsesEventTimestampNanoseconds() {
        let clock = RecordingClock(startTicks: 1_000_000, ticksPerSecond: 1_000_000)

        #expect(abs(clock.elapsed(atEventTimestampNanoseconds: 1_500_000_000) - 0.5) < 1e-9)
    }
}
