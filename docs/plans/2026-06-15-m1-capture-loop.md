# M1 采集闭环 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 录制主显示器画面 + 系统声音 + 麦克风，输出一个可播放的 `.mov`，同时把鼠标点击/移动事件（带相对时间戳）落盘成 SwiftData 项目；验证标准：录出的 .mov 能播放，且记录的事件数 > 0。

**Architecture:** 采集层两路数据共用一个时间基准。`ScreenRecorder`（封装 `SCStream`）把屏幕帧 + 系统音 + 麦克风写入 `AVAssetWriter`；`MouseEventTap`（封装 `CGEventTap`）把鼠标事件换算成"相对录制起点的秒数"写入缓冲。`RecordingCoordinator` 在开始时统一记录 `t0`、协调两者，停止时创建 `Project`（SwiftData）持久化原始视频路径 + 事件元数据。原始录制永不改动，特效留到后续里程碑。

**Tech Stack:** Swift 6 / SwiftUI / SwiftData / ScreenCaptureKit (SCStream) / AVFoundation (AVAssetWriter) / CoreGraphics (CGEventTap) / XCTest

**纯逻辑（TDD）vs 框架采集（手动验证）：**
- TDD：`RecordingClock`（时间换算）、坐标归一化、事件缓冲计数、SwiftData 持久化往返。
- 手动集成验证：`SCStream` 真实录屏、`CGEventTap` 真实触发、.mov 可播放。这些任务给出明确的人工验证步骤而非自动断言。

---

## Task 0：在 Xcode 中添加单元测试 target（一次性手动步骤）

CGEventTap/SCStream 无法测，但纯逻辑需要测试 target 才能跑。手动加最稳妥（手改 pbxproj 易损）。

**Step 1:** 打开 `SmartRecord/SmartRecord.xcodeproj`。

**Step 2:** File → New → Target → **Unit Testing Bundle**，命名 `SmartRecordTests`，Target to be Tested 选 `SmartRecord`，语言 Swift。

**Step 3:** 删除自动生成的 `SmartRecordTests.swift` 里的示例方法（保留文件或后续替换）。

**Step 4:** 验证测试 target 能跑：
```bash
cd /Users/nellertcai/SmartRecord/SmartRecord
xcodebuild test -scheme SmartRecord -destination 'platform=macOS' -only-testing:SmartRecordTests 2>&1 | tail -20
```
Expected: `TEST SUCCEEDED`（0 个测试也算成功）。

**Step 5: Commit**
```bash
cd /Users/nellertcai/SmartRecord
git add -A && git commit -m "chore: add SmartRecordTests unit test target"
```

---

## Task 1：数据模型（替换模板的 Item）

**Files:**
- Create: `SmartRecord/SmartRecord/Models/MouseEventKind.swift`
- Create: `SmartRecord/SmartRecord/Models/ClickEvent.swift`
- Create: `SmartRecord/SmartRecord/Models/CursorSample.swift`
- Create: `SmartRecord/SmartRecord/Models/RenderSettings.swift`
- Create: `SmartRecord/SmartRecord/Models/Project.swift`
- Delete: `SmartRecord/SmartRecord/Item.swift`
- Modify: `SmartRecord/SmartRecord/SmartRecordApp.swift`（Schema 改用 Project）

**Step 1: 写模型代码**

`MouseEventKind.swift`:
```swift
import Foundation

enum MouseEventKind: String, Codable {
    case leftMouseDown
    case mouseMoved
    case leftMouseDragged
}
```

`ClickEvent.swift`:
```swift
import Foundation
import SwiftData

@Model
final class ClickEvent {
    /// 相对录制起点的秒数
    var time: Double
    /// 归一化坐标 [0,1]，左上原点
    var nx: Double
    var ny: Double

    init(time: Double, nx: Double, ny: Double) {
        self.time = time
        self.nx = nx
        self.ny = ny
    }
}
```

