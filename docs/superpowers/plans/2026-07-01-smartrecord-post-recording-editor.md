# SmartRecord Post-Recording Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a non-destructive post-recording editor with trimming, cut/delete segments, annotations, editable SmartFocus keyframes, Apple on-device project captions, and H.264 export with optional burned captions.

**Architecture:** Add a SwiftData timeline model under each `Project`, keep raw assets immutable, and route editing/export through pure timeline mapping utilities plus AVFoundation/Core Image renderers. UI is a lightweight single-window editor launched from the project list; speech recognition is a manually triggered, local-only service that writes project-internal caption segments.

**Tech Stack:** SwiftUI, SwiftData, AVFoundation, Core Image, AppKit image/file panels, Apple Speech framework or current macOS on-device speech transcription API, Swift Testing.

---

## Preflight For The Implementer

The repository may already contain staged App Store cleanup changes that remove the previous transcription toolchain. Finish or isolate those changes before starting this plan. Do not mix those cleanup changes with editor implementation commits.

Recommended start:

```bash
git status --short --branch
git worktree add .worktrees/post-recording-editor -b codex/post-recording-editor
cd .worktrees/post-recording-editor
```

Run the baseline tests before Task 1:

```bash
xcodebuild test -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -destination 'platform=macOS,arch=arm64'
```

Expected: `** TEST SUCCEEDED **`.

## File Structure

Create focused files rather than expanding `ContentView.swift` or `VideoExporter.swift` indefinitely.

- `SmartRecord/SmartRecord/Models/EditTimeline.swift`: root SwiftData model for editor state.
- `SmartRecord/SmartRecord/Models/EditSegment.swift`: non-destructive source time ranges.
- `SmartRecord/SmartRecord/Models/AnnotationItem.swift`: annotation model and kind enum.
- `SmartRecord/SmartRecord/Models/SmartFocusKeyframe.swift`: editable SmartFocus points.
- `SmartRecord/SmartRecord/Models/CaptionSegment.swift`: project-internal caption rows.
- `SmartRecord/SmartRecord/Models/ExportSettings.swift`: export toggles.
- `SmartRecord/SmartRecord/Editing/TimelineMapper.swift`: pure source-time/timeline-time conversion.
- `SmartRecord/SmartRecord/Editing/TimelineEditing.swift`: split, delete, trim helpers.
- `SmartRecord/SmartRecord/Editing/AnnotationRenderer.swift`: Core Image overlay drawing.
- `SmartRecord/SmartRecord/Editing/EditorPreviewController.swift`: lightweight current-frame preview.
- `SmartRecord/SmartRecord/PostProcessing/EditedVideoExporter.swift`: timeline-aware H.264 exporter.
- `SmartRecord/SmartRecord/Speech/LocalSpeechCaptioner.swift`: local-only caption generation boundary.
- `SmartRecord/SmartRecord/UI/Editor/RecordingEditorView.swift`: editor shell.
- `SmartRecord/SmartRecord/UI/Editor/EditorTimelineView.swift`: timeline tracks and segment edge edits.
- `SmartRecord/SmartRecord/UI/Editor/EditorInspectorView.swift`: selected item properties.
- `SmartRecord/SmartRecord/UI/Editor/CaptionEditorView.swift`: caption mode.
- `SmartRecord/SmartRecord/UI/Editor/AnnotationToolbar.swift`: annotation tools.
- `SmartRecord/SmartRecordTests/TimelineMapperTests.swift`
- `SmartRecord/SmartRecordTests/TimelineEditingTests.swift`
- `SmartRecord/SmartRecordTests/EditedVideoExporterTests.swift`
- `SmartRecord/SmartRecordTests/AnnotationRendererTests.swift`
- `SmartRecord/SmartRecordTests/LocalSpeechCaptionerTests.swift`

## Task 1: Timeline SwiftData Models

**Files:**
- Create: `SmartRecord/SmartRecord/Models/EditTimeline.swift`
- Create: `SmartRecord/SmartRecord/Models/EditSegment.swift`
- Create: `SmartRecord/SmartRecord/Models/AnnotationItem.swift`
- Create: `SmartRecord/SmartRecord/Models/SmartFocusKeyframe.swift`
- Create: `SmartRecord/SmartRecord/Models/CaptionSegment.swift`
- Create: `SmartRecord/SmartRecord/Models/ExportSettings.swift`
- Modify: `SmartRecord/SmartRecord/Models/Project.swift`
- Modify: `SmartRecord/SmartRecord/SmartRecordApp.swift`
- Test: `SmartRecord/SmartRecordTests/ProjectStatusTests.swift`

- [ ] **Step 1: Write failing model relationship tests**

Add this test to `SmartRecord/SmartRecordTests/ProjectStatusTests.swift`:

```swift
@Test func projectCreatesDefaultEditTimeline() {
    let project = Project(rawVideoFilename: "screen.mov", duration: 12)

    #expect(project.editTimeline != nil)
    #expect(project.editTimeline?.segments.count == 1)
    #expect(project.editTimeline?.segments.first?.sourceStartTime == 0)
    #expect(project.editTimeline?.segments.first?.sourceEndTime == 12)
    #expect(project.editTimeline?.exportSettings?.burnCaptions == false)
    #expect(project.editTimeline?.exportSettings?.includeAnnotations == true)
    #expect(project.editTimeline?.exportSettings?.includeSmartFocus == true)
}

@Test func editTimelineStoresCaptionsAnnotationsAndFocusKeyframes() {
    let project = Project(rawVideoFilename: "screen.mov", duration: 10)
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
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
xcodebuild test -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -destination 'platform=macOS,arch=arm64' -only-testing:SmartRecordTests/ProjectStatusTests
```

Expected: compile fails because `editTimeline`, `EditTimeline`, `AnnotationItem`, `CaptionSegment`, and `SmartFocusKeyframe` do not exist.

- [ ] **Step 3: Create model files**

Create `SmartRecord/SmartRecord/Models/EditSegment.swift`:

```swift
import Foundation
import SwiftData

@Model
final class EditSegment {
    var sourceStartTime: Double
    var sourceEndTime: Double
    var timelineStartTime: Double
    var isEnabled: Bool

    init(sourceStartTime: Double, sourceEndTime: Double, timelineStartTime: Double = 0, isEnabled: Bool = true) {
        self.sourceStartTime = max(0, sourceStartTime)
        self.sourceEndTime = max(self.sourceStartTime, sourceEndTime)
        self.timelineStartTime = max(0, timelineStartTime)
        self.isEnabled = isEnabled
    }

    var duration: Double {
        max(0, sourceEndTime - sourceStartTime)
    }
}
```

Create `SmartRecord/SmartRecord/Models/ExportSettings.swift`:

```swift
import Foundation
import SwiftData

enum ExportDestinationMode: String, Codable, CaseIterable {
    case updateFinalVideo
    case saveCopy
}

@Model
final class ExportSettings {
    var burnCaptions: Bool
    var includeAnnotations: Bool
    var includeSmartFocus: Bool
    var destinationModeRawValue: String

    init(
        burnCaptions: Bool = false,
        includeAnnotations: Bool = true,
        includeSmartFocus: Bool = true,
        destinationMode: ExportDestinationMode = .updateFinalVideo
    ) {
        self.burnCaptions = burnCaptions
        self.includeAnnotations = includeAnnotations
        self.includeSmartFocus = includeSmartFocus
        self.destinationModeRawValue = destinationMode.rawValue
    }

    var destinationMode: ExportDestinationMode {
        get { ExportDestinationMode(rawValue: destinationModeRawValue) ?? .updateFinalVideo }
        set { destinationModeRawValue = newValue.rawValue }
    }
}
```

Create `SmartRecord/SmartRecord/Models/AnnotationItem.swift`:

```swift
import Foundation
import SwiftData

enum AnnotationKind: String, Codable, CaseIterable {
    case text
    case arrow
    case highlightRectangle
    case highlightEllipse
    case blur
    case image
}

@Model
final class AnnotationItem {
    var kindRawValue: String
    var startTime: Double
    var endTime: Double
    var normalizedX: Double
    var normalizedY: Double
    var normalizedWidth: Double
    var normalizedHeight: Double
    var text: String
    var assetFilename: String?
    var zIndex: Int
    var colorHex: String
    var opacity: Double
    var blurRadius: Double

    init(
        kind: AnnotationKind,
        startTime: Double,
        endTime: Double,
        normalizedX: Double,
        normalizedY: Double,
        normalizedWidth: Double,
        normalizedHeight: Double,
        text: String = "",
        assetFilename: String? = nil,
        zIndex: Int = 0,
        colorHex: String = "#0B65C2",
        opacity: Double = 1,
        blurRadius: Double = 12
    ) {
        self.kindRawValue = kind.rawValue
        self.startTime = max(0, startTime)
        self.endTime = max(self.startTime, endTime)
        self.normalizedX = min(max(normalizedX, 0), 1)
        self.normalizedY = min(max(normalizedY, 0), 1)
        self.normalizedWidth = min(max(normalizedWidth, 0), 1)
        self.normalizedHeight = min(max(normalizedHeight, 0), 1)
        self.text = text
        self.assetFilename = assetFilename
        self.zIndex = zIndex
        self.colorHex = colorHex
        self.opacity = min(max(opacity, 0), 1)
        self.blurRadius = max(0, blurRadius)
    }

    var kind: AnnotationKind {
        get { AnnotationKind(rawValue: kindRawValue) ?? .text }
        set { kindRawValue = newValue.rawValue }
    }
}
```

Create `SmartRecord/SmartRecord/Models/SmartFocusKeyframe.swift`:

```swift
import Foundation
import SwiftData

enum SmartFocusKeyframeSource: String, Codable, CaseIterable {
    case detectedClick
    case userEdited
}

@Model
final class SmartFocusKeyframe {
    var time: Double
    var nx: Double
    var ny: Double
    var zoomScale: Double
    var holdDuration: Double
    var transitionDuration: Double
    var sourceRawValue: String

    init(
        time: Double,
        nx: Double,
        ny: Double,
        zoomScale: Double,
        holdDuration: Double = 1.2,
        transitionDuration: Double = 0.25,
        source: SmartFocusKeyframeSource = .userEdited
    ) {
        self.time = max(0, time)
        self.nx = min(max(nx, 0), 1)
        self.ny = min(max(ny, 0), 1)
        self.zoomScale = min(max(zoomScale, 1), 2.4)
        self.holdDuration = max(0.1, holdDuration)
        self.transitionDuration = max(0.05, transitionDuration)
        self.sourceRawValue = source.rawValue
    }

    var source: SmartFocusKeyframeSource {
        get { SmartFocusKeyframeSource(rawValue: sourceRawValue) ?? .userEdited }
        set { sourceRawValue = newValue.rawValue }
    }
}
```

