import AppKit
import Foundation

final class MouseEventTap {
    private var timer: Timer?
    private var lastLocation: CGPoint?
    private var lastLeftButtonDown = false
    private let buffer: MouseEventBuffer
    private let clock: RecordingClock
    private let sampleInterval: TimeInterval = 1.0 / 30.0

    init(buffer: MouseEventBuffer, clock: RecordingClock) {
        self.buffer = buffer
        self.clock = clock
    }

    deinit { stop() }

    @discardableResult
    func start() -> Bool {
        guard timer == nil else { return true }
        sample()
        let timer = Timer(timeInterval: sampleInterval, repeats: true) { [weak self] _ in
            self?.sample()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        return true
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        lastLocation = nil
        lastLeftButtonDown = false
    }

    private func sample() {
        guard let event = CGEvent(source: nil) else {
            return
        }
        let location = event.location
        let leftButtonDown = (NSEvent.pressedMouseButtons & 1) == 1
        defer {
            lastLocation = location
            lastLeftButtonDown = leftButtonDown
        }

        let time = clock.elapsed(atTicks: mach_absolute_time())
        if leftButtonDown && !lastLeftButtonDown {
            buffer.record(kind: .leftMouseDown, time: time, px: Double(location.x), py: Double(location.y))
            return
        }

        guard let lastLocation else {
            buffer.record(kind: .mouseMoved, time: time, px: Double(location.x), py: Double(location.y))
            return
        }

        let moved = abs(location.x - lastLocation.x) >= 0.5 || abs(location.y - lastLocation.y) >= 0.5
        guard moved else { return }

        buffer.record(
            kind: leftButtonDown ? .leftMouseDragged : .mouseMoved,
            time: time,
            px: Double(location.x),
            py: Double(location.y)
        )
    }
}
