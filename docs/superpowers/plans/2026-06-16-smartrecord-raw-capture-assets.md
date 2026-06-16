# SmartRecord Raw Capture Assets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the fragile one-writer recording path with a reliable raw asset capture pipeline that creates a project directory containing screen video, optional system audio, optional microphone audio, and mouse metadata.

**Architecture:** This is the first implementation plan for the approved post-processing spec. It only builds the recording foundation: asset directory management, project status/warnings, separate capture outputs, and UI status. Smart Focus rendering, final H.264 export, audio mixing, and Whisper VTT are separate implementation plans that consume these raw assets.

**Tech Stack:** Swift, SwiftUI, SwiftData, ScreenCaptureKit, AVFoundation, CoreGraphics, Swift Testing, Xcode project `SmartRecord/SmartRecord.xcodeproj`.

---

## File Structure

- Create `SmartRecord/SmartRecord/Models/ProjectStatus.swift`: raw-value enum for project processing status.
- Create `SmartRecord/SmartRecord/Models/ProjectWarning.swift`: raw-value enum for non-terminal project warnings.
- Modify `SmartRecord/SmartRecord/Models/Project.swift`: store `assetDirectoryName`, status, warnings, and canonical asset filenames.
- Create `SmartRecord/SmartRecord/Capture/ProjectAssetStore.swift`: creates project directories and returns canonical URLs.
- Create `SmartRecord/SmartRecordTests/ProjectAssetStoreTests.swift`: tests path generation and generated-output cleanup.
- Create `SmartRecord/SmartRecordTests/ProjectStatusTests.swift`: tests project status and warning helpers.
- Replace `SmartRecord/SmartRecord/Capture/ScreenRecorder.swift`: split output into `screen.mov`, `system.m4a`, and `microphone.m4a`.
- Modify `SmartRecord/SmartRecord/Capture/RecordingCoordinator.swift`: use `ProjectAssetStore`, update status/warnings, save project with asset directory.
- Modify `SmartRecord/SmartRecord/ContentView.swift`: display status/warnings and reveal project directory.
- The Xcode project uses `PBXFileSystemSynchronizedRootGroup`, so new Swift files under `SmartRecord/SmartRecord` and `SmartRecord/SmartRecordTests` are picked up by their targets without manual `pbxproj` source-list edits.

## Task 1: Project Status, Warnings, and Asset Store

**Files:**
- Create: `SmartRecord/SmartRecord/Models/ProjectStatus.swift`
- Create: `SmartRecord/SmartRecord/Models/ProjectWarning.swift`
- Modify: `SmartRecord/SmartRecord/Models/Project.swift`
- Create: `SmartRecord/SmartRecord/Capture/ProjectAssetStore.swift`
- Create: `SmartRecord/SmartRecordTests/ProjectStatusTests.swift`
- Create: `SmartRecord/SmartRecordTests/ProjectAssetStoreTests.swift`

- [ ] **Step 1: Write failing status tests**

Create `SmartRecord/SmartRecordTests/ProjectStatusTests.swift`:

```swift
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
```

- [ ] **Step 2: Write failing asset store tests**

Create `SmartRecord/SmartRecordTests/ProjectAssetStoreTests.swift`:

```swift
import Foundation
import Testing
@testable import SmartRecord

struct ProjectAssetStoreTests {
    @Test func createsProjectDirectoryWithCanonicalAssetURLs() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartRecordAssetStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ProjectAssetStore(rootDirectory: root)
        let bundle = try store.createProjectBundle()

        #expect(FileManager.default.fileExists(atPath: bundle.directory.path))
        #expect(bundle.screenVideo.lastPathComponent == "screen.mov")
        #expect(bundle.systemAudio.lastPathComponent == "system.m4a")
        #expect(bundle.microphoneAudio.lastPathComponent == "microphone.m4a")
        #expect(bundle.events.lastPathComponent == "events.json")
        #expect(bundle.finalVideo.lastPathComponent == "final.mp4")
        #expect(bundle.finalVTT.lastPathComponent == "final.vtt")
    }

    @Test func removesOnlyGeneratedOutputs() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartRecordAssetStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ProjectAssetStore(rootDirectory: root)
        let bundle = try store.createProjectBundle()
        try Data("screen".utf8).write(to: bundle.screenVideo)
        try Data("video".utf8).write(to: bundle.finalVideo)
        try Data("vtt".utf8).write(to: bundle.finalVTT)

        try store.removeGeneratedOutputs(for: bundle.directoryName)

        #expect(FileManager.default.fileExists(atPath: bundle.screenVideo.path))
        #expect(!FileManager.default.fileExists(atPath: bundle.finalVideo.path))
        #expect(!FileManager.default.fileExists(atPath: bundle.finalVTT.path))
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run:

```bash
xcodebuild test -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -only-testing:SmartRecordTests/ProjectStatusTests -only-testing:SmartRecordTests/ProjectAssetStoreTests
```

Expected: compile failure because `ProjectStatus`, `ProjectWarning`, and `ProjectAssetStore` do not exist.

- [ ] **Step 4: Add project status and warning enums**

Create `SmartRecord/SmartRecord/Models/ProjectStatus.swift`:

```swift
import Foundation

enum ProjectStatus: String, Codable, CaseIterable {
    case recording
    case recorded
    case renderingVideo
    case transcribing
    case completed
    case videoFailed
    case subtitleFailed
}
```

Create `SmartRecord/SmartRecord/Models/ProjectWarning.swift`:

```swift
import Foundation

enum ProjectWarning: String, Codable, CaseIterable, Comparable, Hashable {
    case missingMicrophoneAudio
    case missingSystemAudio
    case missingAccessibilityPermission
    case whisperCommandNotInstalled

    static func < (lhs: ProjectWarning, rhs: ProjectWarning) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
```

- [ ] **Step 5: Replace Project model with status and asset directory support**

Replace `SmartRecord/SmartRecord/Models/Project.swift` with:

```swift
import Foundation
import SwiftData

@Model
final class Project {
    var createdAt: Date
    var duration: Double
    var rawVideoFilename: String
    var assetDirectoryName: String
    var statusRawValue: String
    var warningRawValues: String

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
        self.warningRawValues = warnings.sorted().map(\.rawValue).joined(separator: ",")
        self.clickEvents = []
        self.cursorSamples = []
        self.settings = RenderSettings()
    }

    var status: ProjectStatus {
        get { ProjectStatus(rawValue: statusRawValue) ?? .recorded }
        set { statusRawValue = newValue.rawValue }
    }

    var warnings: [ProjectWarning] {
        warningRawValues
            .split(separator: ",")
            .compactMap { ProjectWarning(rawValue: String($0)) }
            .sorted()
    }

    func setWarnings(_ warnings: [ProjectWarning]) {
        warningRawValues = warnings.sorted().map(\.rawValue).joined(separator: ",")
    }

    func addWarning(_ warning: ProjectWarning) {
        var next = Set(warnings)
        next.insert(warning)
        setWarnings(Array(next))
    }
}
```

- [ ] **Step 6: Add ProjectAssetStore**

Create `SmartRecord/SmartRecord/Capture/ProjectAssetStore.swift`:

```swift
import Foundation

struct ProjectAssetBundle: Equatable {
    let directoryName: String
    let directory: URL

    var screenVideo: URL { directory.appendingPathComponent("screen.mov") }
    var systemAudio: URL { directory.appendingPathComponent("system.m4a") }
    var microphoneAudio: URL { directory.appendingPathComponent("microphone.m4a") }
    var events: URL { directory.appendingPathComponent("events.json") }
    var finalVideo: URL { directory.appendingPathComponent("final.mp4") }
    var finalVTT: URL { directory.appendingPathComponent("final.vtt") }
}

struct ProjectAssetStore {
    let rootDirectory: URL

    init(rootDirectory: URL = ProjectAssetStore.defaultRootDirectory) {
        self.rootDirectory = rootDirectory
    }

