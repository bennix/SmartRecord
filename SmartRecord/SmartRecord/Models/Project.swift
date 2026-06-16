import Foundation
import SwiftData

@Model
final class Project {
    var createdAt: Date
    var duration: Double
    /// 原始录制 .mov 的文件名（存于 Application Support/SmartRecord/Recordings）
    var rawVideoFilename: String

    @Relationship(deleteRule: .cascade) var clickEvents: [ClickEvent]
    @Relationship(deleteRule: .cascade) var cursorSamples: [CursorSample]
    @Relationship(deleteRule: .cascade) var settings: RenderSettings?

    init(createdAt: Date = .now, duration: Double = 0, rawVideoFilename: String) {
        self.createdAt = createdAt
        self.duration = duration
        self.rawVideoFilename = rawVideoFilename
        self.clickEvents = []
        self.cursorSamples = []
        self.settings = RenderSettings()
    }
}