Create `SmartRecord/SmartRecord/Models/CaptionSegment.swift`:

```swift
import Foundation
import SwiftData

@Model
final class CaptionSegment {
    var startTime: Double
    var endTime: Double
    var text: String
    var languageCode: String
    var confidence: Double
    var isEnabled: Bool

    init(
        startTime: Double,
        endTime: Double,
        text: String,
        languageCode: String,
        confidence: Double = 0,
        isEnabled: Bool = true
    ) {
        self.startTime = max(0, startTime)
        self.endTime = max(self.startTime, endTime)
        self.text = text
        self.languageCode = languageCode
        self.confidence = min(max(confidence, 0), 1)
        self.isEnabled = isEnabled
    }
}
```

Create `SmartRecord/SmartRecord/Models/EditTimeline.swift`:

```swift
import Foundation
import SwiftData

@Model
final class EditTimeline {
    @Relationship(deleteRule: .cascade) var segments: [EditSegment]
    @Relationship(deleteRule: .cascade) var annotations: [AnnotationItem]
    @Relationship(deleteRule: .cascade) var smartFocusKeyframes: [SmartFocusKeyframe]
    @Relationship(deleteRule: .cascade) var captions: [CaptionSegment]
    @Relationship(deleteRule: .cascade) var exportSettings: ExportSettings?

    init(sourceDuration: Double) {
        self.segments = [EditSegment(sourceStartTime: 0, sourceEndTime: max(0, sourceDuration))]
        self.annotations = []
        self.smartFocusKeyframes = []
        self.captions = []
        self.exportSettings = ExportSettings()
    }
}
```

- [ ] **Step 4: Attach timeline to project and schema**

Modify `SmartRecord/SmartRecord/Models/Project.swift`:

```swift
@Relationship(deleteRule: .cascade) var settings: RenderSettings?
@Relationship(deleteRule: .cascade) var editTimeline: EditTimeline?
```

Inside `Project.init`, after `self.settings = RenderSettings()` add:

```swift
self.editTimeline = EditTimeline(sourceDuration: duration)
```

Modify `SmartRecord/SmartRecord/SmartRecordApp.swift` schema:

```swift
let schema = Schema([
    Project.self,
    ClickEvent.self,
    CursorSample.self,
    RenderSettings.self,
    EditTimeline.self,
    EditSegment.self,
    AnnotationItem.self,
    SmartFocusKeyframe.self,
    CaptionSegment.self,
    ExportSettings.self
])
```

- [ ] **Step 5: Run model tests**

Run:

```bash
xcodebuild test -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -destination 'platform=macOS,arch=arm64' -only-testing:SmartRecordTests/ProjectStatusTests
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add SmartRecord/SmartRecord/Models SmartRecord/SmartRecord/SmartRecordApp.swift SmartRecord/SmartRecordTests/ProjectStatusTests.swift
git commit -m "feat: add edit timeline models"
```

## Task 2: Timeline Mapping And Editing Helpers

**Files:**
- Create: `SmartRecord/SmartRecord/Editing/TimelineMapper.swift`
- Create: `SmartRecord/SmartRecord/Editing/TimelineEditing.swift`
- Test: `SmartRecord/SmartRecordTests/TimelineMapperTests.swift`
- Test: `SmartRecord/SmartRecordTests/TimelineEditingTests.swift`

- [ ] **Step 1: Write failing mapper tests**

Create `SmartRecord/SmartRecordTests/TimelineMapperTests.swift`:

```swift
import Testing
@testable import SmartRecord

struct TimelineMapperTests {
    @Test func mapsSourceTimesAcrossDeletedMiddleSegment() {
        let segments = [
            EditSegment(sourceStartTime: 0, sourceEndTime: 5, timelineStartTime: 0),
            EditSegment(sourceStartTime: 8, sourceEndTime: 12, timelineStartTime: 5)
        ]
        let mapper = TimelineMapper(segments: segments)

        #expect(mapper.timelineTime(forSourceTime: 2) == 2)
        #expect(mapper.timelineTime(forSourceTime: 9) == 6)
        #expect(mapper.timelineTime(forSourceTime: 6) == nil)
        #expect(mapper.sourceTime(forTimelineTime: 6.5) == 9.5)
    }

    @Test func normalizesTimelineStartsFromEnabledSegments() {
        let segments = [
            EditSegment(sourceStartTime: 3, sourceEndTime: 7, timelineStartTime: 99),
            EditSegment(sourceStartTime: 10, sourceEndTime: 12, timelineStartTime: 0, isEnabled: false),
            EditSegment(sourceStartTime: 20, sourceEndTime: 25, timelineStartTime: 1)
        ]

        let normalized = TimelineMapper.normalizedSegments(from: segments)

        #expect(normalized.count == 2)
        #expect(normalized[0].timelineStartTime == 0)
        #expect(normalized[1].timelineStartTime == 4)
    }
}
```

- [ ] **Step 2: Write failing editing tests**

Create `SmartRecord/SmartRecordTests/TimelineEditingTests.swift`:

```swift
import Testing
@testable import SmartRecord

struct TimelineEditingTests {
    @Test func splitSegmentCreatesTwoSourceRanges() {
        let segment = EditSegment(sourceStartTime: 0, sourceEndTime: 10, timelineStartTime: 0)

        let result = TimelineEditing.split(segment, atTimelineTime: 4)

        #expect(result.left.sourceStartTime == 0)
        #expect(result.left.sourceEndTime == 4)
        #expect(result.right.sourceStartTime == 4)
        #expect(result.right.sourceEndTime == 10)
        #expect(result.right.timelineStartTime == 4)
    }

    @Test func trimEdgesClampsInsideOriginalRange() {
        let segment = EditSegment(sourceStartTime: 5, sourceEndTime: 15, timelineStartTime: 0)

        TimelineEditing.trim(segment, newSourceStartTime: 8, newSourceEndTime: 20)

        #expect(segment.sourceStartTime == 8)
        #expect(segment.sourceEndTime == 15)
    }
}
```

- [ ] **Step 3: Run tests and verify they fail**

Run:

```bash
xcodebuild test -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -destination 'platform=macOS,arch=arm64' -only-testing:SmartRecordTests/TimelineMapperTests -only-testing:SmartRecordTests/TimelineEditingTests
```

Expected: compile fails because `TimelineMapper` and `TimelineEditing` do not exist.

- [ ] **Step 4: Implement mapping and editing helpers**

Create `SmartRecord/SmartRecord/Editing/TimelineMapper.swift`:

```swift
import Foundation

nonisolated struct TimelineSegment: Equatable {
    let sourceStartTime: Double
    let sourceEndTime: Double
    let timelineStartTime: Double

    var duration: Double { max(0, sourceEndTime - sourceStartTime) }
    var timelineEndTime: Double { timelineStartTime + duration }
}

nonisolated struct TimelineMapper {
    let segments: [TimelineSegment]

    init(segments: [EditSegment]) {
        self.segments = Self.normalizedSegments(from: segments).map {
            TimelineSegment(
                sourceStartTime: $0.sourceStartTime,
                sourceEndTime: $0.sourceEndTime,
                timelineStartTime: $0.timelineStartTime
            )
        }
    }

    init(timelineSegments: [TimelineSegment]) {
        self.segments = timelineSegments.sorted { $0.timelineStartTime < $1.timelineStartTime }
    }

    var duration: Double {
        segments.last?.timelineEndTime ?? 0
    }

    func timelineTime(forSourceTime sourceTime: Double) -> Double? {
        guard let segment = segments.first(where: { $0.sourceStartTime <= sourceTime && sourceTime <= $0.sourceEndTime }) else {
            return nil
        }
        return segment.timelineStartTime + (sourceTime - segment.sourceStartTime)
    }

    func sourceTime(forTimelineTime timelineTime: Double) -> Double? {
        guard let segment = segments.first(where: { $0.timelineStartTime <= timelineTime && timelineTime <= $0.timelineEndTime }) else {
            return nil
        }
        return segment.sourceStartTime + (timelineTime - segment.timelineStartTime)
    }

    static func normalizedSegments(from segments: [EditSegment]) -> [EditSegment] {
        let enabled = segments
            .filter { $0.isEnabled && $0.duration > 0 }
            .sorted { $0.sourceStartTime < $1.sourceStartTime }
        var cursor = 0.0
        for segment in enabled {
            segment.timelineStartTime = cursor
            cursor += segment.duration
        }
        return enabled
    }
}
```

Create `SmartRecord/SmartRecord/Editing/TimelineEditing.swift`:

```swift
import Foundation

nonisolated enum TimelineEditing {
    static func split(_ segment: EditSegment, atTimelineTime timelineTime: Double) -> (left: EditSegment, right: EditSegment) {
        let offset = min(max(timelineTime - segment.timelineStartTime, 0), segment.duration)
        let sourceSplit = segment.sourceStartTime + offset
        let left = EditSegment(
            sourceStartTime: segment.sourceStartTime,
            sourceEndTime: sourceSplit,
            timelineStartTime: segment.timelineStartTime,
            isEnabled: segment.isEnabled
        )
        let right = EditSegment(
            sourceStartTime: sourceSplit,
            sourceEndTime: segment.sourceEndTime,
            timelineStartTime: segment.timelineStartTime + left.duration,
            isEnabled: segment.isEnabled
        )
        return (left, right)
    }

    static func trim(_ segment: EditSegment, newSourceStartTime: Double, newSourceEndTime: Double) {
        let lower = segment.sourceStartTime
        let upper = segment.sourceEndTime
        let nextStart = min(max(newSourceStartTime, lower), upper)
        let nextEnd = min(max(newSourceEndTime, nextStart), upper)
        segment.sourceStartTime = nextStart
        segment.sourceEndTime = nextEnd
    }

    static func delete(_ segment: EditSegment, in timeline: EditTimeline) {
        segment.isEnabled = false
        _ = TimelineMapper.normalizedSegments(from: timeline.segments)
    }
}
```