    func createProjectBundle(id: UUID = UUID()) throws -> ProjectAssetBundle {
        let directoryName = id.uuidString
        let directory = rootDirectory.appendingPathComponent(directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return ProjectAssetBundle(directoryName: directoryName, directory: directory)
    }

    func bundle(named directoryName: String) -> ProjectAssetBundle {
        let directory = rootDirectory.appendingPathComponent(directoryName, isDirectory: true)
        return ProjectAssetBundle(directoryName: directoryName, directory: directory)
    }

    func removeGeneratedOutputs(for directoryName: String) throws {
        let bundle = bundle(named: directoryName)
        try removeIfPresent(bundle.finalVideo)
        try removeIfPresent(bundle.finalVTT)
    }

    func removeProject(named directoryName: String) throws {
        let directory = rootDirectory.appendingPathComponent(directoryName, isDirectory: true)
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.removeItem(at: directory)
    }

    private func removeIfPresent(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private static var defaultRootDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SmartRecord/Projects", isDirectory: true)
    }
}
```

- [ ] **Step 7: Run tests to verify they pass**

Run:

```bash
xcodebuild test -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -only-testing:SmartRecordTests/ProjectStatusTests -only-testing:SmartRecordTests/ProjectAssetStoreTests
```

Expected: `TEST SUCCEEDED`.

- [ ] **Step 8: Commit**

```bash
git add SmartRecord/SmartRecord/Models/ProjectStatus.swift \
        SmartRecord/SmartRecord/Models/ProjectWarning.swift \
        SmartRecord/SmartRecord/Models/Project.swift \
        SmartRecord/SmartRecord/Capture/ProjectAssetStore.swift \
        SmartRecord/SmartRecordTests/ProjectStatusTests.swift \
        SmartRecord/SmartRecordTests/ProjectAssetStoreTests.swift
git commit -m "feat: add project asset store and statuses"
```

## Task 2: Split Capture Output Writers

**Files:**
- Replace: `SmartRecord/SmartRecord/Capture/ScreenRecorder.swift`
- Test manually: real ScreenCaptureKit capture.

- [ ] **Step 1: Replace ScreenRecorder API**

Replace `SmartRecord/SmartRecord/Capture/ScreenRecorder.swift` with this exact implementation.

```swift
import ScreenCaptureKit
import AVFoundation
import AppKit
import CoreGraphics

enum ScreenRecorderError: LocalizedError {
    case screenCapturePermissionDenied
    case noDisplayAvailable
    case noFramesCaptured
    case writerFailed(String)

    var errorDescription: String? {
        switch self {
        case .screenCapturePermissionDenied:
            return "未获得屏幕录制权限。请在系统设置中允许 SmartRecord 录制屏幕，然后重新开始录制。"
        case .noDisplayAvailable:
            return "找不到可录制的显示器。"
        case .noFramesCaptured:
            return "录制时间太短，没有捕捉到可保存的视频帧。请至少录制 2 秒后再停止。"
        case .writerFailed(let message):
            return "录制文件写入失败：\(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .screenCapturePermissionDenied:
            return "打开 系统设置 > 隐私与安全性 > 屏幕录制，勾选 SmartRecord。若已勾选，请关闭后重新打开本应用。"
        case .noDisplayAvailable, .noFramesCaptured, .writerFailed:
            return nil
        }
    }
}

struct ScreenRecordingResult {
    let bundle: ProjectAssetBundle
    let pointSize: CGSize
    let pixelSize: CGSize
    let capturedSystemAudio: Bool
    let capturedMicrophoneAudio: Bool
}

@MainActor
final class ScreenRecorder: NSObject, SCStreamOutput {
    private var stream: SCStream?
    private var screenWriter: AVAssetWriter?
    private var systemAudioWriter: AVAssetWriter?
    private var microphoneWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var systemAudioInput: AVAssetWriterInput?
    private var microphoneInput: AVAssetWriterInput?
    private var screenSessionStarted = false
    private var systemAudioSessionStarted = false
    private var microphoneSessionStarted = false
    private var bundle: ProjectAssetBundle?

