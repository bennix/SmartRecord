import Foundation
import SwiftData

@Model
final class Project {
    var createdAt: Date
    var duration: Double
    var rawVideoFilename: String
    var assetDirectoryName: String = ""
    var statusRawValue: String = ProjectStatus.recorded.rawValue
    var warningRawValues: String = ""

    @Relationship(deleteRule: .cascade) var clickEvents: [ClickEvent]
    @Relationship(deleteRule: .cascade) var cursorSamples: [CursorSample]
    @Relationship(deleteRule: .cascade) var settings: RenderSettings?

    init(
        createdAt: Date = .now,
        duration: Double = 0,
        rawVideoFilename: String,
        assetDirectoryName: String = "",
        status: ProjectStatus = .recorded,
        warnings: [ProjectWarning] = []
    ) {
        self.createdAt = createdAt
        self.duration = duration
        self.rawVideoFilename = rawVideoFilename
        self.assetDirectoryName = assetDirectoryName
        self.statusRawValue = status.rawValue
        self.warningRawValues = Self.serializeWarnings(warnings)
        self.clickEvents = []
        self.cursorSamples = []
        self.settings = RenderSettings()
    }

    var status: ProjectStatus {
        get { ProjectStatus(rawValue: statusRawValue) ?? .recorded }
        set { statusRawValue = newValue.rawValue }
    }

    var warnings: [ProjectWarning] {
        Self.normalizeWarnings(
            warningRawValues
                .split(separator: ",")
                .compactMap { ProjectWarning(rawValue: String($0)) }
        )
    }

    func setWarnings(_ warnings: [ProjectWarning]) {
        warningRawValues = Self.serializeWarnings(warnings)
    }

    func addWarning(_ warning: ProjectWarning) {
        var next = Set(warnings)
        next.insert(warning)
        setWarnings(Array(next))
    }

    private static func normalizeWarnings(_ warnings: [ProjectWarning]) -> [ProjectWarning] {
        Set(warnings).sorted()
    }

    private static func serializeWarnings(_ warnings: [ProjectWarning]) -> String {
        normalizeWarnings(warnings).map(\.rawValue).joined(separator: ",")
    }
}