`CursorSample.swift`:
```swift
import Foundation
import SwiftData

@Model
final class CursorSample {
    var time: Double
    var nx: Double
    var ny: Double
    var dragging: Bool

    init(time: Double, nx: Double, ny: Double, dragging: Bool) {
        self.time = time
        self.nx = nx
        self.ny = ny
        self.dragging = dragging
    }
}
```

`RenderSettings.swift`（M1 只需存在，字段给默认值，后续里程碑使用）:
```swift
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
```

`Project.swift`:
```swift
import Foundation
import SwiftData

@Model
final class Project {
    var createdAt: Date
    var duration: Double
    /// 原始录制 .mov 的文件路径（相对 Application Support）
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
```

**Step 2: 删除 Item.swift 并更新 App schema**

删除 `Item.swift`。把 `SmartRecordApp.swift` 的 `Schema([Item.self])` 改为：
```swift
let schema = Schema([Project.self, ClickEvent.self, CursorSample.self, RenderSettings.self])
```

**Step 3: 编译验证**
```bash
cd /Users/nellertcai/SmartRecord/SmartRecord
xcodebuild build -scheme SmartRecord -destination 'platform=macOS' 2>&1 | tail -15
```
Expected: `BUILD SUCCEEDED`（注意：此时 `ContentView` 仍引用 `Item`，会报错——所以本步骤同时把 `ContentView.swift` 里的 `Item` 引用临时改成最小占位，见下）。

**Step 3a:** 临时把 `ContentView.swift` 替换为最小占位（Task 6 会重写）：
```swift
import SwiftUI

struct ContentView: View {
    var body: some View { Text("SmartRecord").padding() }
}
```

**Step 4: Commit**
```bash
cd /Users/nellertcai/SmartRecord
git add -A && git commit -m "feat: SwiftData models (Project/ClickEvent/CursorSample/RenderSettings), drop Item"
```

---

## Task 2：RecordingClock（纯逻辑，TDD）

把 `mach_absolute_time()` 的原始 tick 换算成"相对录制起点的秒数"。

**Files:**
- Create: `SmartRecord/SmartRecord/Capture/RecordingClock.swift`
- Test: `SmartRecord/SmartRecordTests/RecordingClockTests.swift`

**Step 1: 写失败测试**
```swift
import XCTest
@testable import SmartRecord

final class RecordingClockTests: XCTestCase {
    func test_elapsed_isZeroAtStart() {
        let clock = RecordingClock(startTicks: 1000, ticksPerSecond: 1_000_000)
        XCTAssertEqual(clock.elapsed(atTicks: 1000), 0, accuracy: 1e-9)
    }

    func test_elapsed_convertsTicksToSeconds() {
        let clock = RecordingClock(startTicks: 1000, ticksPerSecond: 1_000_000)
        // 500_000 ticks 之后 = 0.5 秒
        XCTAssertEqual(clock.elapsed(atTicks: 1000 + 500_000), 0.5, accuracy: 1e-9)
    }

    func test_elapsed_neverNegative() {
        let clock = RecordingClock(startTicks: 2000, ticksPerSecond: 1_000_000)
        XCTAssertEqual(clock.elapsed(atTicks: 1000), 0, accuracy: 1e-9)
    }
}
```

**Step 2: 跑测试确认失败**
```bash
cd /Users/nellertcai/SmartRecord/SmartRecord
xcodebuild test -scheme SmartRecord -destination 'platform=macOS' -only-testing:SmartRecordTests/RecordingClockTests 2>&1 | tail -20
```
Expected: 编译失败（`RecordingClock` 未定义）。

