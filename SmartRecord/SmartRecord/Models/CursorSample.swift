import Foundation
import SwiftData

@Model
final class CursorSample {
    var time: Double
    var nx: Double
    var ny: Double
    var dragging: Bool

    init(time: Double, nx: Double, ny: Double, dragging: Bool) {
        self.time = time
        self.nx = nx
        self.ny = ny
        self.dragging = dragging
    }
}
