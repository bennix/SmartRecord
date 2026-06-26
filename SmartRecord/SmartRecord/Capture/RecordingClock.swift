import Foundation

struct RecordingClock {
    let startTicks: UInt64
    let ticksPerSecond: Double
    private let startNanoseconds: Double

    /// Construct from the real mach timebase (recording start point).
    init(startTicks: UInt64) {
        self.startTicks = startTicks
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        // ticks -> nanoseconds: * numer / denom; ticks per second = 1e9 * denom / numer
        self.ticksPerSecond = 1_000_000_000.0 * Double(info.denom) / Double(info.numer)
        self.startNanoseconds = Double(startTicks) / ticksPerSecond * 1_000_000_000.0
    }

    /// Test seam: explicit ticksPerSecond.
    init(startTicks: UInt64, ticksPerSecond: Double) {
        self.startTicks = startTicks
        self.ticksPerSecond = ticksPerSecond
        self.startNanoseconds = Double(startTicks) / ticksPerSecond * 1_000_000_000.0
    }

    func elapsed(atTicks ticks: UInt64) -> Double {
        guard ticks > startTicks else { return 0 }
        return Double(ticks - startTicks) / ticksPerSecond
    }

    func elapsed(atEventTimestampNanoseconds timestamp: UInt64) -> Double {
        let timestamp = Double(timestamp)
        guard timestamp > startNanoseconds else { return 0 }
        return (timestamp - startNanoseconds) / 1_000_000_000.0
    }
}
