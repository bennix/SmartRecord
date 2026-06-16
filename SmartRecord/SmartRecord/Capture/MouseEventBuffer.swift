import Foundation

struct RawClick { let time: Double; let nx: Double; let ny: Double }
struct RawSample { let time: Double; let nx: Double; let ny: Double; let dragging: Bool }

final class MouseEventBuffer {
    private let w: Double
    private let h: Double
    private(set) var clicks: [RawClick] = []
    private(set) var samples: [RawSample] = []

    init(screenWidth: Double, screenHeight: Double) {
        self.w = screenWidth
        self.h = screenHeight
    }

    func record(kind: MouseEventKind, time: Double, px: Double, py: Double) {
        let nx = min(max(px / w, 0), 1)
        let ny = min(max(py / h, 0), 1)
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