**Step 3: 写最小实现**
```swift
import Foundation

struct RecordingClock {
    let startTicks: UInt64
    let ticksPerSecond: Double

    /// 用真实 mach timebase 构造（录制起点）
    init(startTicks: UInt64) {
        self.startTicks = startTicks
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        // ticks → 纳秒：* numer / denom；每秒 ticks = 1e9 * denom / numer
        self.ticksPerSecond = 1_000_000_000.0 * Double(info.denom) / Double(info.numer)
    }

    /// 测试用：显式给 ticksPerSecond
    init(startTicks: UInt64, ticksPerSecond: Double) {
        self.startTicks = startTicks
        self.ticksPerSecond = ticksPerSecond
    }

    func elapsed(atTicks ticks: UInt64) -> Double {
        guard ticks > startTicks else { return 0 }
        return Double(ticks - startTicks) / ticksPerSecond
    }
}
```

**Step 4: 跑测试确认通过**
```bash
xcodebuild test -scheme SmartRecord -destination 'platform=macOS' -only-testing:SmartRecordTests/RecordingClockTests 2>&1 | tail -20
```
Expected: `TEST SUCCEEDED`，3 个测试通过。

**Step 5: Commit**
```bash
cd /Users/nellertcai/SmartRecord
git add -A && git commit -m "feat: RecordingClock with tests (mach ticks -> relative seconds)"
```

---

## Task 3：鼠标事件缓冲 + 坐标归一化（纯逻辑 TDD）

`CGEventTap` 给全局像素坐标；把它换算成 [0,1] 归一化坐标（这样 Retina/分辨率无关），并提供事件缓冲。先 TDD 纯逻辑，下一任务再接真实 tap。

**Files:**
- Create: `SmartRecord/SmartRecord/Capture/MouseEventBuffer.swift`
- Test: `SmartRecord/SmartRecordTests/MouseEventBufferTests.swift`

**Step 1: 写失败测试**
```swift
import XCTest
@testable import SmartRecord

final class MouseEventBufferTests: XCTestCase {
    func test_normalizes_pixelToUnitRange() {
        let buf = MouseEventBuffer(screenWidth: 1000, screenHeight: 500)
        buf.record(kind: .leftMouseDown, time: 1.0, px: 500, py: 250)
        XCTAssertEqual(buf.clicks.count, 1)
        XCTAssertEqual(buf.clicks[0].nx, 0.5, accuracy: 1e-9)
        XCTAssertEqual(buf.clicks[0].ny, 0.5, accuracy: 1e-9)
    }

    func test_clicksAndMovesGoToSeparateBuckets() {
        let buf = MouseEventBuffer(screenWidth: 1000, screenHeight: 500)
        buf.record(kind: .leftMouseDown, time: 1.0, px: 0, py: 0)
        buf.record(kind: .mouseMoved, time: 1.1, px: 1000, py: 500)
        buf.record(kind: .leftMouseDragged, time: 1.2, px: 500, py: 250)
        XCTAssertEqual(buf.clicks.count, 1)
        XCTAssertEqual(buf.samples.count, 2)        // moved + dragged
        XCTAssertTrue(buf.samples.last!.dragging)
    }

    func test_clampsOutOfBoundsCoordinates() {
        let buf = MouseEventBuffer(screenWidth: 1000, screenHeight: 500)
        buf.record(kind: .mouseMoved, time: 0.5, px: -50, py: 9999)
        XCTAssertEqual(buf.samples[0].nx, 0.0, accuracy: 1e-9)
        XCTAssertEqual(buf.samples[0].ny, 1.0, accuracy: 1e-9)
    }
}
```

**Step 2: 跑测试确认失败**
```bash
cd /Users/nellertcai/SmartRecord/SmartRecord
xcodebuild test -scheme SmartRecord -destination 'platform=macOS' -only-testing:SmartRecordTests/MouseEventBufferTests 2>&1 | tail -20
```
Expected: 编译失败（`MouseEventBuffer` 未定义）。

**Step 3: 写最小实现**

