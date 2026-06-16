import AppKit
import SwiftData
import SwiftUI

@MainActor
@Observable
final class RecordingCoordinator {
    var isRecording = false
    var isStarting = false
    var lastEventCount = 0
    var permissionMissing = false
    var screenRecordingPermissionMissing = false
    var statusMessage = "准备录制"
    var failureMessage: String?
    var lastProjectDirectory: URL?
    var recordingStartedAt: Date?

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

    func startRecording() async {
        guard !isRecording, !isStarting else { return }

        isStarting = true
        failureMessage = nil
        permissionMissing = false
        screenRecordingPermissionMissing = false
        statusMessage = "正在准备录制..."

        let bundle: ProjectAssetBundle
        do {
            bundle = try assetStore.createProjectBundle()
        } catch {
            failureMessage = "无法创建项目目录：\(error.localizedDescription)"
            statusMessage = "录制启动失败"
            isStarting = false
            return
        }

        let recorder = ScreenRecorder()
        do {
            try await recorder.start(bundle: bundle)
        } catch {
            try? assetStore.removeProject(named: bundle.directoryName)
            handleStartFailure(error)
            isStarting = false
            return
        }

        let clock = RecordingClock(startTicks: mach_absolute_time())
        let buffer = MouseEventBuffer(
            screenWidth: recorder.pointSize.width,
            screenHeight: recorder.pointSize.height
        )
        let tap = MouseEventTap(buffer: buffer, clock: clock)
        permissionMissing = !tap.start()

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
        statusMessage = permissionMissing ? "正在录制，鼠标事件权限缺失" : "正在录制"
    }

    func stopRecording(context: ModelContext) async {
        guard isRecording || isStarting else { return }

        tap?.stop()
        statusMessage = "正在保存原始素材..."

        let result: ScreenRecordingResult
        do {
            guard let recorder else {
                throw ScreenRecorderError.writerFailed("录制器未启动")
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
            failureMessage = "鼠标事件缓存丢失"
            statusMessage = "录制保存失败"
            cleanupCaptureState()
            return
        }

        let project = Project(
            createdAt: startDate,
            duration: Date.now.timeIntervalSince(startDate),
            rawVideoFilename: result.bundle.screenVideo.lastPathComponent,
            assetDirectoryName: result.bundle.directoryName,
            status: .recorded
        )
        project.clickEvents = buffer.clicks.map { ClickEvent(time: $0.time, nx: $0.nx, ny: $0.ny) }
        project.cursorSamples = buffer.samples.map {
            CursorSample(time: $0.time, nx: $0.nx, ny: $0.ny, dragging: $0.dragging)
        }

        var warnings: [ProjectWarning] = []
        if permissionMissing {
            warnings.append(.missingAccessibilityPermission)
        }
        if !result.capturedSystemAudio {
            warnings.append(.missingSystemAudio)
        }
        if !result.capturedMicrophoneAudio {
            warnings.append(.missingMicrophoneAudio)
        }
        project.setWarnings(warnings)

        context.insert(project)

        do {
            try context.save()
            lastEventCount = project.clickEvents.count + project.cursorSamples.count
            lastProjectDirectory = result.bundle.directory
            statusMessage = warnings.isEmpty ? "原始素材已保存" : "原始素材已保存，有警告"
            Task { @MainActor in
                await postProcessor.process(project: project, context: context)
            }
        } catch {
            failureMessage = "项目保存失败：\(error.localizedDescription)"
            statusMessage = "录制文件已生成，项目保存失败"
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

    func regenerateSubtitles(for project: Project, context: ModelContext) {
        Task { @MainActor in
            await postProcessor.transcribeSubtitles(project: project, context: context)
        }
    }

    func openScreenRecordingSettings() {
        openPrivacySettings(anchor: "Privacy_ScreenCapture")
    }

    func openAccessibilitySettings() {
        openPrivacySettings(anchor: "Privacy_Accessibility")
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
            failureMessage = "录制启动失败：\(error.localizedDescription)"
        }
        statusMessage = screenRecordingPermissionMissing ? "需要屏幕录制权限" : "录制启动失败"
    }

    private func handleStopFailure(_ error: Error) {
        failureMessage = error.localizedDescription
        statusMessage = "录制保存失败"
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
