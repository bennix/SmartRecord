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
        // Use POINT size (event.location is in points), not the Retina pixelSize.
        let buf = MouseEventBuffer(screenWidth: recorder.pointSize.width,
                                   screenHeight: recorder.pointSize.height)
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