- [ ] **Step 5: Run mapper and editing tests**

Run:

```bash
xcodebuild test -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -destination 'platform=macOS,arch=arm64' -only-testing:SmartRecordTests/TimelineMapperTests -only-testing:SmartRecordTests/TimelineEditingTests
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add SmartRecord/SmartRecord/Editing SmartRecord/SmartRecordTests/TimelineMapperTests.swift SmartRecord/SmartRecordTests/TimelineEditingTests.swift
git commit -m "feat: add timeline mapping helpers"
```

## Task 3: Project Asset Support For Imported Annotation Images

**Files:**
- Modify: `SmartRecord/SmartRecord/Capture/ProjectAssetStore.swift`
- Test: `SmartRecord/SmartRecordTests/ProjectAssetStoreTests.swift`

- [ ] **Step 1: Write failing asset directory test**

Add this test to `ProjectAssetStoreTests`:

```swift
@Test func projectBundleProvidesAnnotationAssetDirectory() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("SmartRecordAssetStoreTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let store = ProjectAssetStore(rootDirectory: root)
    let bundle = try store.createProjectBundle()

    try store.ensureAnnotationAssetDirectory(for: bundle)

    #expect(bundle.annotationAssetsDirectory.lastPathComponent == "Assets")
    #expect(FileManager.default.fileExists(atPath: bundle.annotationAssetsDirectory.path))
}
```

- [ ] **Step 2: Run test and verify it fails**

Run:

```bash
xcodebuild test -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -destination 'platform=macOS,arch=arm64' -only-testing:SmartRecordTests/ProjectAssetStoreTests/projectBundleProvidesAnnotationAssetDirectory
```

Expected: compile fails because `annotationAssetsDirectory` and `ensureAnnotationAssetDirectory` do not exist.

- [ ] **Step 3: Implement asset directory helpers**

In `ProjectAssetBundle`, add:

```swift
var annotationAssetsDirectory: URL { directory.appendingPathComponent("Assets", isDirectory: true) }
```

In `ProjectAssetStore`, add:

```swift
func ensureAnnotationAssetDirectory(for bundle: ProjectAssetBundle) throws {
    try FileManager.default.createDirectory(at: bundle.annotationAssetsDirectory, withIntermediateDirectories: true)
}
```

- [ ] **Step 4: Run asset tests**

Run:

```bash
xcodebuild test -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -destination 'platform=macOS,arch=arm64' -only-testing:SmartRecordTests/ProjectAssetStoreTests
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add SmartRecord/SmartRecord/Capture/ProjectAssetStore.swift SmartRecord/SmartRecordTests/ProjectAssetStoreTests.swift
git commit -m "feat: add annotation asset directory"
```

## Task 4: Timeline-Aware Video Export

**Files:**
- Create: `SmartRecord/SmartRecord/PostProcessing/EditedVideoExporter.swift`
- Modify: `SmartRecord/SmartRecord/PostProcessing/PostProcessingCoordinator.swift`
- Test: `SmartRecord/SmartRecordTests/EditedVideoExporterTests.swift`

- [ ] **Step 1: Write failing edited exporter duration test**

Create `SmartRecord/SmartRecordTests/EditedVideoExporterTests.swift`:

```swift
import AVFoundation
import Foundation
import Testing
@testable import SmartRecord

struct EditedVideoExporterTests {
    @Test func exportUsesOnlyEnabledTimelineSegments() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartRecordEditedExporterTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ProjectAssetStore(rootDirectory: root)
        let bundle = try store.createProjectBundle()
        try await TestMediaFactory.writeSilentVideo(to: bundle.screenVideo, duration: 4)

        let timeline = EditTimeline(sourceDuration: 4)
        timeline.segments = [
            EditSegment(sourceStartTime: 0, sourceEndTime: 1.5, timelineStartTime: 0),
            EditSegment(sourceStartTime: 2.5, sourceEndTime: 4.0, timelineStartTime: 1.5)
        ]

        try await EditedVideoExporter().export(
            bundle: bundle,
            timeline: timeline,
            clickEvents: [],
            audioMode: .none,
            options: .defaults
        )

        let asset = AVURLAsset(url: bundle.finalVideo)
        let duration = try await asset.load(.duration).seconds
        #expect(abs(duration - 3.0) < 0.25)
    }
}
```

If `TestMediaFactory` does not exist in the test target, move the media helper currently embedded in `VideoExporterTests` into `SmartRecord/SmartRecordTests/TestMediaFactory.swift` with this public test helper:

```swift
import AVFoundation
import CoreImage
import Foundation

enum TestMediaFactory {
    static func writeSilentVideo(to url: URL, duration: Double) async throws {
        let size = CGSize(width: 320, height: 180)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: size.width,
                AVVideoHeightKey: size.height
            ]
        )
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: size.width,
                kCVPixelBufferHeightKey as String: size.height
            ]
        )
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        let frameCount = Int(duration * 24)
        for frame in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            var buffer: CVPixelBuffer?
            CVPixelBufferCreate(nil, Int(size.width), Int(size.height), kCVPixelFormatType_32BGRA, nil, &buffer)
            if let buffer {
                adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 24))
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
    }
}
```

- [ ] **Step 2: Run test and verify it fails**

Run:

```bash
xcodebuild test -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -destination 'platform=macOS,arch=arm64' -only-testing:SmartRecordTests/EditedVideoExporterTests
```

Expected: compile fails because `EditedVideoExporter` does not exist.

- [ ] **Step 3: Implement initial edited exporter**

Create `SmartRecord/SmartRecord/PostProcessing/EditedVideoExporter.swift`:

```swift
import AVFoundation
import CoreImage
import Foundation

nonisolated struct EditedVideoExporter {
    func export(
        bundle: ProjectAssetBundle,
        timeline: EditTimeline,
        clickEvents: [SmartFocusEvent],
        audioMode: AudioCaptureMode,
        options: VideoRenderOptions,
        outputURL: URL? = nil
    ) async throws {
        guard FileManager.default.fileExists(atPath: bundle.screenVideo.path) else {
            throw VideoExporterError.missingScreenVideo
        }

        let destination = outputURL ?? bundle.finalVideo
        let temporaryOutput = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).tmp-\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: temporaryOutput)

        let normalizedSegments = TimelineMapper.normalizedSegments(from: timeline.segments)
        let mapper = TimelineMapper(segments: normalizedSegments)
        let composition = AVMutableComposition()
        let screenAsset = AVURLAsset(url: bundle.screenVideo)
        guard let sourceVideoTrack = try await screenAsset.loadTracks(withMediaType: .video).first else {
            throw VideoExporterError.noVideoTrack
        }

        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw VideoExporterError.noVideoTrack
        }

        for segment in mapper.segments {
            try videoTrack.insertTimeRange(
                CMTimeRange(
                    start: CMTime(seconds: segment.sourceStartTime, preferredTimescale: 600),
                    duration: CMTime(seconds: segment.duration, preferredTimescale: 600)
                ),
                of: sourceVideoTrack,
                at: CMTime(seconds: segment.timelineStartTime, preferredTimescale: 600)
            )
        }

        let preferredTransform = try await sourceVideoTrack.load(.preferredTransform)
        let naturalSize = try await sourceVideoTrack.load(.naturalSize)
        videoTrack.preferredTransform = preferredTransform
        let audioMixParameters = try await addAudioTracks(to: composition, bundle: bundle, audioMode: audioMode, options: options, mapper: mapper)

        let renderSize = evenSize(naturalSize.applying(preferredTransform))
        let mappedEvents = clickEvents.compactMap { event -> SmartFocusEvent? in
            guard let time = mapper.timelineTime(forSourceTime: event.time) else { return nil }
            return SmartFocusEvent(time: time, nx: event.nx, ny: event.ny)
        }
        let solver = SmartFocusSolver(events: mappedEvents, duration: mapper.duration, zoomScale: options.zoomScale)
        let videoComposition = AVMutableVideoComposition(asset: composition) { request in
            let sample = options.zoomEnabled
                ? solver.sample(at: request.compositionTime.seconds)
                : SmartFocusSample(nx: 0.5, ny: 0.5, zoom: 1.0)
            request.finish(with: render(sourceImage: request.sourceImage, sample: sample), context: nil)
        }
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = options.frameRate.frameDuration

        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoExporterError.exportUnavailable
        }
        exporter.shouldOptimizeForNetworkUse = true
        exporter.videoComposition = videoComposition
        if !audioMixParameters.isEmpty {
            let audioMix = AVMutableAudioMix()
            audioMix.inputParameters = audioMixParameters
            exporter.audioMix = audioMix
        }

        do {
            try await exporter.export(to: temporaryOutput, as: .mp4)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: temporaryOutput, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: temporaryOutput)
            throw VideoExporterError.exportFailed(Self.errorSummary(error))
        }
    }

    private func addAudioTracks(
        to composition: AVMutableComposition,
        bundle: ProjectAssetBundle,
        audioMode: AudioCaptureMode,
        options: VideoRenderOptions,
        mapper: TimelineMapper
    ) async throws -> [AVAudioMixInputParameters] {
        var parameters: [AVAudioMixInputParameters] = []
        if audioMode.capturesSystemAudio,
           let track = try await addAudioTrack(from: bundle.systemAudio, to: composition, mapper: mapper) {
            let input = AVMutableAudioMixInputParameters(track: track)
            input.setVolume(options.systemGain, at: .zero)
            parameters.append(input)
        }
        if audioMode.capturesMicrophone,
           let track = try await addAudioTrack(from: bundle.microphoneAudio, to: composition, mapper: mapper) {
            let input = AVMutableAudioMixInputParameters(track: track)
            input.setVolume(options.microphoneGain, at: .zero)
            parameters.append(input)
        }
        return parameters
    }

    private func addAudioTrack(from url: URL, to composition: AVMutableComposition, mapper: TimelineMapper) async throws -> AVMutableCompositionTrack? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let asset = AVURLAsset(url: url)
        guard let sourceTrack = try await asset.loadTracks(withMediaType: .audio).first,
              let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            return nil
        }
        for segment in mapper.segments {
            try track.insertTimeRange(
                CMTimeRange(
                    start: CMTime(seconds: segment.sourceStartTime, preferredTimescale: 600),
                    duration: CMTime(seconds: segment.duration, preferredTimescale: 600)
                ),
                of: sourceTrack,
                at: CMTime(seconds: segment.timelineStartTime, preferredTimescale: 600)
            )
        }
        return track
    }

    private func evenSize(_ size: CGSize) -> CGSize {
        let width = max(2, abs(Int(size.width)) - abs(Int(size.width)) % 2)
        let height = max(2, abs(Int(size.height)) - abs(Int(size.height)) % 2)
        return CGSize(width: width, height: height)
    }

    private static func errorSummary(_ error: Error?) -> String {
        guard let error else { return AppStrings.current(.unknownError) }
        let nsError = error as NSError
        return "\(nsError.domain) \(nsError.code): \(nsError.localizedDescription)"
    }
}
```

