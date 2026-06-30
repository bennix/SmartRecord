import AppKit
import SwiftData
import SwiftUI

@MainActor
@Observable
final class RecordingCoordinator {
    var isRecording = false
    var isStarting = false
    var lastEventCount = 0
    var screenRecordingPermissionMissing = false
    var statusMessage = AppStrings.current(.preparingRecording)
    var failureMessage: String?
    var lastProjectDirectory: URL?
    var recordingStartedAt: Date?
    var selectedAudioMode: AudioCaptureMode = .both
    var selectedFrameRate: RecordingFrameRate = .default

    private let assetStore: ProjectAssetStore
    private let postProcessor = PostProcessingCoordinator()
    private var activeBundle: ProjectAssetBundle?
    private var recorder: ScreenRecorder?
    private var tap: MouseEventTap?
    private var buffer: MouseEventBuffer?
    private var clock: RecordingClock?
    private var startDate = Date.now

    init(assetStore: ProjectAssetStore = ProjectAssetStore()) {
        self.assetStore = assetStore
    }

    func refreshLocalizedText() {
        if isStarting {
            statusMessage = AppStrings.current(.preparingRecordingLong)
        } else if isRecording {
            statusMessage = AppStrings.current(.recording)
        } else if failureMessage == nil {
            statusMessage = AppStrings.current(.preparingRecording)
        }
    }

    func startRecording() async {
        guard !isRecording, !isStarting else { return }

        isStarting = true
        failureMessage = nil
        screenRecordingPermissionMissing = false
        statusMessage = AppStrings.current(.preparingRecordingLong)

        let bundle: ProjectAssetBundle
        do {
            bundle = try assetStore.createProjectBundle()
        } catch {
            failureMessage = AppStrings.current.startFailedWithDetail(error.localizedDescription)
            statusMessage = AppStrings.current(.startFailed)
            isStarting = false
            return
        }

        let recorder = ScreenRecorder()
        do {
            try await recorder.start(
                bundle: bundle,
                audioMode: selectedAudioMode,
                frameRate: selectedFrameRate
            )
        } catch {
            try? assetStore.removeProject(named: bundle.directoryName)
            handleStartFailure(error)
            isStarting = false
            return
        }

        let clock = RecordingClock(startTicks: mach_absolute_time())
        let buffer = MouseEventBuffer(
            screenFrame: recorder.displayFrame
        )
        let tap = MouseEventTap(buffer: buffer, clock: clock)
        tap.start()

        activeBundle = bundle
        self.recorder = recorder
        self.tap = tap
        self.buffer = buffer
        self.clock = clock
        startDate = .now
        recordingStartedAt = startDate
        lastProjectDirectory = bundle.directory
        isRecording = true
        isStarting = false
        statusMessage = AppStrings.current(.recording)
    }

    func stopRecording(context: ModelContext) async {
        guard isRecording || isStarting else { return }

        tap?.stop()
        statusMessage = AppStrings.current(.savingRawAssets)

        let result: ScreenRecordingResult
        do {
            guard let recorder else {
                throw ScreenRecorderError.writerFailed(AppStrings.current(.recorderNotStarted))
            }
            result = try await recorder.stop()
        } catch {
            handleStopFailure(error)
            if let activeBundle {
                try? assetStore.removeProject(named: activeBundle.directoryName)
            }
            isRecording = false
            isStarting = false
            recordingStartedAt = nil
            cleanupCaptureState()
            return
        }

        isRecording = false
        isStarting = false
        recordingStartedAt = nil

        guard let buffer else {
            failureMessage = AppStrings.current(.mouseEventCacheLost)
            statusMessage = AppStrings.current(.saveFailed)
            cleanupCaptureState()
            return
        }

        let project = Project(
            createdAt: startDate,
            duration: Date.now.timeIntervalSince(startDate),
            rawVideoFilename: result.bundle.screenVideo.lastPathComponent,
            assetDirectoryName: result.bundle.directoryName,
            audioCaptureMode: selectedAudioMode,
            frameRate: result.frameRate,
            status: .recorded
        )
        project.clickEvents = buffer.clicks.map { ClickEvent(time: $0.time, nx: $0.nx, ny: $0.ny) }
        project.cursorSamples = buffer.samples.map {
            CursorSample(time: $0.time, nx: $0.nx, ny: $0.ny, dragging: $0.dragging)
        }

        var warnings: [ProjectWarning] = []
        if selectedAudioMode.capturesSystemAudio && !result.capturedSystemAudio {
            warnings.append(.missingSystemAudio)
        }
        if selectedAudioMode.capturesMicrophone && !result.capturedMicrophoneAudio {
            warnings.append(.missingMicrophoneAudio)
        }
        project.setWarnings(warnings)

        context.insert(project)

        do {
            try context.save()
            lastEventCount = project.clickEvents.count + project.cursorSamples.count
            lastProjectDirectory = result.bundle.directory
            statusMessage = warnings.isEmpty ? AppStrings.current(.rawAssetsSaved) : AppStrings.current(.rawAssetsSavedWithWarnings)
            Task { @MainActor in
                await postProcessor.process(project: project, context: context)
            }
        } catch {
            failureMessage = AppStrings.current.projectSaveFailed(error.localizedDescription)
            statusMessage = AppStrings.current(.fileGeneratedProjectSaveFailed)
        }

        cleanupCaptureState()
    }

    func recordingBundle(for project: Project) -> ProjectAssetBundle? {
        guard !project.assetDirectoryName.isEmpty else { return nil }
        return try? assetStore.bundle(named: project.assetDirectoryName)
    }

    func revealLastProject() {
        guard let lastProjectDirectory else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastProjectDirectory])
    }

    func reveal(project: Project) {
        guard let bundle = recordingBundle(for: project) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([bundle.directory])
    }

    func open(project: Project) {
        guard let bundle = recordingBundle(for: project) else { return }
        let url = FileManager.default.fileExists(atPath: bundle.finalVideo.path)
            ? bundle.finalVideo
            : bundle.screenVideo
        NSWorkspace.shared.open(url)
    }

    func regenerateVideo(for project: Project, context: ModelContext) {
        Task { @MainActor in
            await postProcessor.renderFinalVideo(project: project, context: context)
        }
    }

    func openScreenRecordingSettings() {
        openPrivacySettings(anchor: "Privacy_ScreenCapture")
    }

    private func handleStartFailure(_ error: Error) {
        let nsError = error as NSError
        if error is ScreenRecorderError || isScreenCapturePermissionError(nsError) {
            screenRecordingPermissionMissing = true
        }

        let recovery = nsError.localizedRecoverySuggestion
        if let recovery, !recovery.isEmpty {
            failureMessage = "\(error.localizedDescription)\n\(recovery)"
        } else {
            failureMessage = AppStrings.current.startFailedWithDetail(error.localizedDescription)
        }
        statusMessage = screenRecordingPermissionMissing ? AppStrings.current(.screenPermissionStatus) : AppStrings.current(.startFailed)
    }

    private func handleStopFailure(_ error: Error) {
        failureMessage = error.localizedDescription
        statusMessage = AppStrings.current(.saveFailed)
        lastProjectDirectory = nil
    }

    private func cleanupCaptureState() {
        activeBundle = nil
        recorder = nil
        tap = nil
        buffer = nil
        clock = nil
    }

    private func openPrivacySettings(anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func isScreenCapturePermissionError(_ error: NSError) -> Bool {
        error.domain == "com.apple.ScreenCaptureKit.SCStreamErrorDomain" && error.code == -3801
    }
}
