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

    @Test func projectCreatesDefaultEditTimeline() {
        let project = Project(duration: 12, rawVideoFilename: "screen.mov")

        #expect(project.editTimeline != nil)
        #expect(project.editTimeline?.segments.count == 1)
        #expect(project.editTimeline?.segments.first?.sourceStartTime == 0)
        #expect(project.editTimeline?.segments.first?.sourceEndTime == 12)
        #expect(project.editTimeline?.exportSettings?.burnCaptions == false)
        #expect(project.editTimeline?.exportSettings?.includeAnnotations == true)
        #expect(project.editTimeline?.exportSettings?.includeSmartFocus == true)
    }

    @Test func editTimelineStoresCaptionsAnnotationsAndFocusKeyframes() {
        let project = Project(duration: 10, rawVideoFilename: "screen.mov")
        let timeline = project.editTimeline!

        timeline.annotations.append(
            AnnotationItem(
                kind: .text,
                startTime: 1,
                endTime: 4,
                normalizedX: 0.2,
                normalizedY: 0.3,
                normalizedWidth: 0.4,
                normalizedHeight: 0.1,
                text: "Hello"
            )
        )
        timeline.captions.append(
            CaptionSegment(startTime: 1, endTime: 3, text: "Hello", languageCode: "en-US", confidence: 0.95)
        )
        timeline.smartFocusKeyframes.append(
            SmartFocusKeyframe(time: 2, nx: 0.3, ny: 0.4, zoomScale: 1.8)
        )

        #expect(timeline.annotations.first?.kind == .text)
        #expect(timeline.captions.first?.text == "Hello")
        #expect(timeline.smartFocusKeyframes.first?.zoomScale == 1.8)
    }
}