Move `render(sourceImage:sample:)` from `VideoExporter.swift` to a shared file if access is private. Create `SmartRecord/SmartRecord/PostProcessing/SmartFocusRenderer.swift`:

```swift
import CoreImage
import Foundation

nonisolated func render(sourceImage: CIImage, sample: SmartFocusSample) -> CIImage {
    let extent = sourceImage.extent
    let zoom = max(CGFloat(sample.zoom), 1.0)
    guard zoom > 1.001 else {
        return sourceImage.cropped(to: extent)
    }
    let cropWidth = extent.width / zoom
    let cropHeight = extent.height / zoom
    let centerX = extent.minX + CGFloat(sample.nx) * extent.width
    let centerY = extent.minY + (1 - CGFloat(sample.ny)) * extent.height
    let originX = min(max(centerX - cropWidth / 2, extent.minX), extent.maxX - cropWidth)
    let originY = min(max(centerY - cropHeight / 2, extent.minY), extent.maxY - cropHeight)
    let cropRect = CGRect(x: originX, y: originY, width: cropWidth, height: cropHeight)
    let translated = sourceImage
        .cropped(to: cropRect)
        .transformed(by: CGAffineTransform(translationX: -cropRect.minX, y: -cropRect.minY))
    return translated
        .transformed(by: CGAffineTransform(scaleX: zoom, y: zoom))
        .cropped(to: CGRect(origin: .zero, size: extent.size))
}
```

Delete the private `render(sourceImage:sample:)` from `VideoExporter.swift` after adding the shared file.

- [ ] **Step 4: Wire coordinator to edited exporter when a timeline exists**

Modify `PostProcessingCoordinator` to hold both exporters:

```swift
private let videoExporter: VideoExporter
private let editedVideoExporter: EditedVideoExporter
```

Change initializer:

```swift
init(
    assetStore: ProjectAssetStore = ProjectAssetStore(),
    videoExporter: VideoExporter = VideoExporter(),
    editedVideoExporter: EditedVideoExporter = EditedVideoExporter()
) {
    self.assetStore = assetStore
    self.videoExporter = videoExporter
    self.editedVideoExporter = editedVideoExporter
}
```

Inside `renderFinalVideo`, replace the export call with:

```swift
if let timeline = project.editTimeline, timeline.segments.contains(where: { $0.isEnabled }) {
    try await editedVideoExporter.export(
        bundle: bundle,
        timeline: timeline,
        clickEvents: smartFocusEvents(for: project),
        audioMode: project.audioCaptureMode,
        options: renderOptions(for: project)
    )
} else {
    try await videoExporter.export(
        bundle: bundle,
        clickEvents: smartFocusEvents(for: project),
        audioMode: project.audioCaptureMode,
        options: renderOptions(for: project)
    )
}
```

- [ ] **Step 5: Run edited exporter tests**

Run:

```bash
xcodebuild test -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -destination 'platform=macOS,arch=arm64' -only-testing:SmartRecordTests/EditedVideoExporterTests -only-testing:SmartRecordTests/VideoExporterTests
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add SmartRecord/SmartRecord/PostProcessing SmartRecord/SmartRecordTests/EditedVideoExporterTests.swift SmartRecord/SmartRecordTests/TestMediaFactory.swift
git commit -m "feat: export edited timeline segments"
```

## Task 5: Annotation And Caption Burn-In Renderer

**Files:**
- Create: `SmartRecord/SmartRecord/Editing/AnnotationRenderer.swift`
- Modify: `SmartRecord/SmartRecord/PostProcessing/EditedVideoExporter.swift`
- Test: `SmartRecord/SmartRecordTests/AnnotationRendererTests.swift`

- [ ] **Step 1: Write failing renderer tests**

Create `SmartRecord/SmartRecordTests/AnnotationRendererTests.swift`:

```swift
import CoreImage
import Testing
@testable import SmartRecord

struct AnnotationRendererTests {
    @Test func visibleAnnotationsAreSortedByLayer() {
        let annotations = [
            AnnotationItem(kind: .text, startTime: 0, endTime: 5, normalizedX: 0, normalizedY: 0, normalizedWidth: 0.2, normalizedHeight: 0.2, zIndex: 2),
            AnnotationItem(kind: .blur, startTime: 0, endTime: 5, normalizedX: 0, normalizedY: 0, normalizedWidth: 0.2, normalizedHeight: 0.2, zIndex: 1),
            AnnotationItem(kind: .arrow, startTime: 7, endTime: 8, normalizedX: 0, normalizedY: 0, normalizedWidth: 0.2, normalizedHeight: 0.2, zIndex: 0)
        ]

        let visible = AnnotationRenderer.visibleAnnotations(annotations, at: 3)

        #expect(visible.map(\.kind) == [.blur, .text])
    }

    @Test func captionVisibilityRespectsEnabledState() {
        let captions = [
            CaptionSegment(startTime: 0, endTime: 5, text: "shown", languageCode: "en-US"),
            CaptionSegment(startTime: 0, endTime: 5, text: "hidden", languageCode: "en-US", isEnabled: false)
        ]

        #expect(AnnotationRenderer.visibleCaptions(captions, at: 2).map(\.text) == ["shown"])
    }
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
xcodebuild test -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -destination 'platform=macOS,arch=arm64' -only-testing:SmartRecordTests/AnnotationRendererTests
```

Expected: compile fails because `AnnotationRenderer` does not exist.

- [ ] **Step 3: Implement initial renderer utilities**

Create `SmartRecord/SmartRecord/Editing/AnnotationRenderer.swift`:

```swift
import AppKit
import CoreImage
import Foundation

nonisolated struct AnnotationRenderer {
    static func visibleAnnotations(_ annotations: [AnnotationItem], at time: Double) -> [AnnotationItem] {
        annotations
            .filter { $0.startTime <= time && time <= $0.endTime }
            .sorted { $0.zIndex < $1.zIndex }
    }

    static func visibleCaptions(_ captions: [CaptionSegment], at time: Double) -> [CaptionSegment] {
        captions
            .filter { $0.isEnabled && $0.startTime <= time && time <= $0.endTime && !$0.text.isEmpty }
            .sorted { $0.startTime < $1.startTime }
    }

    func render(
        image: CIImage,
        annotations: [AnnotationItem],
        captions: [CaptionSegment],
        time: Double,
        burnCaptions: Bool,
        assetsDirectory: URL?
    ) -> CIImage {
        let size = image.extent.size
        let bitmap = NSImage(size: size)
        bitmap.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        for annotation in Self.visibleAnnotations(annotations, at: time) {
            draw(annotation, size: size, assetsDirectory: assetsDirectory)
        }
        if burnCaptions, let caption = Self.visibleCaptions(captions, at: time).last {
            drawCaption(caption.text, size: size)
        }
        bitmap.unlockFocus()
        guard let tiff = bitmap.tiffRepresentation,
              let overlay = CIImage(data: tiff) else {
            return image
        }
        return overlay.composited(over: image)
    }

    private func draw(_ annotation: AnnotationItem, size: CGSize, assetsDirectory: URL?) {
        let rect = CGRect(
            x: annotation.normalizedX * size.width,
            y: (1 - annotation.normalizedY - annotation.normalizedHeight) * size.height,
            width: annotation.normalizedWidth * size.width,
            height: annotation.normalizedHeight * size.height
        )
        switch annotation.kind {
        case .text:
            drawText(annotation.text, rect: rect, color: color(from: annotation.colorHex), opacity: annotation.opacity)
        case .highlightRectangle:
            drawStroke(rect: rect, ellipse: false, color: color(from: annotation.colorHex), opacity: annotation.opacity)
        case .highlightEllipse:
            drawStroke(rect: rect, ellipse: true, color: color(from: annotation.colorHex), opacity: annotation.opacity)
        case .arrow:
            drawArrow(rect: rect, color: color(from: annotation.colorHex), opacity: annotation.opacity)
        case .blur:
            drawBlurPlaceholder(rect: rect, opacity: min(max(annotation.opacity, 0.15), 0.65))
        case .image:
            drawImage(annotation.assetFilename, rect: rect, assetsDirectory: assetsDirectory, opacity: annotation.opacity)
        }
    }

    private func drawText(_ text: String, rect: CGRect, color: NSColor, opacity: Double) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: color.withAlphaComponent(opacity),
            .font: NSFont.systemFont(ofSize: max(16, rect.height * 0.45), weight: .semibold),
            .paragraphStyle: paragraph
        ]
        text.draw(in: rect, withAttributes: attrs)
    }

    private func drawStroke(rect: CGRect, ellipse: Bool, color: NSColor, opacity: Double) {
        color.withAlphaComponent(opacity).setStroke()
        let path = ellipse ? NSBezierPath(ovalIn: rect) : NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
        path.lineWidth = max(3, min(rect.width, rect.height) * 0.04)
        path.stroke()
    }

    private func drawArrow(rect: CGRect, color: NSColor, opacity: Double) {
        color.withAlphaComponent(opacity).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 5
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.line(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.stroke()
    }

    private func drawBlurPlaceholder(rect: CGRect, opacity: Double) {
        NSColor.black.withAlphaComponent(opacity).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
    }

    private func drawImage(_ filename: String?, rect: CGRect, assetsDirectory: URL?, opacity: Double) {
        guard let filename, let assetsDirectory else { return }
        let url = assetsDirectory.appendingPathComponent(filename)
        guard let image = NSImage(contentsOf: url) else { return }
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: opacity)
    }

    private func drawCaption(_ text: String, size: CGSize) {
        let height = max(44, size.height * 0.085)
        let rect = CGRect(x: size.width * 0.1, y: size.height * 0.07, width: size.width * 0.8, height: height)
        NSColor.black.withAlphaComponent(0.58).setFill()
        NSBezierPath(roundedRect: rect.insetBy(dx: -12, dy: -6), xRadius: 10, yRadius: 10).fill()
        drawText(text, rect: rect, color: .white, opacity: 1)
    }

    private func color(from hex: String) -> NSColor {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else { return .systemBlue }
        return NSColor(
            red: CGFloat((value >> 16) & 0xff) / 255,
            green: CGFloat((value >> 8) & 0xff) / 255,
            blue: CGFloat(value & 0xff) / 255,
            alpha: 1
        )
    }
}
```

