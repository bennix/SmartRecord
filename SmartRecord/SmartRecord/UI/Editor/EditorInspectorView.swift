import SwiftData
import SwiftUI

struct EditorInspectorView: View {
    @Environment(\.modelContext) private var context
    @Bindable var project: Project
    let mode: RecordingEditorMode
    @Binding var playhead: Double
    @Binding var captionLanguage: CaptionLanguage
    let coordinator: RecordingCoordinator

    private var timeline: EditTimeline {
        project.ensureEditTimeline()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label(mode.rawValue, systemImage: mode.icon)
                    .font(.title2.weight(.bold))

                switch mode {
                case .cut:
                    cutPanel
                case .annotate:
                    annotationPanel
                case .smartFocus:
                    smartFocusPanel
                case .captions:
                    captionPanel
                case .export:
                    exportPanel
                }
            }
            .padding(18)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var cutPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("移动播放头后，可以切开当前段或删除当前段。拖动开始/结束时间只修改编辑决策，不会改动原始录制文件。")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                resetTimeline()
            } label: {
                Label("恢复完整时间轴", systemImage: "arrow.counterclockwise")
            }
        }
    }

    private var annotationPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            AnnotationToolbar(
                addText: { addAnnotation(.text) },
                addArrow: { addAnnotation(.arrow) },
                addHighlight: { addAnnotation(.highlightRectangle) },
                addBlur: { addAnnotation(.blur) },
                addImage: { coordinator.importAnnotationImage(for: project, context: context, at: playhead) }
            )

            ForEach(timeline.annotations.sorted { $0.startTime < $1.startTime }) { annotation in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(annotation.kind.rawValue, systemImage: icon(for: annotation.kind))
                        Spacer()
                        Button(role: .destructive) {
                            timeline.annotations.removeAll { $0 === annotation }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    if annotation.kind == .text {
                        TextField("文字", text: Bindable(annotation).text)
                    }
                    Stepper("开始 \(timeText(annotation.startTime))", value: Bindable(annotation).startTime, in: 0...max(timeline.duration, 0.1), step: 0.1)
                    Stepper("结束 \(timeText(annotation.endTime))", value: Bindable(annotation).endTime, in: annotation.startTime...max(timeline.duration, annotation.endTime), step: 0.1)
                    Slider(value: Bindable(annotation).opacity, in: 0.1...1) {
                        Text("透明度")
                    }
                }
                .padding(12)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var smartFocusPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                timeline.smartFocusKeyframes.append(SmartFocusKeyframe(time: playhead, nx: 0.5, ny: 0.5, zoomScale: 1.7))
            } label: {
                Label("在播放头添加聚焦点", systemImage: "plus.magnifyingglass")
            }

            ForEach(timeline.smartFocusKeyframes.sorted { $0.time < $1.time }) { keyframe in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("聚焦 \(timeText(keyframe.time))")
                            .font(.headline)
                        Spacer()
                        Button(role: .destructive) {
                            timeline.smartFocusKeyframes.removeAll { $0 === keyframe }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    Stepper("时间 \(timeText(keyframe.time))", value: Bindable(keyframe).time, in: 0...max(timeline.duration, 0.1), step: 0.1)
                    Slider(value: Bindable(keyframe).nx, in: 0...1) { Text("X") }
                    Slider(value: Bindable(keyframe).ny, in: 0...1) { Text("Y") }
                    Slider(value: Bindable(keyframe).zoomScale, in: 1...2.4) { Text("缩放") }
                }
                .padding(12)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var captionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("识别语言", selection: $captionLanguage) {
                ForEach(CaptionLanguage.defaults) { language in
                    Text(language.displayName).tag(language)
                }
            }
            Button {
                coordinator.generateLocalCaptions(for: project, context: context, language: captionLanguage)
            } label: {
                Label("使用 Apple 本地语音生成字幕", systemImage: "waveform.badge.mic")
            }
            .disabled(!project.audioCaptureMode.capturesAudio)

            ForEach(timeline.captions.sorted { $0.startTime < $1.startTime }) { caption in
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("启用", isOn: Bindable(caption).isEnabled)
                    TextField("字幕文字", text: Bindable(caption).text, axis: .vertical)
                    Stepper("开始 \(timeText(caption.startTime))", value: Bindable(caption).startTime, in: 0...max(timeline.duration, 0.1), step: 0.1)
                    Stepper("结束 \(timeText(caption.endTime))", value: Bindable(caption).endTime, in: caption.startTime...max(timeline.duration, caption.endTime), step: 0.1)
                }
                .padding(12)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var exportPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("包含注释", isOn: Binding(
                get: { timeline.exportSettings?.includeAnnotations ?? true },
                set: { timeline.exportSettings?.includeAnnotations = $0 }
            ))
            Toggle("包含 SmartFocus", isOn: Binding(
                get: { timeline.exportSettings?.includeSmartFocus ?? true },
                set: { timeline.exportSettings?.includeSmartFocus = $0 }
            ))
            Toggle("把字幕烧录进视频", isOn: Binding(
                get: { timeline.exportSettings?.burnCaptions ?? false },
                set: { timeline.exportSettings?.burnCaptions = $0 }
            ))
            Divider()
            Button {
                coordinator.regenerateVideo(for: project, context: context)
            } label: {
                Label("更新项目 final.mp4", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func addAnnotation(_ kind: AnnotationKind) {
        timeline.annotations.append(
            AnnotationItem(
                kind: kind,
                startTime: playhead,
                endTime: min(playhead + 4, max(timeline.duration, playhead + 4)),
                normalizedX: 0.18,
                normalizedY: 0.18,
                normalizedWidth: 0.34,
                normalizedHeight: 0.16,
                text: kind == .text ? "注释" : ""
            )
        )
    }

    private func resetTimeline() {
        timeline.segments = [EditSegment(sourceStartTime: 0, sourceEndTime: project.duration)]
        playhead = 0
    }

    private func icon(for kind: AnnotationKind) -> String {
        switch kind {
        case .text: "textformat"
        case .arrow: "arrow.up.right"
        case .highlightRectangle: "rectangle"
        case .highlightEllipse: "circle"
        case .blur: "eye.slash"
        case .image: "photo"
        }
    }

    private func timeText(_ time: Double) -> String {
        String(format: "%.1fs", time)
    }
}
