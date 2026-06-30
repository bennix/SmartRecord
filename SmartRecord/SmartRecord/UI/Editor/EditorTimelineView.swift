import SwiftUI

struct EditorTimelineView: View {
    @Bindable var project: Project
    @Binding var playhead: Double

    private var timeline: EditTimeline {
        project.ensureEditTimeline()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("时间轴", systemImage: "timeline.selection")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button {
                    splitAtPlayhead()
                } label: {
                    Label("切开", systemImage: "scissors")
                }
                Button(role: .destructive) {
                    deleteSegmentAtPlayhead()
                } label: {
                    Label("删除当前段", systemImage: "trash")
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                    ForEach(TimelineMapper.normalizedSegments(from: timeline.segments)) { segment in
                        segmentBlock(segment, width: proxy.size.width)
                    }
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 2)
                        .offset(x: proxy.size.width * playheadRatio)
                }
            }
            .frame(height: 74)

            List {
                ForEach(TimelineMapper.normalizedSegments(from: timeline.segments)) { segment in
                    HStack(spacing: 12) {
                        Image(systemName: "film")
                            .foregroundStyle(.blue)
                        Text("\(timeText(segment.timelineStartTime)) - \(timeText(segment.timelineStartTime + segment.duration))")
                            .monospacedDigit()
                            .frame(width: 150, alignment: .leading)
                        Stepper("开始 \(timeText(segment.sourceStartTime))", value: binding(for: segment, keyPath: \EditSegment.sourceStartTime), in: 0...max(segment.sourceEndTime, 0), step: 0.1)
                        Stepper("结束 \(timeText(segment.sourceEndTime))", value: binding(for: segment, keyPath: \EditSegment.sourceEndTime), in: segment.sourceStartTime...max(project.duration, segment.sourceEndTime), step: 0.1)
                    }
                    .font(.body)
                }
            }
            .frame(minHeight: 160)
        }
        .padding(16)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private var playheadRatio: Double {
        guard timeline.duration > 0 else { return 0 }
        return min(max(playhead / timeline.duration, 0), 1)
    }

    private func segmentBlock(_ segment: EditSegment, width: CGFloat) -> some View {
        let total = max(timeline.duration, 0.1)
        let x = width * segment.timelineStartTime / total
        let w = max(12, width * segment.duration / total)
        return RoundedRectangle(cornerRadius: 6)
            .fill(Color.blue.opacity(0.72))
            .overlay(alignment: .leading) {
                Text(timeText(segment.duration))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
            }
            .frame(width: w, height: 46)
            .offset(x: x)
            .onTapGesture {
                playhead = segment.timelineStartTime
            }
    }

    private func splitAtPlayhead() {
        guard let segment = TimelineMapper.normalizedSegments(from: timeline.segments).first(where: {
            $0.timelineStartTime < playhead && playhead < $0.timelineStartTime + $0.duration
        }) else { return }
        let result = TimelineEditing.split(segment, atTimelineTime: playhead)
        TimelineEditing.replace(segment, in: timeline, with: [result.left, result.right])
    }

    private func deleteSegmentAtPlayhead() {
        guard let segment = TimelineMapper.normalizedSegments(from: timeline.segments).first(where: {
            $0.timelineStartTime <= playhead && playhead <= $0.timelineStartTime + $0.duration
        }) else { return }
        TimelineEditing.delete(segment, in: timeline)
    }

    private func binding(for segment: EditSegment, keyPath: ReferenceWritableKeyPath<EditSegment, Double>) -> Binding<Double> {
        Binding {
            segment[keyPath: keyPath]
        } set: { value in
            segment[keyPath: keyPath] = value
            if segment.sourceEndTime < segment.sourceStartTime {
                segment.sourceEndTime = segment.sourceStartTime
            }
            _ = TimelineMapper.normalizedSegments(from: timeline.segments)
        }
    }

    private func timeText(_ time: Double) -> String {
        String(format: "%.1fs", time)
    }
}