注意：缓冲存的是轻量值类型（不是 SwiftData @Model），停止录制时再转换成 @Model 持久化——避免录制热路径上碰 SwiftData。
```swift
import Foundation

struct RawClick { let time: Double; let nx: Double; let ny: Double }
struct RawSample { let time: Double; let nx: Double; let ny: Double; let dragging: Bool }

final class MouseEventBuffer {
    private let w: Double
    private let h: Double
    private(set) var clicks: [RawClick] = []
    private(set) var samples: [RawSample] = []

    init(screenWidth: Double, screenHeight: Double) {
        self.w = screenWidth
        self.h = screenHeight
    }

    func record(kind: MouseEventKind, time: Double, px: Double, py: Double) {
        let nx = min(max(px / w, 0), 1)
        let ny = min(max(py / h, 0), 1)
        switch kind {
        case .leftMouseDown:
            clicks.append(RawClick(time: time, nx: nx, ny: ny))
        case .mouseMoved:
            samples.append(RawSample(time: time, nx: nx, ny: ny, dragging: false))
        case .leftMouseDragged:
            samples.append(RawSample(time: time, nx: nx, ny: ny, dragging: true))
        }
    }
}
```

**Step 4: 跑测试确认通过**
```bash
xcodebuild test -scheme SmartRecord -destination 'platform=macOS' -only-testing:SmartRecordTests/MouseEventBufferTests 2>&1 | tail -20
```
Expected: `TEST SUCCEEDED`，3 个测试通过。

**Step 5: Commit**
```bash
cd /Users/nellertcai/SmartRecord
git add -A && git commit -m "feat: MouseEventBuffer with coordinate normalization + tests"
```

---

## Task 4：MouseEventTap（真实 CGEventTap，手动验证）

封装全局鼠标监听，把事件喂给 `MouseEventBuffer`。需要"辅助功能"权限——无法纯代码弹窗，靠引导。

**Files:**
- Create: `SmartRecord/SmartRecord/Capture/MouseEventTap.swift`

**Step 1: 写实现**
```swift
import CoreGraphics
import Foundation

final class MouseEventTap {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let buffer: MouseEventBuffer
    private let clock: RecordingClock

    init(buffer: MouseEventBuffer, clock: RecordingClock) {
        self.buffer = buffer
        self.clock = clock
    }

    /// 返回 false 表示未获辅助功能权限
    @discardableResult
    func start() -> Bool {
        let mask = (1 << CGEventType.leftMouseDown.rawValue)
                 | (1 << CGEventType.mouseMoved.rawValue)
                 | (1 << CGEventType.leftMouseDragged.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            let me = Unmanaged<MouseEventTap>.fromOpaque(refcon!).takeUnretainedValue()
            me.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false   // 多半是没有辅助功能权限
        }

        self.tap = tap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = src
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        tap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        let ticks = mach_absolute_time()
        let t = clock.elapsed(atTicks: ticks)
        let loc = event.location   // 全局坐标，左上原点
        let kind: MouseEventKind
        switch type {
        case .leftMouseDown: kind = .leftMouseDown
        case .mouseMoved: kind = .mouseMoved
        case .leftMouseDragged: kind = .leftMouseDragged
        default: return
        }
        buffer.record(kind: kind, time: t, px: Double(loc.x), py: Double(loc.y))
    }
}
```

**Step 2: 编译验证**
```bash
cd /Users/nellertcai/SmartRecord/SmartRecord
xcodebuild build -scheme SmartRecord -destination 'platform=macOS' 2>&1 | tail -10
```
Expected: `BUILD SUCCEEDED`。

**Step 3: 手动验证留到 Task 8**（需配合录制流程整体跑）。

**Step 4: Commit**
```bash
cd /Users/nellertcai/SmartRecord
git add -A && git commit -m "feat: MouseEventTap wrapping CGEventTap (listen-only global mouse)"
```

---

## Task 5：ScreenRecorder（SCStream → .mov，手动验证）

封装屏幕 + 系统音 + 麦克风采集，写入 `AVAssetWriter`。

> **取舍（已与设计文档对齐）**：M1 把视频 + 系统音 + 麦克风写成 **独立音轨**，50/50 实时混音降到 Task 9（可选）。M1 验证只需"能播放"，主音轨即视频+系统音。

