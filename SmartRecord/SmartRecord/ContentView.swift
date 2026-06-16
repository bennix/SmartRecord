import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]
    @State private var coordinator = RecordingCoordinator()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("SmartRecord")
                    .font(.largeTitle.bold())
                Spacer()
                Button {
                    Task {
                        if coordinator.isRecording {
                            await coordinator.stopRecording(context: context)
                        } else {
                            await coordinator.startRecording()
                        }
                    }
                } label: {
                    Text(recordButtonTitle)
                        .frame(minWidth: 96)
                }
                .controlSize(.large)
                .disabled(coordinator.isStarting)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(coordinator.statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if let failureMessage = coordinator.failureMessage {
                    Text(failureMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }

                if coordinator.screenRecordingPermissionMissing {
                    Button {
                        coordinator.openScreenRecordingSettings()
                    } label: {
                        Label("打开屏幕录制设置", systemImage: "macwindow.badge.plus")
                    }
                    .buttonStyle(.borderless)
                }

                if coordinator.permissionMissing {
                    HStack(spacing: 8) {
                        Label("未获辅助功能权限，鼠标事件不会被记录。", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Button("打开辅助功能设置") {
                            coordinator.openAccessibilitySettings()
                        }
                        .buttonStyle(.borderless)
                    }
                    .font(.callout)
                }

                if coordinator.lastEventCount > 0 {
                    Text("上次录制事件数：\(coordinator.lastEventCount)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
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
                    .buttonStyle(.borderless)
                }
            }

            Divider()

            Text("最近项目")
                .font(.headline)

            List {
                ForEach(projects) { project in
                    projectRow(project)
                        .contextMenu {
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
        }
        .padding()
        .frame(minWidth: 560, minHeight: 480)
    }

    private var recordButtonTitle: String {
        if coordinator.isStarting {
            return "正在启动"
        }
        return coordinator.isRecording ? "停止录制" : "开始录制"
    }

    private func projectRow(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(project.createdAt, format: .dateTime)
                Spacer()
                Text("\(project.clickEvents.count) 点击 / \(project.cursorSamples.count) 轨迹")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                tag(project.status.rawValue, icon: "circle.dashed")
                if !project.warnings.isEmpty {
                    tag("\(project.warnings.count) 警告", icon: "exclamationmark.triangle")
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func tag(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
    }

    private func delete(_ project: Project) {
        let bundle = coordinator.recordingBundle(for: project)
        try? FileManager.default.removeItem(at: bundle.directory)
        context.delete(project)
        try? context.save()
    }
}
