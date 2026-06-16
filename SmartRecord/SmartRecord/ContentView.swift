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
