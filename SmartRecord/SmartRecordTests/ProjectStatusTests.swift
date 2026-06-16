import Testing
@testable import SmartRecord

struct ProjectStatusTests {
    @Test func projectStoresStatusAsRawValue() {
        let project = Project(rawVideoFilename: "legacy.mov")
        #expect(project.status == .recorded)

        project.status = .renderingVideo
        #expect(project.statusRawValue == ProjectStatus.renderingVideo.rawValue)
        #expect(project.status == .renderingVideo)
    }

    @Test func projectStoresWarningsAsSortedRawValues() {
        let project = Project(rawVideoFilename: "legacy.mov")

        project.setWarnings([.missingMicrophoneAudio, .missingSystemAudio])

        #expect(project.warnings == [.missingMicrophoneAudio, .missingSystemAudio])
        #expect(project.warningRawValues == "missingMicrophoneAudio,missingSystemAudio")
    }

    @Test func invalidStatusFallsBackToRecorded() {
        let project = Project(rawVideoFilename: "legacy.mov")

        project.statusRawValue = "unknown"

        #expect(project.status == .recorded)
    }
}
