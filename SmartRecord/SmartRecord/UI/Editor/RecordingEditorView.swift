import AppKit
import AVFoundation
import SwiftData
import SwiftUI

enum RecordingEditorMode: String, CaseIterable, Identifiable {
    case cut = "剪辑"
    case annotate = "注释"
    case smartFocus = "SmartFocus"
    case captions = "字幕"
    case export = "导出"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cut: "timeline.selection"
        case .annotate: "pencil.and.outline"
        case .smartFocus: "cursorarrow.click.2"
        case .captions: "captions.bubble"
        case .export: "square.and.arrow.up"
        }
    }
}

struct RecordingEditorView: View {
    @Environment(\.modelContext) private var context
    @Bindable var project: Project
    let coordinator: RecordingCoordinator
    var onClose: (() -> Void)?

    @State private var mode: RecordingEditorMode = .cut
    @State private var playhead = 0.0
    @State private var captionLanguage = CaptionLanguage.defaults[0]
    @State private var preparedTimeline: EditTimeline?
    @State private var isPreviewLoaded = false
    @State private var isPreviewFrameLoading = false
    @State private var previewImage: NSImage?
    @State private var previewErrorMessage: String?
    @State private var previewNoticeMessage: String?
    @State private var previewRequestID = UUID()

    init(project: Project, coordinator: RecordingCoordinator, onClose: (() -> Void)? = nil) {
        self.project = project
        self.coordinator = coordinator
        self.onClose = onClose
        _preparedTimeline = State(initialValue: project.ensureEditTimeline())
    }

    private var bundle: ProjectAssetBundle? {
        coordinator.recordingBundle(for: project)
    }