**Files:**
- Create: `SmartRecord/SmartRecord/Capture/ScreenRecorder.swift`

**Step 1: 写实现**（关键 API 骨架，含三路输出）
```swift
import ScreenCaptureKit
import AVFoundation

@MainActor
final class ScreenRecorder: NSObject, SCStreamOutput {
    private var stream: SCStream?
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var systemAudioInput: AVAssetWriterInput?
    private var micAudioInput: AVAssetWriterInput?
    private var sessionStarted = false
    private(set) var outputURL: URL?
    private(set) var pixelSize: CGSize = .zero

    /// 启动录制主屏。返回写入的 .mov URL。
    func start() async throws -> URL {
        let content = try await SCShareableContent.excludingDesktopWindows(false,
                                                                           onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw NSError(domain: "SmartRecord", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "找不到主显示器"])
        }

        // 排除自身窗口（录制悬浮窗时用；M1 先排除全部本 App 窗口）
        let myWindows = content.windows.filter {
            $0.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
        }
        let filter = SCContentFilter(display: display, excludingWindows: myWindows)

        let config = SCStreamConfiguration()
        config.width = display.width * 2     // Retina：按需调整
        config.height = display.height * 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.capturesAudio = true          // 系统声音
        config.captureMicrophone = true      // 麦克风（macOS 15+）
        pixelSize = CGSize(width: config.width, height: config.height)

        let url = Self.makeOutputURL()
        outputURL = url
        try setupWriter(url: url, size: pixelSize)

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global())
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global())
        try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: .global())
        self.stream = stream
        try await stream.startCapture()
        return url
    }

    func stop() async throws {
        try await stream?.stopCapture()
        videoInput?.markAsFinished()
        systemAudioInput?.markAsFinished()
        micAudioInput?.markAsFinished()
        await writer?.finishWriting()
    }

    private func setupWriter(url: URL, size: CGSize) throws {
        let w = try AVAssetWriter(outputURL: url, fileType: .mov)
        let vSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height
        ]
        let vIn = AVAssetWriterInput(mediaType: .video, outputSettings: vSettings)
        vIn.expectsMediaDataInRealTime = true
        w.add(vIn)

        let aSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44_100
        ]
        let sysIn = AVAssetWriterInput(mediaType: .audio, outputSettings: aSettings)
        sysIn.expectsMediaDataInRealTime = true
        w.add(sysIn)
        let micIn = AVAssetWriterInput(mediaType: .audio, outputSettings: aSettings)
        micIn.expectsMediaDataInRealTime = true
        w.add(micIn)

        self.writer = w
        self.videoInput = vIn
        self.systemAudioInput = sysIn
        self.micAudioInput = micIn
        w.startWriting()
    }

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sb: CMSampleBuffer,
                            of type: SCStreamOutputType) {
        guard CMSampleBufferDataIsReady(sb) else { return }
        Task { @MainActor in self.append(sb, type: type) }
    }

    private func append(_ sb: CMSampleBuffer, type: SCStreamOutputType) {
        guard let writer, writer.status == .writing else { return }
        if !sessionStarted {
            writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sb))
            sessionStarted = true
        }
        let input: AVAssetWriterInput?
        switch type {
        case .screen: input = videoInput
        case .audio: input = systemAudioInput
        case .microphone: input = micAudioInput
        @unknown default: input = nil
        }
        if let input, input.isReadyForMoreMediaData {
            input.append(sb)
        }
    }

    private static func makeOutputURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                           in: .userDomainMask)[0]
            .appendingPathComponent("SmartRecord/Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(UUID().uuidString).mov")
    }
}
```

**Step 2: 编译验证**
```bash
cd /Users/nellertcai/SmartRecord/SmartRecord
xcodebuild build -scheme SmartRecord -destination 'platform=macOS' 2>&1 | tail -15
```
Expected: `BUILD SUCCEEDED`。如有并发/隔离告警，按提示修 `nonisolated`/`@MainActor`。

