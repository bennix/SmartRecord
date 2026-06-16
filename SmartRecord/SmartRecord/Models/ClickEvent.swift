import Foundation
import SwiftData

@Model
final class ClickEvent {
    /// 相对录制起点的秒数
    var time: Double
    /// 归一化坐标 [0,1]，左上原点
    var nx: Double
    var ny: Double

    init(time: Double, nx: Double, ny: Double) {
        self.time = time
        self.nx = nx
        self.ny = ny
    }
}