    var body: some View {
        Group {
            if let timeline = project.editTimeline ?? preparedTimeline {
                editorBody(timeline)
            } else {
                ContentUnavailableView("无法准备编辑数据", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.top, 44)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func editorBody(_ timeline: EditTimeline) -> some View {
        VStack(spacing: 0) {
            header
            Divider()
            content(timeline)
            Divider()
            footer(timeline)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            if let onClose {
                Button(action: onClose) {
                    Label("返回", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("SmartRecord 编辑器")
                    .font(.title.weight(.bold))
                Text(project.createdAt, format: .dateTime.year().month().day().hour().minute())
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("模式", selection: $mode) {
                ForEach(RecordingEditorMode.allCases) { item in
                    Label(item.rawValue, systemImage: item.icon).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 560)
            Button {
                coordinator.regenerateVideo(for: project, context: context)
            } label: {
                Label("渲染 final.mp4", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
    }

    private func content(_ timeline: EditTimeline) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: 14) {
                preview(timeline)
                sourceControls
                EditorTimelineView(timeline: timeline, sourceDuration: project.duration, playhead: $playhead)
            }
            .frame(minWidth: 720)
            .padding(18)

            Divider()

            EditorInspectorView(
                project: project,
                timeline: timeline,
                mode: mode,
                playhead: $playhead,
                captionLanguage: $captionLanguage,
                coordinator: coordinator
            )
            .frame(width: 360)
        }
    }

    private func preview(_ timeline: EditTimeline) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay {
                    if let previewErrorMessage {
                        ContentUnavailableView(
                            "视频预览加载失败",
                            systemImage: "exclamationmark.triangle",
                            description: Text(previewErrorMessage)
                        )
                        .foregroundStyle(.white)
                    } else if let previewImage {
                        Image(nsImage: previewImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else if isPreviewFrameLoading {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 46, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.82))
                            Text("正在读取视频画面")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    } else if bundle != nil {
                        VStack(spacing: 14) {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 48, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.82))
                            Text("原始录屏已就绪")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("点击生成静态预览图，或直接用系统播放器打开原始 screen.mov。")
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.72))
                            Button {
                                loadPreviewVideo()
                            } label: {
                                Label("生成预览图", systemImage: "photo")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        ContentUnavailableView("找不到录制文件", systemImage: "film.stack")
                    }
                }

            HStack(spacing: 10) {
                Label(timeText(playhead), systemImage: "play.circle")
                    .monospacedDigit()
                NonContinuousSlider(value: $playhead, range: 0...max(timeline.duration, 0.1))
                    .frame(height: 24)
                Button {
                    coordinator.openOriginalRecording(for: project)
                } label: {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(.bordered)
                .help("用系统播放器打开原始录屏")
            }
            .padding(10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding(14)

            if let previewNoticeMessage {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                    Text(previewNoticeMessage)
                    Button {
                        coordinator.openOriginalRecording(for: project)
                    } label: {
                        Label("系统播放器打开", systemImage: "play.rectangle")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .font(.body)
                .padding(10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private var sourceControls: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Label(sourceVideoStatus, systemImage: "film")
                    .font(.headline)
                Label(smartFocusStatus, systemImage: "cursorarrow.click")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            Spacer()
            Button {
                Task {
                    let didImport = await coordinator.importSourceVideo(for: project, context: context)
                    guard didImport else { return }
                    preparedTimeline = project.ensureEditTimeline()
                    resetPreview()
                }
            } label: {
                Label("选择原始录屏", systemImage: "film.stack")
            }
            Button {
                let didImport = coordinator.importSmartFocusLog(for: project, context: context)
                guard didImport else { return }
                preparedTimeline = project.ensureEditTimeline()
            } label: {
                Label("选择 SmartFocus 记录", systemImage: "point.3.connected.trianglepath.dotted")
            }
            Button {
                coordinator.openOriginalRecording(for: project)
            } label: {
                Label("系统播放器打开", systemImage: "play.rectangle")
            }
            .disabled(!hasSourceVideo)
        }
        .controlSize(.large)
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private func footer(_ timeline: EditTimeline) -> some View {
        HStack {
            Label("\(timeline.segments.filter(\.isEnabled).count) 段", systemImage: "rectangle.split.3x1")
            Label("\(timeline.annotations.count) 注释", systemImage: "pencil.and.outline")
            Label("\(timeline.smartFocusKeyframes.count) 聚焦点", systemImage: "cursorarrow.click")
            Label("\(timeline.captions.count) 字幕", systemImage: "captions.bubble")
            Spacer()
            Button {
                coordinator.open(project: project)
            } label: {
                Label("打开视频", systemImage: "play.rectangle")
            }
            Button {
                saveCopy()
            } label: {
                Label("另存 MP4", systemImage: "square.and.arrow.down")
            }
        }
        .font(.body)
        .padding(14)
    }

    private func loadPreviewVideo() {
        guard let bundle else {
            previewErrorMessage = "找不到项目录制目录。"
            previewNoticeMessage = nil
            isPreviewFrameLoading = false
            return
        }
        let url = bundle.screenVideo
        guard FileManager.default.fileExists(atPath: url.path) else {
            previewErrorMessage = "找不到原始屏幕录制文件：\(url.lastPathComponent)"
            previewNoticeMessage = nil
            isPreviewFrameLoading = false
            return
        }
        previewErrorMessage = nil
        previewNoticeMessage = nil
        isPreviewLoaded = true
        loadPreviewFrame(from: url)
    }

    private func loadPreviewFrame(from url: URL) {
        let requestID = UUID()
        previewRequestID = requestID
        previewImage = nil
        isPreviewFrameLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try EditorPreviewFrameLoader.imageData(from: url)
                Task { @MainActor in
                    guard previewRequestID == requestID else { return }
                    previewImage = NSImage(data: data)
                    previewErrorMessage = nil
                    previewNoticeMessage = nil
                    isPreviewFrameLoading = false
                }
            } catch {
                Task { @MainActor in
                    guard previewRequestID == requestID else { return }
                    previewNoticeMessage = "原始录屏存在，但应用内预览暂时无法读取画面；可用系统播放器打开。"
                    isPreviewFrameLoading = false
                }
            }
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard previewRequestID == requestID, isPreviewFrameLoading else { return }
            previewNoticeMessage = "原始录屏存在，预览仍在后台读取；你可以继续编辑或用系统播放器打开。"
            isPreviewFrameLoading = false
        }
    }

    private func resetPreview() {
        isPreviewLoaded = false
        isPreviewFrameLoading = false
        previewImage = nil
        previewErrorMessage = nil
        previewNoticeMessage = nil
    }

    private func saveCopy() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = "SmartRecord.mp4"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        coordinator.exportEditedVideoCopy(for: project, context: context, destination: url)
    }

    private func timeText(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var hasSourceVideo: Bool {
        guard let bundle else { return false }
        return FileManager.default.fileExists(atPath: bundle.screenVideo.path)
    }

    private var sourceVideoStatus: String {
        guard let bundle else {
            return "原始录屏：未找到项目目录"
        }
        return FileManager.default.fileExists(atPath: bundle.screenVideo.path)
            ? "原始录屏：\(bundle.screenVideo.lastPathComponent) · \(timeText(project.duration))"
            : "原始录屏：未选择"
    }

    private var smartFocusStatus: String {
        "SmartFocus：\(project.clickEvents.count) 次点击 · \(project.cursorSamples.count) 个轨迹点"
    }
}

private nonisolated enum EditorPreviewFrameLoader {
    static func imageData(from url: URL) throws -> Data {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1920, height: 1080)

        var lastError: Error?
        for seconds in [0.5, 0.1, 1.0, 0.0] {
            do {
                var actualTime = CMTime.zero
                let image = try generator.copyCGImage(
                    at: CMTime(seconds: seconds, preferredTimescale: 600),
                    actualTime: &actualTime
                )
                let bitmap = NSBitmapImageRep(cgImage: image)
                if let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.86]) {
                    return data
                }
            } catch {
                lastError = error
            }
        }

        throw lastError ?? CocoaError(.fileReadCorruptFile)
    }
}

private struct NonContinuousSlider: NSViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value)
    }

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider(
            value: value,
            minValue: range.lowerBound,
            maxValue: range.upperBound,
            target: context.coordinator,
            action: #selector(Coordinator.valueChanged(_:))
        )
        slider.isContinuous = false
        slider.controlSize = .large
        return slider
    }

    func updateNSView(_ slider: NSSlider, context: Context) {
        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound
        let clampedValue = min(max(value, range.lowerBound), range.upperBound)
        if abs(slider.doubleValue - clampedValue) > 0.0001 {
            slider.doubleValue = clampedValue
        }
    }

    final class Coordinator: NSObject {
        private var value: Binding<Double>

        init(value: Binding<Double>) {
            self.value = value
        }

        @objc func valueChanged(_ sender: NSSlider) {
            value.wrappedValue = sender.doubleValue
        }
    }
}
