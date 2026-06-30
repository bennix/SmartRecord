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

        project.setWarnings([.missingSystemAudio, .missingMicrophoneAudio, .missingSystemAudio])

        #expect(project.warnings == [.missingMicrophoneAudio, .missingSystemAudio])
        #expect(project.warningRawValues == "missingMicrophoneAudio,missingSystemAudio")
    }

    @Test func projectInitializerDeduplicatesWarnings() {
        let project = Project(
            rawVideoFilename: "legacy.mov",
            warnings: [.missingSystemAudio, .missingMicrophoneAudio, .missingSystemAudio]
        )

        #expect(project.warnings == [.missingMicrophoneAudio, .missingSystemAudio])
        #expect(project.warningRawValues == "missingMicrophoneAudio,missingSystemAudio")
    }

    @Test func warningGetterDeduplicatesPersistedRawValues() {
        let project = Project(rawVideoFilename: "legacy.mov")

        project.warningRawValues = "missingSystemAudio,missingMicrophoneAudio,missingSystemAudio"

        #expect(project.warnings == [.missingMicrophoneAudio, .missingSystemAudio])
    }

    @Test func invalidStatusFallsBackToRecorded() {
        let project = Project(rawVideoFilename: "legacy.mov")

        project.statusRawValue = "unknown"

        #expect(project.status == .recorded)
    }

    @Test func projectStoresAudioCaptureModeAsRawValue() {
        let project = Project(rawVideoFilename: "legacy.mov", audioCaptureMode: .systemOnly)

        #expect(project.audioCaptureMode == .systemOnly)
        #expect(project.audioCaptureModeRawValue == AudioCaptureMode.systemOnly.rawValue)

        project.audioCaptureMode = .none
        #expect(project.audioCaptureModeRawValue == AudioCaptureMode.none.rawValue)
        #expect(project.audioCaptureMode == .none)
    }

    @Test func invalidAudioCaptureModeFallsBackToBoth() {
        let project = Project(rawVideoFilename: "legacy.mov")

        project.audioCaptureModeRawValue = "unknown"

        #expect(project.audioCaptureMode == .both)
    }

    @Test func projectStoresFrameRateAsRawValue() {
        let project = Project(rawVideoFilename: "legacy.mov", frameRate: .fps10)

        #expect(project.frameRate == .fps10)
        #expect(project.frameRateRawValue == 10)

        project.frameRate = .fps1
        #expect(project.frameRateRawValue == 1)
        #expect(project.frameRate == .fps1)
    }

    @Test func invalidFrameRateFallsBackToDefault() {
        let project = Project(rawVideoFilename: "legacy.mov")

        project.frameRateRawValue = 60

        #expect(project.frameRate == .default)
    }
}
