import Foundation
import SwiftData

@Model
final class RenderSettings {
    var zoomEnabled: Bool
    var zoomScale: Double          // 1.2 ~ 2.5
    var cursorSmoothing: Double    // 0 ~ 1
    var cursor3D: Bool
    var backgroundPadding: Double  // 0 ~ 1
    var cornerRadius: Double
    var micSystemMix: Double       // 0=纯系统 1=纯麦克风，0.5=均衡

    init() {
        zoomEnabled = true
        zoomScale = 1.8
        cursorSmoothing = 0.7
        cursor3D = false
        backgroundPadding = 0.1
        cornerRadius = 12
        micSystemMix = 0.5
    }
}