- [ ] **Step 4: Integrate renderer into edited export**

In `EditedVideoExporter.export`, capture the renderer and timeline values before creating `AVMutableVideoComposition`:

```swift
let annotationRenderer = AnnotationRenderer()
let annotations = timeline.exportSettings?.includeAnnotations == true ? timeline.annotations : []
let captions = timeline.captions
let burnCaptions = timeline.exportSettings?.burnCaptions == true
let assetsDirectory = bundle.annotationAssetsDirectory
```

Inside the video composition closure, after SmartFocus render:

```swift
let focused = render(sourceImage: request.sourceImage, sample: sample)
let overlaid = annotationRenderer.render(
    image: focused,
    annotations: annotations,
    captions: captions,
    time: request.compositionTime.seconds,
    burnCaptions: burnCaptions,
    assetsDirectory: assetsDirectory
)
request.finish(with: overlaid, context: nil)
```

- [ ] **Step 5: Run renderer tests and edited exporter tests**

Run:

```bash
xcodebuild test -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -destination 'platform=macOS,arch=arm64' -only-testing:SmartRecordTests/AnnotationRendererTests -only-testing:SmartRecordTests/EditedVideoExporterTests
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add SmartRecord/SmartRecord/Editing/AnnotationRenderer.swift SmartRecord/SmartRecord/PostProcessing/EditedVideoExporter.swift SmartRecord/SmartRecordTests/AnnotationRendererTests.swift
git commit -m "feat: render annotations and captions"
```

## Task 6: SmartFocus Keyframe Overrides

**Files:**
- Modify: `SmartRecord/SmartRecord/PostProcessing/EditedVideoExporter.swift`
- Create: `SmartRecord/SmartRecord/Editing/SmartFocusTimeline.swift`
- Test: `SmartRecord/SmartRecordTests/SmartFocusSolverTests.swift`

- [ ] **Step 1: Write failing SmartFocus timeline test**

Add this test to `SmartFocusSolverTests`:

```swift
@Test func userEditedKeyframesOverrideDetectedClicks() {
    let clicks = [SmartFocusEvent(time: 2, nx: 0.1, ny: 0.1)]
    let keyframes = [SmartFocusKeyframe(time: 2, nx: 0.8, ny: 0.7, zoomScale: 1.9)]

    let events = SmartFocusTimeline.events(clickEvents: clicks, keyframes: keyframes)

    #expect(events.count == 1)
    #expect(events[0].nx == 0.8)
    #expect(events[0].ny == 0.7)
}
```

- [ ] **Step 2: Run test and verify it fails**

Run:

```bash
xcodebuild test -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -destination 'platform=macOS,arch=arm64' -only-testing:SmartRecordTests/SmartFocusSolverTests/userEditedKeyframesOverrideDetectedClicks
```

Expected: compile fails because `SmartFocusTimeline` does not exist.

- [ ] **Step 3: Implement SmartFocus event merger**

Create `SmartRecord/SmartRecord/Editing/SmartFocusTimeline.swift`:

```swift
import Foundation

nonisolated enum SmartFocusTimeline {
    static func events(clickEvents: [SmartFocusEvent], keyframes: [SmartFocusKeyframe]) -> [SmartFocusEvent] {
        let edited = keyframes.map { SmartFocusEvent(time: $0.time, nx: $0.nx, ny: $0.ny) }
        guard !edited.isEmpty else { return clickEvents.sorted { $0.time < $1.time } }
        return edited.sorted { $0.time < $1.time }
    }
}
```

- [ ] **Step 4: Use keyframes during edited export**

In `EditedVideoExporter.export`, replace:

```swift
let mappedEvents = clickEvents.compactMap { event -> SmartFocusEvent? in
```

with:

```swift
let focusSourceEvents = timeline.exportSettings?.includeSmartFocus == false
    ? []
    : SmartFocusTimeline.events(clickEvents: clickEvents, keyframes: timeline.smartFocusKeyframes)
let mappedEvents = focusSourceEvents.compactMap { event -> SmartFocusEvent? in
```

- [ ] **Step 5: Run SmartFocus and edited exporter tests**

Run:

```bash
xcodebuild test -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -destination 'platform=macOS,arch=arm64' -only-testing:SmartRecordTests/SmartFocusSolverTests -only-testing:SmartRecordTests/EditedVideoExporterTests
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add SmartRecord/SmartRecord/Editing/SmartFocusTimeline.swift SmartRecord/SmartRecord/PostProcessing/EditedVideoExporter.swift SmartRecord/SmartRecordTests/SmartFocusSolverTests.swift
git commit -m "feat: support editable smartfocus keyframes"
```

## Task 7: Local-Only Captioning Boundary

**Files:**
- Create: `SmartRecord/SmartRecord/Speech/LocalSpeechCaptioner.swift`
- Create: `SmartRecord/SmartRecord/Speech/CaptionLanguage.swift`
- Modify: `SmartRecord/SmartRecord/SmartRecord.entitlements`
- Test: `SmartRecord/SmartRecordTests/LocalSpeechCaptionerTests.swift`

- [ ] **Step 1: Write failing speech boundary tests**

Create `SmartRecord/SmartRecordTests/LocalSpeechCaptionerTests.swift`:

```swift
import Foundation
import Testing
@testable import SmartRecord

struct LocalSpeechCaptionerTests {
    @Test func noAudioModeDisablesCaptioning() {
        let result = LocalSpeechCaptioner.audioSource(
            bundle: ProjectAssetBundle(directoryName: UUID().uuidString, directory: URL(filePath: "/tmp/missing")),
            audioMode: .none
        )

        #expect(result == nil)
    }

    @Test func appLanguageMapsToSpeechLocale() {
        #expect(CaptionLanguage.defaultLanguage(for: .zhHans).identifier == "zh-CN")
        #expect(CaptionLanguage.defaultLanguage(for: .en).identifier == "en-US")
        #expect(CaptionLanguage.defaultLanguage(for: .ja).identifier == "ja-JP")
    }
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
xcodebuild test -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -destination 'platform=macOS,arch=arm64' -only-testing:SmartRecordTests/LocalSpeechCaptionerTests
```

Expected: compile fails because `LocalSpeechCaptioner` and `CaptionLanguage` do not exist.

- [ ] **Step 3: Implement language and captioning boundary**

Create `SmartRecord/SmartRecord/Speech/CaptionLanguage.swift`:

```swift
import Foundation

nonisolated struct CaptionLanguage: Equatable, Identifiable {
    let identifier: String
    let displayName: String

    var id: String { identifier }

    static let supported: [CaptionLanguage] = [
        CaptionLanguage(identifier: "zh-CN", displayName: "简体中文"),
        CaptionLanguage(identifier: "zh-TW", displayName: "繁體中文"),
        CaptionLanguage(identifier: "en-US", displayName: "English"),
        CaptionLanguage(identifier: "ja-JP", displayName: "日本語"),
        CaptionLanguage(identifier: "ko-KR", displayName: "한국어"),
        CaptionLanguage(identifier: "fr-FR", displayName: "Français"),
        CaptionLanguage(identifier: "de-DE", displayName: "Deutsch"),
        CaptionLanguage(identifier: "es-ES", displayName: "Español"),
        CaptionLanguage(identifier: "it-IT", displayName: "Italiano"),
        CaptionLanguage(identifier: "pt-BR", displayName: "Português")
    ]

    static func defaultLanguage(for appLanguage: AppLanguage) -> CaptionLanguage {
        switch appLanguage {
        case .zhHans:
            return supported[0]
        case .zhHant:
            return supported[1]
        case .en:
            return supported[2]
        case .ja:
            return supported[3]
        case .ko:
            return supported[4]
        case .fr:
            return supported[5]
        case .es:
            return supported[7]
        case .it:
            return supported[8]
        case .pt:
            return supported[9]
        case .sv, .fi:
            return supported[2]
        }
    }
}
```

Create `SmartRecord/SmartRecord/Speech/LocalSpeechCaptioner.swift`:

```swift
import Foundation

enum LocalSpeechCaptionerError: LocalizedError, Equatable {
    case noAudio
    case onDeviceRecognitionUnavailable(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noAudio:
            return "No local audio is available for caption generation."
        case .onDeviceRecognitionUnavailable(let language):
            return "On-device speech recognition is unavailable for \(language) on this Mac."
        case .cancelled:
            return "Caption generation was cancelled."
        }
    }
}

nonisolated struct LocalSpeechCaptioner {
    static func audioSource(bundle: ProjectAssetBundle, audioMode: AudioCaptureMode) -> URL? {
        switch audioMode {
        case .both:
            if FileManager.default.fileExists(atPath: bundle.microphoneAudio.path) { return bundle.microphoneAudio }
            if FileManager.default.fileExists(atPath: bundle.systemAudio.path) { return bundle.systemAudio }
            return nil
        case .microphoneOnly:
            return FileManager.default.fileExists(atPath: bundle.microphoneAudio.path) ? bundle.microphoneAudio : nil
        case .systemOnly:
            return FileManager.default.fileExists(atPath: bundle.systemAudio.path) ? bundle.systemAudio : nil
        case .none:
            return nil
        }
    }

    func transcribe(bundle: ProjectAssetBundle, audioMode: AudioCaptureMode, language: CaptionLanguage) async throws -> [CaptionSegment] {
        guard Self.audioSource(bundle: bundle, audioMode: audioMode) != nil else {
            throw LocalSpeechCaptionerError.noAudio
        }
        throw LocalSpeechCaptionerError.onDeviceRecognitionUnavailable(language.identifier)
    }
}
```

