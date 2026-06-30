import AVKit
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
    @State private var player = AVPlayer()
    @State private var captionLanguage = CaptionLanguage.defaults[0]
    @State private var preparedTimeline: EditTimeline?
    @State private var isPreviewLoaded = false

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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            loadPreviewVideoIfNeeded()
        }
        .onDisappear {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
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
                    if isPreviewLoaded {
                        VideoPlayer(player: player)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else if bundle != nil {
                        VStack(spacing: 14) {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 48, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.82))
                            Text("正在加载视频预览")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                            Button {
                                loadPreviewVideo()
                            } label: {
                                Label("重新加载预览", systemImage: "arrow.clockwise")
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
                Slider(value: $playhead, in: 0...max(timeline.duration, 0.1)) {
                    Text("Playhead")
                }
                Button {
                    if !isPreviewLoaded {
                        loadPreviewVideo()
                    }
                    player.seek(to: CMTime(seconds: playhead, preferredTimescale: 600))
                    player.play()
                } label: {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(.bordered)
                .help("从当前位置播放")
            }
            .padding(10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding(14)
        }
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
        guard let bundle else { return }
        let url = FileManager.default.fileExists(atPath: bundle.finalVideo.path) ? bundle.finalVideo : bundle.screenVideo
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        isPreviewLoaded = true
    }

    private func loadPreviewVideoIfNeeded() {
        guard !isPreviewLoaded else { return }
        loadPreviewVideo()
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
}
