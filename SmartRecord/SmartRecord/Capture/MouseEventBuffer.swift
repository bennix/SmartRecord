import CoreGraphics
import Foundation

struct RawClick { let time: Double; let nx: Double; let ny: Double }
struct RawSample { let time: Double; let nx: Double; let ny: Double; let dragging: Bool }

final class MouseEventBuffer {
    private let screenFrame: CGRect
    private(set) var clicks: [RawClick] = []
    private(set) var samples: [RawSample] = []

    init(screenFrame: CGRect) {
        precondition(screenFrame.width > 0 && screenFrame.height > 0, "screen dimensions must be positive")
        self.screenFrame = screenFrame
    }

    init(screenWidth: Double, screenHeight: Double) {
        precondition(screenWidth > 0 && screenHeight > 0, "screen dimensions must be positive")
        self.screenFrame = CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight)
    }

    /// Not thread-safe: must be called from the run-loop thread that owns the event tap.
    func record(kind: MouseEventKind, time: Double, px: Double, py: Double) {
        let nx = min(max((px - screenFrame.minX) / screenFrame.width, 0), 1)
        let ny = min(max((py - screenFrame.minY) / screenFrame.height, 0), 1)
        switch kind {
        case .leftMouseDown:
            clicks.append(RawClick(time: time, nx: nx, ny: ny))
        case .mouseMoved:
            samples.append(RawSample(time: time, nx: nx, ny: ny, dragging: false))
        case .leftMouseDragged:
            samples.append(RawSample(time: time, nx: nx, ny: ny, dragging: true))
        }
    }
}
