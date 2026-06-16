import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]
    @State private var coordinator = RecordingCoordinator()

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            HStack(alignment: .top, spacing: 0) {
                sidebar

                Divider()

                recordingsList
            }
        }
        .frame(minWidth: 860, minHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("SmartRecord")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                Text(coordinator.statusMessage)
                    .font(.callout)
                    .foregroundStyle(statusColor)
            }

            Spacer()

            if let failureMessage = coordinator.failureMessage {
                Text(failureMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .textSelection(.enabled)
                    .frame(maxWidth: 360, alignment: .trailing)
            }

            Button {
                Task {
                    if coordinator.isRecording {
                        await coordinator.stopRecording(context: context)
                    } else {
                        await coordinator.startRecording()
                    }
                }
            } label: {
                Label(recordButtonTitle, systemImage: recordButtonIcon)
                    .frame(minWidth: 126)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(coordinator.isRecording ? .red : .accentColor)
            .disabled(coordinator.isStarting)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                metric("项目", value: "\(projects.count)", icon: "film.stack")
                metric("上次事件", value: "\(coordinator.lastEventCount)", icon: "cursorarrow.motionlines")
            }

            if let lastProjectDirectory = coordinator.lastProjectDirectory, !coordinator.isRecording {
                Button {
                    coordinator.revealLastProject()
                } label: {
                    Label(lastProjectDirectory.lastPathComponent, systemImage: "folder")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
            }

            if coordinator.screenRecordingPermissionMissing {
                permissionButton(
                    "屏幕录制权限",
                    detail: "允许后重新打开应用",
                    icon: "macwindow.badge.plus",
                    action: coordinator.openScreenRecordingSettings
                )
            }

            if coordinator.permissionMissing {
                permissionButton(
                    "辅助功能权限",
                    detail: "用于记录鼠标点击轨迹",
                    icon: "exclamationmark.triangle",
                    action: coordinator.openAccessibilitySettings
                )
            }

            Spacer()
        }
        .padding(18)
        .frame(width: 238)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var recordingsList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("最近录制")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("点击项目即可播放 screen.mov")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if projects.isEmpty {
                ContentUnavailableView(
                    "还没有录制",
                    systemImage: "record.circle",
                    description: Text("点击右上角开始录制。")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(projects) { project in
                        projectRow(project)
                            .listRowInsets(EdgeInsets(top: 7, leading: 0, bottom: 7, trailing: 0))
                            .listRowSeparator(.hidden)
                            .contextMenu {
                                Button {
                                    coordinator.open(project: project)
                                } label: {
                                    Label("播放录制", systemImage: "play.rectangle")
                                }
                                Button {
                                    coordinator.reveal(project: project)
                                } label: {
                                    Label("在 Finder 中显示", systemImage: "folder")
                                }
                                Button(role: .destructive) {
                                    delete(project)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete { offsets in
                        offsets.map { projects[$0] }.forEach(delete)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .padding(20)
    }

    private var recordButtonTitle: String {
        if coordinator.isStarting { return "正在启动" }
        return coordinator.isRecording ? "停止录制" : "开始录制"
    }

    private var recordButtonIcon: String {
        if coordinator.isStarting { return "hourglass" }
        return coordinator.isRecording ? "stop.fill" : "record.circle"
    }

    private var statusColor: Color {
        if coordinator.isRecording { return .red }
        if coordinator.failureMessage != nil { return .red }
        return .secondary
    }

    private func projectRow(_ project: Project) -> some View {
        HStack(spacing: 10) {
            Button {
                coordinator.open(project: project)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(project.createdAt, format: .dateTime.month().day().hour().minute())
                                .font(.headline)
                            Text(durationText(project.duration))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            tag(project.status.rawValue, icon: "circle.dashed")
                            tag("\(project.clickEvents.count) 点击", icon: "cursorarrow.click")
                            tag("\(project.cursorSamples.count) 轨迹", icon: "point.topleft.down.curvedto.point.bottomright.up")
                            if !project.warnings.isEmpty {
                                tag("\(project.warnings.count) 警告", icon: "exclamationmark.triangle")
                            }
                        }
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                coordinator.reveal(project: project)
            } label: {
                Image(systemName: "folder")
            }
            .help("在 Finder 中显示")

            Button(role: .destructive) {
                delete(project)
            } label: {
                Image(systemName: "trash")
            }
            .help("删除项目")
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45))
        )
    }

    private func metric(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private func permissionButton(_ title: String, detail: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(.orange)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.medium))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .buttonStyle(.bordered)
    }

    private func tag(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
    }

    private func durationText(_ duration: Double) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func delete(_ project: Project) {
        if let bundle = coordinator.recordingBundle(for: project) {
            try? FileManager.default.removeItem(at: bundle.directory)
        }
        context.delete(project)
        try? context.save()
    }
}
