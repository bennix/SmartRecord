import CoreGraphics
import Foundation

nonisolated struct SmartFocusEvent: Equatable {
    let time: Double
    let nx: Double
    let ny: Double
}

nonisolated struct SmartFocusSample: Equatable {
    let nx: Double
    let ny: Double
    let zoom: Double
}

nonisolated struct SmartFocusSolver {
    private let segments: [FocusSegment]
    private let zoomScale: Double

    init(events: [SmartFocusEvent], duration: Double, zoomScale: Double = 1.6) {
        self.zoomScale = min(max(zoomScale, 1.2), 2.4)
        self.segments = Self.makeSegments(events: events, duration: duration)
    }

    func sample(at time: Double) -> SmartFocusSample {
        guard !segments.isEmpty else {
            return SmartFocusSample(nx: 0.5, ny: 0.5, zoom: 1.0)
        }

        if let segment = segments.last(where: { $0.start <= time && time <= $0.end }) {
            return sample(in: segment, at: time)
        }

        if let previous = segments.last(where: { $0.end < time }), time < previous.end + 0.55 {
            let progress = smoothStep((time - previous.end) / 0.55)
            let zoom = zoomScale + (1.0 - zoomScale) * progress
            return SmartFocusSample(nx: previous.nx, ny: previous.ny, zoom: zoom)
        }

        return SmartFocusSample(nx: 0.5, ny: 0.5, zoom: 1.0)
    }

    private func sample(in segment: FocusSegment, at time: Double) -> SmartFocusSample {
        let easeIn = smoothStep((time - segment.start) / 0.2)
        let easeOut = smoothStep((segment.end - time) / 0.35)
        let amount = min(1.0, max(0.0, min(easeIn, easeOut)))
        let zoom = 1.0 + (zoomScale - 1.0) * amount
        return SmartFocusSample(nx: segment.nx, ny: segment.ny, zoom: zoom)
    }

    private func smoothStep(_ value: Double) -> Double {
        let x = min(max(value, 0), 1)
        return x * x * (3 - 2 * x)
    }

    private static func makeSegments(events: [SmartFocusEvent], duration: Double) -> [FocusSegment] {
        let sortedEvents = events
            .filter { $0.time >= 0 && $0.time <= max(duration, 0) }
            .sorted { $0.time < $1.time }
        guard !sortedEvents.isEmpty else { return [] }

        return sortedEvents.map { event in
            FocusSegment(
                start: max(0, event.time - 0.2),
                end: min(max(duration, event.time + 1.2), event.time + 1.2),
                nx: min(max(event.nx, 0), 1),
                ny: min(max(event.ny, 0), 1)
            )
        }
    }

    private struct FocusSegment {
        let start: Double
        let end: Double
        let nx: Double
        let ny: Double
    }
}