**Step 3: Commit**
```bash
cd /Users/nellertcai/SmartRecord
git add -A && git commit -m "feat: ScreenRecorder (SCStream screen+system audio+mic -> AVAssetWriter .mov)"
```

---

## Task 6：RecordingCoordinator + 最小 UI（落盘 Project）

把时钟、事件 tap、录制器串起来；停止时把缓冲转成 SwiftData。

**Files:**
- Create: `SmartRecord/SmartRecord/Capture/RecordingCoordinator.swift`
- Modify: `SmartRecord/SmartRecord/ContentView.swift`（替换占位）

**Step 1: 写 Coordinator**
```swift
import SwiftUI
import SwiftData

@MainActor
@Observable
final class RecordingCoordinator {
    var isRecording = false
    var lastEventCount = 0
    var permissionMissing = false

    private var recorder: ScreenRecorder?
    private var tap: MouseEventTap?
    private var buffer: MouseEventBuffer?
    private var clock: RecordingClock?
    private var startDate = Date.now

    func startRecording() async {
        let recorder = ScreenRecorder()
        do {
            _ = try await recorder.start()
        } catch {
            print("录制启动失败: \(error)")
            return
        }
        let clock = RecordingClock(startTicks: mach_absolute_time())
        let buf = MouseEventBuffer(screenWidth: recorder.pixelSize.width,
                                   screenHeight: recorder.pixelSize.height)
        let tap = MouseEventTap(buffer: buf, clock: clock)
        permissionMissing = !tap.start()

        self.recorder = recorder
        self.clock = clock
        self.buffer = buf
        self.tap = tap
        self.startDate = .now
        isRecording = true
    }

    func stopRecording(context: ModelContext) async {
        tap?.stop()
        try? await recorder?.stop()
        isRecording = false

        guard let buf = buffer, let recorder, let url = recorder.outputURL else { return }
        let project = Project(createdAt: startDate,
                              duration: Date.now.timeIntervalSince(startDate),
                              rawVideoFilename: url.lastPathComponent)
        project.clickEvents = buf.clicks.map { ClickEvent(time: $0.time, nx: $0.nx, ny: $0.ny) }
        project.cursorSamples = buf.samples.map {
            CursorSample(time: $0.time, nx: $0.nx, ny: $0.ny, dragging: $0.dragging)
        }
        context.insert(project)
        try? context.save()
        lastEventCount = project.clickEvents.count + project.cursorSamples.count
    }
}
```

**Step 2: 写最小 UI**
```swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]
    @State private var coordinator = RecordingCoordinator()

    var body: some View {
        VStack(spacing: 16) {
            Text("SmartRecord").font(.largeTitle.bold())

            Button(coordinator.isRecording ? "停止录制" : "开始录制") {
                Task {
                    if coordinator.isRecording {
                        await coordinator.stopRecording(context: context)
                    } else {
                        await coordinator.startRecording()
                    }
                }
            }
            .controlSize(.large)

            if coordinator.permissionMissing {
                Text("⚠️ 未获辅助功能权限，鼠标事件不会被记录。请到 系统设置 › 隐私与安全性 › 辅助功能 授权。")
                    .foregroundStyle(.orange).font(.callout)
            }
            if coordinator.lastEventCount > 0 {
                Text("上次录制事件数：\(coordinator.lastEventCount)").font(.callout)
            }

            Divider()
            Text("最近项目").font(.headline)
            List(projects) { p in
                HStack {
                    Text(p.createdAt, format: .dateTime)
                    Spacer()
                    Text("\(p.clickEvents.count) 点击 / \(p.cursorSamples.count) 轨迹")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(minWidth: 480, minHeight: 420)
    }
}
```

**Step 3: 编译验证**
```bash
cd /Users/nellertcai/SmartRecord/SmartRecord
xcodebuild build -scheme SmartRecord -destination 'platform=macOS' 2>&1 | tail -15
```
Expected: `BUILD SUCCEEDED`。