    private(set) var pointSize: CGSize = .zero
    private(set) var pixelSize: CGSize = .zero

    func start(bundle: ProjectAssetBundle) async throws {
        if !CGPreflightScreenCaptureAccess() {
            guard CGRequestScreenCaptureAccess() else {
                throw ScreenRecorderError.screenCapturePermissionDenied
            }
        }

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            let nsError = error as NSError
            if nsError.domain == "com.apple.ScreenCaptureKit.SCStreamErrorDomain" && nsError.code == -3801 {
                throw ScreenRecorderError.screenCapturePermissionDenied
            }
            throw error
        }

        guard let display = content.displays.first else {
            throw ScreenRecorderError.noDisplayAvailable
        }

        let ownWindows = content.windows.filter {
            $0.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
        }
        let filter = SCContentFilter(display: display, excludingWindows: ownWindows)

        let config = SCStreamConfiguration()
        config.width = Self.evenDimension(display.width)
        config.height = Self.evenDimension(display.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.capturesAudio = true
        config.captureMicrophone = true

        self.bundle = bundle
        self.pixelSize = CGSize(width: config.width, height: config.height)
        self.pointSize = NSScreen.main?.frame.size ?? CGSize(width: display.width, height: display.height)

        try setupWriters(bundle: bundle, size: pixelSize)

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global(qos: .userInitiated))
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global(qos: .userInitiated))
        try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: .global(qos: .userInitiated))
        self.stream = stream
        try await stream.startCapture()
    }

    func stop() async throws -> ScreenRecordingResult {
        try await stream?.stopCapture()

        guard let bundle else {
            throw ScreenRecorderError.writerFailed("缺少项目素材目录")
        }
        guard screenSessionStarted else {
            cancelWriters()
            try? FileManager.default.removeItem(at: bundle.directory)
            throw ScreenRecorderError.noFramesCaptured
        }

        videoInput?.markAsFinished()
        systemAudioInput?.markAsFinished()
        microphoneInput?.markAsFinished()

        try await finish(writer: screenWriter)
        if systemAudioSessionStarted {
            try await finish(writer: systemAudioWriter)
        } else {
            systemAudioWriter?.cancelWriting()
            try? FileManager.default.removeItem(at: bundle.systemAudio)
        }
        if microphoneSessionStarted {
            try await finish(writer: microphoneWriter)
        } else {
            microphoneWriter?.cancelWriting()
            try? FileManager.default.removeItem(at: bundle.microphoneAudio)
        }

        return ScreenRecordingResult(
            bundle: bundle,
            pointSize: pointSize,
            pixelSize: pixelSize,
            capturedSystemAudio: systemAudioSessionStarted,
            capturedMicrophoneAudio: microphoneSessionStarted
        )
    }

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        Task { @MainActor in
            self.append(sampleBuffer, type: type)
        }
    }

    private func setupWriters(bundle: ProjectAssetBundle, size: CGSize) throws {
        let codec: AVVideoCodecType = max(size.width, size.height) > 4096 ? .hevc : .h264
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height
        ]

        let screenWriter = try AVAssetWriter(outputURL: bundle.screenVideo, fileType: .mov)
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true
        screenWriter.add(videoInput)
        guard screenWriter.startWriting() else {
            throw ScreenRecorderError.writerFailed(Self.errorSummary(screenWriter.error))
        }

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44_100,
            AVEncoderBitRateKey: 128_000
        ]

        let systemAudioWriter = try AVAssetWriter(outputURL: bundle.systemAudio, fileType: .m4a)
        let systemAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        systemAudioInput.expectsMediaDataInRealTime = true
        systemAudioWriter.add(systemAudioInput)
        guard systemAudioWriter.startWriting() else {
            throw ScreenRecorderError.writerFailed(Self.errorSummary(systemAudioWriter.error))
        }

        let microphoneWriter = try AVAssetWriter(outputURL: bundle.microphoneAudio, fileType: .m4a)
        let microphoneInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        microphoneInput.expectsMediaDataInRealTime = true
        microphoneWriter.add(microphoneInput)
        guard microphoneWriter.startWriting() else {
            throw ScreenRecorderError.writerFailed(Self.errorSummary(microphoneWriter.error))
        }

        self.screenWriter = screenWriter
        self.systemAudioWriter = systemAudioWriter
        self.microphoneWriter = microphoneWriter
        self.videoInput = videoInput
        self.systemAudioInput = systemAudioInput
        self.microphoneInput = microphoneInput
    }

    private func append(_ sampleBuffer: CMSampleBuffer, type: SCStreamOutputType) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        switch type {
        case .screen:
            guard let screenWriter, let videoInput, screenWriter.status == .writing else { return }
            if !screenSessionStarted {
                screenWriter.startSession(atSourceTime: timestamp)
                screenSessionStarted = true
            }
            if videoInput.isReadyForMoreMediaData {
                _ = videoInput.append(sampleBuffer)
            }
        case .audio:
            guard let systemAudioWriter, let systemAudioInput, systemAudioWriter.status == .writing else { return }
            if !systemAudioSessionStarted {
                systemAudioWriter.startSession(atSourceTime: timestamp)
                systemAudioSessionStarted = true
            }
            if systemAudioInput.isReadyForMoreMediaData {
                _ = systemAudioInput.append(sampleBuffer)
            }
        case .microphone:
            guard let microphoneWriter, let microphoneInput, microphoneWriter.status == .writing else { return }
            if !microphoneSessionStarted {
                microphoneWriter.startSession(atSourceTime: timestamp)
                microphoneSessionStarted = true
            }
            if microphoneInput.isReadyForMoreMediaData {
                _ = microphoneInput.append(sampleBuffer)
            }
        @unknown default:
            return
        }
    }

    private func finish(writer: AVAssetWriter?) async throws {
        guard let writer else { return }
        await writer.finishWriting()
        if writer.status == .failed {
            throw ScreenRecorderError.writerFailed(Self.errorSummary(writer.error))
        }
    }

    private func cancelWriters() {
        screenWriter?.cancelWriting()
        systemAudioWriter?.cancelWriting()
        microphoneWriter?.cancelWriting()
    }

    private static func evenDimension(_ value: Int) -> Int {
        max(2, value - value % 2)
    }

    private static func errorSummary(_ error: Error?) -> String {
        guard let error else { return "未知写入错误" }
        let nsError = error as NSError
        var parts = ["\(nsError.domain) \(nsError.code)", nsError.localizedDescription]
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            parts.append("底层错误：\(underlying.domain) \(underlying.code) \(underlying.localizedDescription)")
        }
        return parts.joined(separator: "；")
    }
}
```

- [ ] **Step 2: Build to catch API errors**

Run:

```bash
xcodebuild -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -configuration Debug build
```

Expected: build fails because `RecordingCoordinator` still calls the old `start() -> URL` and `stop()` API.

- [ ] **Step 3: Commit is skipped until coordinator is updated**

Do not commit this task by itself if the app does not compile. Continue to Task 3.

## Task 3: Coordinator Uses Project Asset Store

**Files:**
- Modify: `SmartRecord/SmartRecord/Capture/RecordingCoordinator.swift`
- Modify: `SmartRecord/SmartRecord/ContentView.swift`

- [ ] **Step 1: Update RecordingCoordinator to create bundles and persist status**

Replace `SmartRecord/SmartRecord/Capture/RecordingCoordinator.swift` with:

```swift
import SwiftUI
import SwiftData
import AppKit

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

    private let assetStore = ProjectAssetStore()
    private var activeBundle: ProjectAssetBundle?
    private var recorder: ScreenRecorder?
    private var tap: MouseEventTap?
    private var buffer: MouseEventBuffer?
    private var clock: RecordingClock?
    private var startDate = Date.now

    func startRecording() async {
        guard !isRecording, !isStarting else { return }

        isStarting = true
        failureMessage = nil
        screenRecordingPermissionMissing = false
        permissionMissing = false
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
        let buf = MouseEventBuffer(screenWidth: recorder.pointSize.width, screenHeight: recorder.pointSize.height)
        let tap = MouseEventTap(buffer: buf, clock: clock)
        permissionMissing = !tap.start()

        self.activeBundle = bundle
        self.recorder = recorder
        self.clock = clock
        self.buffer = buf
        self.tap = tap
        self.startDate = .now
        self.recordingStartedAt = startDate
        self.lastProjectDirectory = bundle.directory
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
            guard let recorder else { throw ScreenRecorderError.writerFailed("录制器未启动") }
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

        guard let buf = buffer else {
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
        project.clickEvents = buf.clicks.map { ClickEvent(time: $0.time, nx: $0.nx, ny: $0.ny) }
        project.cursorSamples = buf.samples.map {
            CursorSample(time: $0.time, nx: $0.nx, ny: $0.ny, dragging: $0.dragging)
        }

        var warnings: [ProjectWarning] = []
        if permissionMissing { warnings.append(.missingAccessibilityPermission) }
        if !result.capturedSystemAudio { warnings.append(.missingSystemAudio) }
        if !result.capturedMicrophoneAudio { warnings.append(.missingMicrophoneAudio) }
        project.setWarnings(warnings)

        context.insert(project)

        do {
            try context.save()
            lastEventCount = project.clickEvents.count + project.cursorSamples.count
            lastProjectDirectory = result.bundle.directory
            statusMessage = warnings.isEmpty ? "原始素材已保存" : "原始素材已保存，有警告"
        } catch {
            failureMessage = "项目保存失败：\(error.localizedDescription)"
            statusMessage = "录制文件已生成，项目保存失败"
        }

        cleanupCaptureState()
    }

    func recordingBundle(for project: Project) -> ProjectAssetBundle {
        assetStore.bundle(named: project.assetDirectoryName)
    }

    func revealLastProject() {
        guard let lastProjectDirectory else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastProjectDirectory])
    }

    func reveal(project: Project) {
        NSWorkspace.shared.activateFileViewerSelecting([recordingBundle(for: project).directory])
    }

    func openScreenRecordingSettings() {
        openPrivacySettings(anchor: "Privacy_ScreenCapture")
    }

    func openAccessibilitySettings() {
        openPrivacySettings(anchor: "Privacy_Accessibility")
    }

    private func handleStartFailure(_ error: Error) {
        let nsError = error as NSError
        if error is ScreenRecorderError || (nsError.domain == "com.apple.ScreenCaptureKit.SCStreamErrorDomain" && nsError.code == -3801) {
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
        clock = nil
        buffer = nil
        tap = nil
    }

    private func openPrivacySettings(anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }
}
```

- [ ] **Step 2: Update ContentView references from file URL to bundle directory**

In `SmartRecord/SmartRecord/ContentView.swift`, replace calls to removed APIs:

Replace:

```swift
if let lastURL = coordinator.lastRecordingURL, !coordinator.isRecording {
    Button {
        coordinator.revealLastRecording()
    } label: {
        Label(lastURL.lastPathComponent, systemImage: "folder")
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    .buttonStyle(.borderless)
}
```

with:

```swift
if let lastProjectDirectory = coordinator.lastProjectDirectory, !coordinator.isRecording {
    Button {
        coordinator.revealLastProject()
    } label: {
        Label(lastProjectDirectory.lastPathComponent, systemImage: "folder")
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    .buttonStyle(.borderless)
}
```

If this call remains elsewhere:

```swift
coordinator.revealLastRecording()
```

with:

```swift
coordinator.revealLastProject()
```

Replace:

```swift
coordinator.recordingFileURL(for: project)
```

with:

```swift
coordinator.recordingBundle(for: project).screenVideo
```

Replace delete logic with:

```swift
private func delete(_ project: Project) {
    let bundle = coordinator.recordingBundle(for: project)
    try? FileManager.default.removeItem(at: bundle.directory)
    context.delete(project)
    try? context.save()
}
```

- [ ] **Step 3: Add status and warning display to project rows**

In `projectRow(_:)`, include these tags in the existing tag `HStack`:

```swift
tag(project.status.rawValue, icon: "circle.dashed")
if !project.warnings.isEmpty {
    tag("\(project.warnings.count) 警告", icon: "exclamationmark.triangle")
}
```

- [ ] **Step 4: Build**

Run:

```bash
xcodebuild -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -configuration Debug build
```

Expected: `BUILD SUCCEEDED`, with at most the existing `CMSampleBuffer` Sendable warning.

- [ ] **Step 5: Run tests**

Run:

```bash
xcodebuild test -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord
```

Expected: `TEST SUCCEEDED`.

- [ ] **Step 6: Commit**

```bash
git add SmartRecord/SmartRecord/Capture/ScreenRecorder.swift \
        SmartRecord/SmartRecord/Capture/RecordingCoordinator.swift \
        SmartRecord/SmartRecord/ContentView.swift
git commit -m "feat: record raw assets into project bundles"
```

## Task 4: Manual Recording Verification

**Files:**
- No source changes expected.
- Manual output: one project directory under `~/Library/Application Support/SmartRecord/Projects/`.

- [ ] **Step 1: Build the app**

Run:

```bash
xcodebuild -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -configuration Debug build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 2: Launch the built app**

Run:

```bash
open ~/Library/Developer/Xcode/DerivedData/SmartRecord-gzfxfqjxkuibqvbeflvsrjxzirmw/Build/Products/Debug/SmartRecord.app
```

Expected: SmartRecord opens.

- [ ] **Step 3: Record for at least 5 seconds**

Manual steps:

1. Click `开始录制`.
2. Speak into the microphone.
3. Play a short system sound.
4. Move the mouse and click at least twice.
5. Wait at least 5 seconds.
6. Click `停止并保存`.

Expected UI result:

- Status becomes `原始素材已保存` or `原始素材已保存，有警告`.
- A project appears in the project list.
- The project row shows status `recorded`.

- [ ] **Step 4: Verify files exist**

Run:

```bash
find "$HOME/Library/Application Support/SmartRecord/Projects" -maxdepth 2 -type f | sort | tail -20
```

Expected:

- One recent `screen.mov`.
- `system.m4a` if system audio was captured.
- `microphone.m4a` if microphone audio was captured.

- [ ] **Step 5: Verify screen video is playable**

Run this against the newest screen file:

```bash
SCREEN_FILE="$(find "$HOME/Library/Application Support/SmartRecord/Projects" -name screen.mov -type f -print0 | xargs -0 ls -t | head -1)"
mdls -name kMDItemCodecs -name kMDItemPixelHeight -name kMDItemPixelWidth "$SCREEN_FILE"
```

Expected:

```text
kMDItemCodecs = (
    "H.264"
)
```

or:

```text
kMDItemCodecs = (
    HEVC
)
```

Width and height are non-zero.

- [ ] **Step 6: Verify optional audio files**

Run:

```bash
PROJECT_DIR="$(dirname "$SCREEN_FILE")"
ls -lh "$PROJECT_DIR"
```

Expected:

- `screen.mov` is non-empty.
- `microphone.m4a` is present and non-empty if microphone permission and input are available.
- `system.m4a` is present and non-empty if system audio capture is available.

- [ ] **Step 7: Commit any manual-verification fixes**

If manual verification required small fixes, run the build and tests again, then commit:

```bash
xcodebuild -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -configuration Debug build
xcodebuild test -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord
git add SmartRecord/SmartRecord SmartRecord/SmartRecordTests
git commit -m "fix: stabilize raw capture verification"
```

If no fixes were needed, do not create an empty commit.

## Out of Scope for This Plan

- Smart Focus solver and frame renderer.
- Audio mixing into final AAC.
- H.264 `final.mp4` export.
- Local Whisper medium integration.
- VTT generation.
- Burned-in subtitles.

These are separate plans built on top of the raw asset directory and status model created here.
