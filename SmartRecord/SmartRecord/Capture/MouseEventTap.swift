import CoreGraphics
import Foundation

final class MouseEventTap {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let buffer: MouseEventBuffer
    private let clock: RecordingClock

    init(buffer: MouseEventBuffer, clock: RecordingClock) {
        self.buffer = buffer
        self.clock = clock
    }

    /// Returns false if Accessibility permission was not granted (tap creation fails).
    @discardableResult
    func start() -> Bool {
        let mask = (1 << CGEventType.leftMouseDown.rawValue)
                 | (1 << CGEventType.mouseMoved.rawValue)
                 | (1 << CGEventType.leftMouseDragged.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            let me = Unmanaged<MouseEventTap>.fromOpaque(refcon!).takeUnretainedValue()
            me.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false   // most likely missing Accessibility permission
        }

        self.tap = tap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = src
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        tap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        let ticks = mach_absolute_time()
        let t = clock.elapsed(atTicks: ticks)
        let loc = event.location   // global coords, top-left origin
        let kind: MouseEventKind
        switch type {
        case .leftMouseDown: kind = .leftMouseDown
        case .mouseMoved: kind = .mouseMoved
        case .leftMouseDragged: kind = .leftMouseDragged
        default: return
        }
        buffer.record(kind: kind, time: t, px: Double(loc.x), py: Double(loc.y))
    }
}