**Step 4: Commit**
```bash
cd /Users/nellertcai/SmartRecord
git add -A && git commit -m "feat: RecordingCoordinator + minimal recording UI"
```

---

## Task 7：权限声明（Info.plist）

**Files:**
- Modify: `SmartRecord` target 的 Info 设置（Xcode → target → Info，或 `project.pbxproj` 的 `INFOPLIST_KEY_*`）

**Step 1:** 在 target build settings 加：
- `INFOPLIST_KEY_NSMicrophoneUsageDescription` = `SmartRecord 需要麦克风录制你的旁白。`
- 屏幕录制权限由系统在首次 `SCStream` 时自动弹出，无需 plist key。

**Step 2:** 沙盒（如开启 App Sandbox）需在 entitlements 加：
- `com.apple.security.device.microphone` = YES
- `com.apple.security.device.audio-input` = YES
- 注意：CGEventTap 全局监听在 App Sandbox 下受限。**M1 建议关闭 App Sandbox**（Signing & Capabilities 移除 App Sandbox）以保证 CGEventTap 可用；上架问题留到后续里程碑评估。

**Step 3: 编译验证**
```bash
cd /Users/nellertcai/SmartRecord/SmartRecord
xcodebuild build -scheme SmartRecord -destination 'platform=macOS' 2>&1 | tail -10
```
Expected: `BUILD SUCCEEDED`。

**Step 4: Commit**
```bash
cd /Users/nellertcai/SmartRecord
git add -A && git commit -m "chore: microphone usage description + sandbox notes for M1"
```

---

## Task 8：端到端手动验证（M1 验收）

**Step 1:** Xcode 运行 App（⌘R）。首次会弹屏幕录制权限——授权后**重启 App**。

**Step 2:** 到 系统设置 › 隐私与安全性 › 辅助功能，把 SmartRecord 打开（CGEventTap 需要）。

**Step 3:** 点"开始录制"，在屏幕上**点几下 + 移动鼠标 + 说句话**，5~10 秒后点"停止录制"。

**Step 4: 验收标准：**
- UI 显示"上次录制事件数" > 0（点击 + 轨迹）。
- "最近项目"列表出现一条新记录，点击数 > 0。
- 找到 .mov 并播放：
```bash
open ~/Library/Application\ Support/SmartRecord/Recordings/
```
用 QuickTime 打开最新 .mov → **画面能播放**（音轨此时可能是系统音或麦克风其一，属预期）。

**Step 5:** 若事件数为 0：多半辅助功能权限没生效（UI 会显示橙色警告）→ 重新授权并重启 App。

**Step 6:** 全部通过即 M1 完成。打标签：
```bash
cd /Users/nellertcai/SmartRecord
git tag m1-capture-loop && git log --oneline | head
```

---

## Task 9（可选）：麦克风/系统声音 50/50 实时混音

M1 验收不依赖本任务；若想立刻补齐设计文档的"单条混音轨"，再做。

**思路：** 用 `AVAudioEngine` 或手动 PCM 累加——把两路 `CMSampleBuffer` 转 `AVAudioPCMBuffer`，按 `micSystemMix` 加权求和，写入单一音频 input。需处理两路采样率/时间戳对齐与缓冲队列。**这是一块独立的、值得单独 TDD 的 DSP 逻辑**（混音函数纯逻辑可测：给定两段 PCM + 权重，断言输出样本）。建议作为 M1 之后、M2 之前的小插曲，或并入 M5 导出阶段统一混音。

---

## 完成定义（M1）

- [ ] 单元测试全绿（RecordingClock + MouseEventBuffer）。
- [ ] App 能录主屏，输出可播放的 .mov。
- [ ] 鼠标点击/轨迹事件落盘进 SwiftData，事件数 > 0。
- [ ] 权限缺失时 UI 有明确引导。
- [ ] 每个任务独立提交，M1 打 tag。