This first implementation is a safe boundary: it never calls online recognition and returns an unavailable state until the exact Apple on-device API is wired in Task 8.

- [ ] **Step 4: Add Speech entitlement**

Add the Apple speech-recognition entitlement only when the API integration in Task 8 requires it. If Xcode signing rejects the capability without Apple approval, leave entitlement off and keep the UI in unavailable state. The code path must still never request network permission.

- [ ] **Step 5: Run speech boundary tests**

Run:

```bash
xcodebuild test -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -destination 'platform=macOS,arch=arm64' -only-testing:SmartRecordTests/LocalSpeechCaptionerTests
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add SmartRecord/SmartRecord/Speech SmartRecord/SmartRecordTests/LocalSpeechCaptionerTests.swift
git commit -m "feat: add local captioning boundary"
```

## Task 8: Wire Apple On-Device Speech Recognition

**Files:**
- Modify: `SmartRecord/SmartRecord/Speech/LocalSpeechCaptioner.swift`
- Test: `SmartRecord/SmartRecordTests/LocalSpeechCaptionerTests.swift`

- [ ] **Step 1: Verify Apple API in local SDK**

Run:

```bash
xcrun swift -e 'import Speech; print("Speech framework available")'
```

Expected: prints `Speech framework available`.

Run:

```bash
xcrun swift -e 'import Speech; let request = SFSpeechURLRecognitionRequest(url: URL(fileURLWithPath: "/tmp/no-audio.m4a")); request.requiresOnDeviceRecognition = true; print(request.requiresOnDeviceRecognition)'
```

Expected: prints `true`.

- [ ] **Step 2: Add availability test for unsupported languages**

Append to `LocalSpeechCaptionerTests.swift`:

```swift
@Test func unavailableRecognizerReportsLanguage() async {
    let captioner = LocalSpeechCaptioner(recognizerFactory: { _ in nil })

    await #expect(throws: LocalSpeechCaptionerError.onDeviceRecognitionUnavailable("xx-XX")) {
        _ = try await captioner.transcribe(
            bundle: ProjectAssetBundle(directoryName: UUID().uuidString, directory: URL(filePath: "/tmp")),
            audioMode: .microphoneOnly,
            language: CaptionLanguage(identifier: "xx-XX", displayName: "Unsupported")
        )
    }
}
```

- [ ] **Step 3: Implement recognizer injection**

Update `LocalSpeechCaptioner.swift`:

```swift
import Foundation
import Speech

nonisolated struct LocalSpeechCaptioner {
    typealias RecognizerFactory = @Sendable (Locale) -> SFSpeechRecognizer?
    private let recognizerFactory: RecognizerFactory

    init(recognizerFactory: @escaping RecognizerFactory = { SFSpeechRecognizer(locale: $0) }) {
        self.recognizerFactory = recognizerFactory
    }

    static func audioSource(bundle: ProjectAssetBundle, audioMode: AudioCaptureMode) -> URL? {
        switch audioMode {
        case .both:
            if FileManager.default.fileExists(atPath: bundle.microphoneAudio.path) { return bundle.microphoneAudio }
            if FileManager.default.fileExists(atPath: bundle.systemAudio.path) { return bundle.systemAudio }
            return nil
        case .microphoneOnly:
            return FileManager.default.fileExists(atPath: bundle.microphoneAudio.path) ? bundle.microphoneAudio : nil
        case .systemOnly:
            return FileManager.default.fileExists(atPath: bundle.systemAudio.path) ? bundle.systemAudio : nil
        case .none:
            return nil
        }
    }

    func transcribe(bundle: ProjectAssetBundle, audioMode: AudioCaptureMode, language: CaptionLanguage) async throws -> [CaptionSegment] {
        guard let audioURL = Self.audioSource(bundle: bundle, audioMode: audioMode) else {
            throw LocalSpeechCaptionerError.noAudio
        }
        let locale = Locale(identifier: language.identifier)
        guard let recognizer = recognizerFactory(locale), recognizer.supportsOnDeviceRecognition else {
            throw LocalSpeechCaptionerError.onDeviceRecognitionUnavailable(language.identifier)
        }
        return try await transcribe(audioURL: audioURL, recognizer: recognizer, language: language)
    }

    private func transcribe(audioURL: URL, recognizer: SFSpeechRecognizer, language: CaptionLanguage) async throws -> [CaptionSegment] {
        try await withCheckedThrowingContinuation { continuation in
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = false
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result, result.isFinal else { return }
                let segments = result.bestTranscription.segments.map {
                    CaptionSegment(
                        startTime: $0.timestamp,
                        endTime: $0.timestamp + $0.duration,
                        text: $0.substring,
                        languageCode: language.identifier,
                        confidence: Double($0.confidence)
                    )
                }
                continuation.resume(returning: segments)
            }
        }
    }
}
```

Keep this integration behind `request.requiresOnDeviceRecognition = true` and `recognizer.supportsOnDeviceRecognition`. If the current SDK or App Store signing path requires a newer Apple local-transcription API for the deployment target, adapt only `LocalSpeechCaptioner` while preserving the same public boundary and tests: no online fallback, no network entitlement, and no sidecar subtitle files.

- [ ] **Step 4: Run speech tests**

Run:

```bash
xcodebuild test -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -destination 'platform=macOS,arch=arm64' -only-testing:SmartRecordTests/LocalSpeechCaptionerTests
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add SmartRecord/SmartRecord/Speech SmartRecord/SmartRecordTests/LocalSpeechCaptionerTests.swift
git commit -m "feat: wire on-device speech captions"
```

## Task 9: Editor Window Shell And Project List Entry Point

**Files:**
- Create: `SmartRecord/SmartRecord/UI/Editor/RecordingEditorView.swift`
- Create: `SmartRecord/SmartRecord/UI/Editor/EditorTimelineView.swift`
- Create: `SmartRecord/SmartRecord/UI/Editor/EditorInspectorView.swift`
- Modify: `SmartRecord/SmartRecord/ContentView.swift`
- Modify: `SmartRecord/SmartRecord/Localization/AppLocalization.swift`

- [ ] **Step 1: Add localization keys**

Add these `AppText` cases:

```swift
case edit
case editorCut
case editorAnnotate
case editorSmartFocus
case editorCaptions
case editorExport
case burnCaptions
case exportFinalVideo
case saveCopy
```

Add table values for every language. For the first pass, use clear English fallback values for non-primary languages to keep `AppLocalizationTests/everyTextKeyHasEverySupportedLanguage()` passing:

```swift
.edit: values("编辑", "編輯", "Edit", "Edit", "Edit", "Edit", "Edit", "Edit", "Edit", "Edit", "Edit"),
.editorCut: values("剪辑", "剪輯", "Cut", "Cut", "Cut", "Cut", "Cut", "Cut", "Cut", "Cut", "Cut"),
.editorAnnotate: values("注释", "註釋", "Annotate", "Annotate", "Annotate", "Annotate", "Annotate", "Annotate", "Annotate", "Annotate", "Annotate"),
.editorSmartFocus: values("SmartFocus", "SmartFocus", "SmartFocus", "SmartFocus", "SmartFocus", "SmartFocus", "SmartFocus", "SmartFocus", "SmartFocus", "SmartFocus", "SmartFocus"),
.editorCaptions: values("字幕", "字幕", "Captions", "Captions", "Captions", "Captions", "Captions", "Captions", "Captions", "Captions", "Captions"),
.editorExport: values("导出", "匯出", "Export", "Export", "Export", "Export", "Export", "Export", "Export", "Export", "Export"),
.burnCaptions: values("烧录字幕", "燒錄字幕", "Burn captions", "Burn captions", "Burn captions", "Burn captions", "Burn captions", "Burn captions", "Burn captions", "Burn captions", "Burn captions"),
.exportFinalVideo: values("更新 final.mp4", "更新 final.mp4", "Update final.mp4", "Update final.mp4", "Update final.mp4", "Update final.mp4", "Update final.mp4", "Update final.mp4", "Update final.mp4", "Update final.mp4", "Update final.mp4"),
.saveCopy: values("另存副本", "另存副本", "Save copy", "Save copy", "Save copy", "Save copy", "Save copy", "Save copy", "Save copy", "Save copy", "Save copy"),
```

- [ ] **Step 2: Create editor shell**

Create `SmartRecord/SmartRecord/UI/Editor/RecordingEditorView.swift`:

```swift
import SwiftData
import SwiftUI

enum EditorMode: String, CaseIterable, Identifiable {
    case cut
    case annotate
    case smartFocus
    case captions
    case export

    var id: String { rawValue }
}

struct RecordingEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var project: Project
    let bundle: ProjectAssetBundle
    let strings: AppStrings
    @State private var mode: EditorMode = .cut
    @State private var playhead: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $mode) {
                Text(strings(.editorCut)).tag(EditorMode.cut)
                Text(strings(.editorAnnotate)).tag(EditorMode.annotate)
                Text(strings(.editorSmartFocus)).tag(EditorMode.smartFocus)
                Text(strings(.editorCaptions)).tag(EditorMode.captions)
                Text(strings(.editorExport)).tag(EditorMode.export)
            }
            .pickerStyle(.segmented)
            .padding()

            HStack(spacing: 0) {
                VStack(spacing: 12) {
                    ZStack {
                        Rectangle().fill(.black)
                        Text("Preview")
                            .foregroundStyle(.white.secondary)
                    }
                    .aspectRatio(16.0 / 10.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    EditorTimelineView(project: project, playhead: $playhead, strings: strings)
                }
                .padding()

                Divider()

                EditorInspectorView(project: project, mode: mode, strings: strings)
                    .frame(width: 280)
                    .padding()
            }
        }
        .frame(minWidth: 1040, minHeight: 720)
    }
}
```

Create `EditorTimelineView.swift`:

```swift
import SwiftUI

struct EditorTimelineView: View {
    @Bindable var project: Project
    @Binding var playhead: Double
    let strings: AppStrings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(strings(.editorCut))
                .font(.headline)
            timelineTrack(title: "Video", color: .blue)
            timelineTrack(title: strings(.editorAnnotate), color: .pink)
            timelineTrack(title: "SmartFocus", color: .green)
            timelineTrack(title: strings(.editorCaptions), color: .orange)
        }
    }

    private func timelineTrack(title: String, color: Color) -> some View {
        HStack {
            Text(title)
                .frame(width: 96, alignment: .leading)
            RoundedRectangle(cornerRadius: 5)
                .fill(color.opacity(0.18))
                .frame(height: 32)
        }
    }
}
```

Create `EditorInspectorView.swift`:

```swift
import SwiftUI

struct EditorInspectorView: View {
    @Bindable var project: Project
    let mode: EditorMode
    let strings: AppStrings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
            if mode == .export {
                Toggle(strings(.burnCaptions), isOn: burnCaptionsBinding)
                Button(strings(.exportFinalVideo)) {}
                    .buttonStyle(.borderedProminent)
                Button(strings(.saveCopy)) {}
                    .buttonStyle(.bordered)
            }
            Spacer()
        }
    }

    private var title: String {
        switch mode {
        case .cut: strings(.editorCut)
        case .annotate: strings(.editorAnnotate)
        case .smartFocus: strings(.editorSmartFocus)
        case .captions: strings(.editorCaptions)
        case .export: strings(.editorExport)
        }
    }

    private var burnCaptionsBinding: Binding<Bool> {
        Binding {
            project.editTimeline?.exportSettings?.burnCaptions ?? false
        } set: { value in
            project.editTimeline?.exportSettings?.burnCaptions = value
        }
    }
}
```

- [ ] **Step 3: Add Edit button to project rows**

In `ContentView`, add state:

```swift
@State private var projectBeingEdited: Project?
```

Add a row action beside play/Finder:

```swift
rowAction(t(.edit), icon: "slider.horizontal.3") {
    projectBeingEdited = project
}
```

Attach a sheet to the root `HStack`:

```swift
.sheet(item: $projectBeingEdited) { project in
    if let bundle = coordinator.recordingBundle(for: project) {
        RecordingEditorView(project: project, bundle: bundle, strings: t)
    }
}
```

- [ ] **Step 4: Run localization and build tests**

Run:

```bash
xcodebuild test -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -destination 'platform=macOS,arch=arm64' -only-testing:SmartRecordTests/AppLocalizationTests
xcodebuild build -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -configuration Debug
```

Expected: localization test passes and build succeeds.

- [ ] **Step 5: Commit**

```bash
git add SmartRecord/SmartRecord/UI/Editor SmartRecord/SmartRecord/ContentView.swift SmartRecord/SmartRecord/Localization/AppLocalization.swift
git commit -m "feat: add recording editor shell"
```

## Task 10: Timeline Editing UI Interactions

**Files:**
- Modify: `SmartRecord/SmartRecord/UI/Editor/EditorTimelineView.swift`
- Modify: `SmartRecord/SmartRecord/UI/Editor/EditorInspectorView.swift`
- Test: `SmartRecord/SmartRecordTests/TimelineEditingTests.swift`

- [ ] **Step 1: Add test for applying split to timeline**

Append to `TimelineEditingTests`:

```swift
@Test func splitSegmentInTimelineReplacesOriginal() {
    let timeline = EditTimeline(sourceDuration: 10)
    let original = timeline.segments[0]

    TimelineEditing.split(original, atTimelineTime: 4, in: timeline)

    #expect(timeline.segments.count == 2)
    #expect(timeline.segments[0].sourceEndTime == 4)
    #expect(timeline.segments[1].sourceStartTime == 4)
}
```

- [ ] **Step 2: Implement timeline split mutation**

Add to `TimelineEditing.swift`:

```swift
static func split(_ segment: EditSegment, atTimelineTime timelineTime: Double, in timeline: EditTimeline) {
    let parts = split(segment, atTimelineTime: timelineTime)
    guard let index = timeline.segments.firstIndex(where: { $0 === segment }) else { return }
    timeline.segments.remove(at: index)
    timeline.segments.insert(parts.right, at: index)
    timeline.segments.insert(parts.left, at: index)
    _ = TimelineMapper.normalizedSegments(from: timeline.segments)
}
```

- [ ] **Step 3: Add basic cut buttons to timeline view**

In `EditorTimelineView`, render segment buttons:

```swift
ForEach((project.editTimeline?.segments ?? []).filter(\.isEnabled)) { segment in
    Button {
        playhead = segment.timelineStartTime
    } label: {
        Text(String(format: "%.1fs - %.1fs", segment.sourceStartTime, segment.sourceEndTime))
            .font(.caption.weight(.semibold))
            .frame(minWidth: 90, minHeight: 28)
    }
    .buttonStyle(.bordered)
}
```

Add cut/delete controls under the video track:

```swift
HStack {
    Button("Split") {
        guard let segment = project.editTimeline?.segments.first(where: { $0.isEnabled && $0.timelineStartTime <= playhead && playhead <= $0.timelineStartTime + $0.duration }),
              let timeline = project.editTimeline else { return }
        TimelineEditing.split(segment, atTimelineTime: playhead, in: timeline)
    }
    Button("Delete") {
        guard let segment = project.editTimeline?.segments.first(where: { $0.isEnabled && $0.timelineStartTime <= playhead && playhead <= $0.timelineStartTime + $0.duration }),
              let timeline = project.editTimeline else { return }
        TimelineEditing.delete(segment, in: timeline)
    }
}
```

- [ ] **Step 4: Add edge time fields in inspector**

In `EditorInspectorView`, for `.cut`, show the first enabled segment as a minimal first version:

```swift
if mode == .cut, let segment = project.editTimeline?.segments.first(where: \.isEnabled) {
    TextField("Start", value: Binding(get: {
        segment.sourceStartTime
    }, set: { value in
        TimelineEditing.trim(segment, newSourceStartTime: value, newSourceEndTime: segment.sourceEndTime)
    }), format: .number)
    TextField("End", value: Binding(get: {
        segment.sourceEndTime
    }, set: { value in
        TimelineEditing.trim(segment, newSourceStartTime: segment.sourceStartTime, newSourceEndTime: value)
    }), format: .number)
}
```

- [ ] **Step 5: Run editing tests and build**

Run:

```bash
xcodebuild test -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -destination 'platform=macOS,arch=arm64' -only-testing:SmartRecordTests/TimelineEditingTests
xcodebuild build -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -configuration Debug
```

Expected: tests pass and build succeeds.

- [ ] **Step 6: Commit**

```bash
git add SmartRecord/SmartRecord/Editing/TimelineEditing.swift SmartRecord/SmartRecord/UI/Editor SmartRecord/SmartRecordTests/TimelineEditingTests.swift
git commit -m "feat: add timeline cut controls"
```

## Task 11: Annotation Editing UI

**Files:**
- Create: `SmartRecord/SmartRecord/UI/Editor/AnnotationToolbar.swift`
- Modify: `SmartRecord/SmartRecord/UI/Editor/RecordingEditorView.swift`
- Modify: `SmartRecord/SmartRecord/UI/Editor/EditorInspectorView.swift`

- [ ] **Step 1: Create annotation toolbar**

Create `AnnotationToolbar.swift`:

```swift
import SwiftUI

struct AnnotationToolbar: View {
    @Bindable var timeline: EditTimeline
    @Binding var playhead: Double

    var body: some View {
        HStack {
            addButton("Text", kind: .text)
            addButton("Arrow", kind: .arrow)
            addButton("Box", kind: .highlightRectangle)
            addButton("Circle", kind: .highlightEllipse)
            addButton("Blur", kind: .blur)
            addButton("Logo", kind: .image)
        }
    }

    private func addButton(_ title: String, kind: AnnotationKind) -> some View {
        Button(title) {
            timeline.annotations.append(
                AnnotationItem(
                    kind: kind,
                    startTime: playhead,
                    endTime: playhead + 3,
                    normalizedX: 0.3,
                    normalizedY: 0.3,
                    normalizedWidth: 0.3,
                    normalizedHeight: 0.16,
                    text: kind == .text ? "Text" : ""
                )
            )
        }
    }
}
```

- [ ] **Step 2: Show annotation toolbar in editor**

In `RecordingEditorView`, under the mode picker:

```swift
if mode == .annotate, let timeline = project.editTimeline {
    AnnotationToolbar(timeline: timeline, playhead: $playhead)
        .padding(.horizontal)
}
```

- [ ] **Step 3: Add annotation inspector**

In `EditorInspectorView`, add:

```swift
if mode == .annotate, let annotation = project.editTimeline?.annotations.last {
    TextField("Text", text: Binding(get: {
        annotation.text
    }, set: { annotation.text = $0 }))
    TextField("Start", value: Binding(get: {
        annotation.startTime
    }, set: { annotation.startTime = max(0, $0) }), format: .number)
    TextField("End", value: Binding(get: {
        annotation.endTime
    }, set: { annotation.endTime = max(annotation.startTime, $0) }), format: .number)
    Slider(value: Binding(get: {
        annotation.opacity
    }, set: { annotation.opacity = min(max($0, 0), 1) }), in: 0...1)
}
```

- [ ] **Step 4: Build**

Run:

```bash
xcodebuild build -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -configuration Debug
```

Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add SmartRecord/SmartRecord/UI/Editor
git commit -m "feat: add annotation editing controls"
```

## Task 12: Caption UI And Manual Recognition Trigger

**Files:**
- Create: `SmartRecord/SmartRecord/UI/Editor/CaptionEditorView.swift`
- Modify: `SmartRecord/SmartRecord/UI/Editor/RecordingEditorView.swift`
- Modify: `SmartRecord/SmartRecord/UI/Editor/EditorInspectorView.swift`
- Modify: `SmartRecord/SmartRecord/Localization/AppLocalization.swift`

- [ ] **Step 1: Add caption action strings**

Add `AppText` cases:

```swift
case generateCaptions
case captionLanguage
case onDeviceSpeechUnavailable
```

Add values:

```swift
.generateCaptions: values("生成字幕", "產生字幕", "Generate captions", "Generate captions", "Generate captions", "Generate captions", "Generate captions", "Generate captions", "Generate captions", "Generate captions", "Generate captions"),
.captionLanguage: values("字幕语言", "字幕語言", "Caption language", "Caption language", "Caption language", "Caption language", "Caption language", "Caption language", "Caption language", "Caption language", "Caption language"),
.onDeviceSpeechUnavailable: values("当前系统或语言不支持本机语音识别。", "目前系統或語言不支援本機語音辨識。", "On-device speech recognition is unavailable for this system or language.", "On-device speech recognition is unavailable for this system or language.", "On-device speech recognition is unavailable for this system or language.", "On-device speech recognition is unavailable for this system or language.", "On-device speech recognition is unavailable for this system or language.", "On-device speech recognition is unavailable for this system or language.", "On-device speech recognition is unavailable for this system or language.", "On-device speech recognition is unavailable for this system or language.", "On-device speech recognition is unavailable for this system or language."),
```

- [ ] **Step 2: Create CaptionEditorView**

Create `CaptionEditorView.swift`:

```swift
import SwiftUI

struct CaptionEditorView: View {
    @Bindable var project: Project
    let bundle: ProjectAssetBundle
    let strings: AppStrings
    @State private var selectedLanguage: CaptionLanguage
    @State private var message: String?
    @State private var isGenerating = false

    init(project: Project, bundle: ProjectAssetBundle, strings: AppStrings) {
        self.project = project
        self.bundle = bundle
        self.strings = strings
        _selectedLanguage = State(initialValue: CaptionLanguage.defaultLanguage(for: strings.language))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(strings(.captionLanguage), selection: $selectedLanguage) {
                ForEach(CaptionLanguage.supported) { language in
                    Text(language.displayName).tag(language)
                }
            }
            Button(strings(.generateCaptions)) {
                generate()
            }
            .disabled(isGenerating || project.audioCaptureMode == .none)

            if let message {
                Text(message)
                    .foregroundStyle(.secondary)
            }

            ForEach(project.editTimeline?.captions ?? []) { caption in
                TextField("Caption", text: Binding(get: {
                    caption.text
                }, set: { caption.text = $0 }))
            }
        }
    }

    private func generate() {
        guard let timeline = project.editTimeline else { return }
        isGenerating = true
        message = nil
        Task { @MainActor in
            do {
                let captions = try await LocalSpeechCaptioner().transcribe(
                    bundle: bundle,
                    audioMode: project.audioCaptureMode,
                    language: selectedLanguage
                )
                timeline.captions = captions
            } catch {
                message = strings(.onDeviceSpeechUnavailable)
            }
            isGenerating = false
        }
    }
}
```

- [ ] **Step 3: Mount caption editor**

In `RecordingEditorView`, under the preview when `mode == .captions`:

```swift
if mode == .captions {
    CaptionEditorView(project: project, bundle: bundle, strings: strings)
}
```

- [ ] **Step 4: Run localization tests and build**

Run:

```bash
xcodebuild test -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -destination 'platform=macOS,arch=arm64' -only-testing:SmartRecordTests/AppLocalizationTests
xcodebuild build -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -configuration Debug
```

Expected: tests pass and build succeeds.

- [ ] **Step 5: Commit**

```bash
git add SmartRecord/SmartRecord/UI/Editor SmartRecord/SmartRecord/Localization/AppLocalization.swift
git commit -m "feat: add caption editing controls"
```

## Task 13: Export Actions From Editor

**Files:**
- Modify: `SmartRecord/SmartRecord/UI/Editor/EditorInspectorView.swift`
- Modify: `SmartRecord/SmartRecord/PostProcessing/PostProcessingCoordinator.swift`
- Modify: `SmartRecord/SmartRecord/Capture/RecordingCoordinator.swift`

- [ ] **Step 1: Add export action closure to inspector**

Update `EditorInspectorView` initializer:

```swift
let exportFinal: () -> Void
let saveCopy: () -> Void
```

Change buttons:

```swift
Button(strings(.exportFinalVideo), action: exportFinal)
    .buttonStyle(.borderedProminent)
Button(strings(.saveCopy), action: saveCopy)
    .buttonStyle(.bordered)
```

- [ ] **Step 2: Add copy export method to coordinator**

In `PostProcessingCoordinator`, add:

```swift
func exportCopy(project: Project, context: ModelContext, destination: URL) async throws {
    guard let bundle = try? assetStore.bundle(named: project.assetDirectoryName),
          let timeline = project.editTimeline else {
        throw VideoExporterError.missingScreenVideo
    }
    try await editedVideoExporter.export(
        bundle: bundle,
        timeline: timeline,
        clickEvents: smartFocusEvents(for: project),
        audioMode: project.audioCaptureMode,
        options: renderOptions(for: project),
        outputURL: destination
    )
    try? context.save()
}
```

In `RecordingCoordinator`, add:

```swift
func exportEditedVideoCopy(for project: Project, context: ModelContext, destination: URL) {
    Task { @MainActor in
        do {
            try await postProcessor.exportCopy(project: project, context: context, destination: destination)
        } catch {
            failureMessage = error.localizedDescription
        }
    }
}
```

- [ ] **Step 3: Wire editor export buttons**

Pass closures from `RecordingEditorView`:

```swift
EditorInspectorView(
    project: project,
    mode: mode,
    strings: strings,
    exportFinal: {
        coordinator.regenerateVideo(for: project, context: context)
    },
    saveCopy: {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = "SmartRecord.mp4"
        if panel.runModal() == .OK, let url = panel.url {
            coordinator.exportEditedVideoCopy(for: project, context: context, destination: url)
        }
    }
)
```

- [ ] **Step 4: Build**

Run:

```bash
xcodebuild build -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -configuration Debug
```

Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add SmartRecord/SmartRecord/UI/Editor SmartRecord/SmartRecord/PostProcessing/PostProcessingCoordinator.swift SmartRecord/SmartRecord/Capture/RecordingCoordinator.swift
git commit -m "feat: wire editor export actions"
```

## Task 14: Privacy And Support Copy

**Files:**
- Modify: `docs/appstore-site/privacy.html`
- Modify: `docs/appstore-site/support.html`
- Modify: `docs/index.html`

- [ ] **Step 1: Update privacy policy copy**

In `docs/appstore-site/privacy.html`, replace the local processing paragraph with:

```html
<p>Recording, audio mixing, SmartFocus processing, post-recording edits, optional on-device caption generation, and H.264 export are designed to run locally on your Mac. Files are saved to locations you choose or to local project folders created by the app.</p>
```

Replace the information handled paragraph with:

```html
<p>When you use SmartRecord, the app may process screen video, selected display or window content, microphone audio, system audio, mouse activity used for SmartFocus, project-internal captions created on device, annotations, imported local annotation images, and exported video files. This data is used to create your recording and export files on your Mac.</p>
```

- [ ] **Step 2: Update support page**

Add this article to `docs/appstore-site/support.html`:

```html
<article>
  <h2>Post-recording edits and captions</h2>
  <p>SmartRecord keeps raw recordings in the local project folder. Edits, annotations, SmartFocus adjustments, and project captions are processed locally and rendered into the final MP4 only when you export.</p>
</article>
```

- [ ] **Step 3: Update landing page**

In `docs/index.html`, update the lead:

```html
<p class="lead">A focused macOS recorder for screen, system audio, microphone narration, SmartFocus zoom, lightweight post-recording edits, and H.264 MP4 export.</p>
```

- [ ] **Step 4: Search for forbidden wording**

Run:

```bash
rg -n "Whisper|whisper|VTT|vtt|\\.srt|model download|cloud transcription|online recognition" docs SmartRecord
```

Expected: no results.

- [ ] **Step 5: Commit**

```bash
git add docs/appstore-site/privacy.html docs/appstore-site/support.html docs/index.html
git commit -m "docs: describe local editor privacy"
```

## Task 15: Full Regression And Archive Verification

**Files:**
- No code files.

- [ ] **Step 1: Run full test suite**

Run:

```bash
xcodebuild test -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -destination 'platform=macOS,arch=arm64'
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 2: Run forbidden artifact scan**

Run:

```bash
rg -n "Whisper|whisper|VTT|vtt|\\.srt|model download|cloud transcription|online recognition|ffmpeg|whisper-cli|ggml" SmartRecord docs
find . -iname '*whisper*' -o -iname '*ffmpeg*' -o -iname '*vtt*'
```

Expected: no results.

- [ ] **Step 3: Create archive**

Run:

```bash
xcodebuild archive -project SmartRecord/SmartRecord.xcodeproj -scheme SmartRecord -configuration Release -archivePath /tmp/SmartRecord-editor.xcarchive
```

Expected: `** ARCHIVE SUCCEEDED **`.

- [ ] **Step 4: Inspect archive entitlements and bundled files**

Run:

```bash
codesign -d --entitlements :- /tmp/SmartRecord-editor.xcarchive/Products/Applications/SmartRecord.app
find /tmp/SmartRecord-editor.xcarchive/Products/Applications/SmartRecord.app -iname '*whisper*' -o -iname '*ffmpeg*' -o -iname '*vtt*' -o -path '*/Tools/*'
```

Expected: entitlements do not include outgoing network permission; file scan returns no files.

- [ ] **Step 5: Commit verification notes if docs changed**

If this task only runs verification, do not commit. If App Store review notes or privacy docs were adjusted, commit the exact doc paths:

```bash
git add docs
git commit -m "docs: update editor review notes"
```

## Self-Review Notes

- Spec coverage: Tasks cover models, mapping, non-destructive cut/delete/trim, annotation kinds, SmartFocus keyframes, local-only captions, optional caption burn-in, export behavior, privacy docs, and verification scans.
- Scope control: The plan does not implement arbitrary clip reordering, proxy files, sidecar caption export, cloud transcription, or transitions.
- Type consistency: `EditTimeline`, `EditSegment`, `AnnotationItem`, `SmartFocusKeyframe`, `CaptionSegment`, `ExportSettings`, `TimelineMapper`, `EditedVideoExporter`, and `LocalSpeechCaptioner` are introduced before later tasks reference them.
- Review risk: Speech recognition is guarded behind local-only behavior and no network entitlement. The implementation path first creates a safe unavailable boundary before wiring Apple on-device recognition.
