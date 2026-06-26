import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]
    @State private var coordinator = RecordingCoordinator()
    @AppStorage(AppLanguageStore.userDefaultsKey) private var languageRawValue = AppLanguage.zhHans.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRawValue) ?? .zhHans
    }

    private var t: AppStrings {
        AppStrings(language)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()

            mainContent
        }
        .frame(minWidth: 1240, minHeight: 760)
        .background(appBackground)
        .onChange(of: languageRawValue) { _, _ in
            coordinator.refreshLocalizedText()
        }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SmartRecord")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                    Text(t(.appSubtitle))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Picker(t(.language), selection: $languageRawValue) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.nativeName).tag(language.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.large)

                recordPanel
                captureHealthPanel
                whisperPanel

                if let lastProjectDirectory = coordinator.lastProjectDirectory, !coordinator.isRecording {
                    Button {
                        coordinator.revealLastProject()
                    } label: {
                        Label(lastProjectDirectory.lastPathComponent, systemImage: "folder")
                            .font(.body)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .help(lastProjectDirectory.path)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.automatic)
        .frame(width: 390, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
    }

    private var recordPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(recordAccent.opacity(coordinator.isRecording ? 0.22 : 0.12))
                    Image(systemName: coordinator.isRecording ? "waveform.circle.fill" : "record.circle")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(recordAccent)
                }
                .frame(width: 62, height: 62)

                VStack(alignment: .leading, spacing: 5) {
                    Text(coordinator.statusMessage)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(recordingDetail)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 10) {
                Label(t(.audioMode), systemImage: coordinator.selectedAudioMode.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(minimum: 138), spacing: 10),
                        GridItem(.flexible(minimum: 138), spacing: 10)
                    ],
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(AudioCaptureMode.allCases, id: \.self) { mode in
                        audioModeButton(mode)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(coordinator.isRecording || coordinator.isStarting ? 0.62 : 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                Label(t(.recordingFrameRate), systemImage: "speedometer")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(RecordingFrameRate.allCases, id: \.self) { frameRate in
                        frameRateButton(frameRate)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(coordinator.isRecording || coordinator.isStarting ? 0.62 : 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(isOn: $coordinator.shouldGenerateSubtitles) {
                Label(t(.generateVTTSubtitles), systemImage: "captions.bubble")
                    .font(.body.weight(.semibold))
            }
            .toggleStyle(.switch)
            .controlSize(.large)
            .disabled(coordinator.isRecording || coordinator.isStarting || !coordinator.selectedAudioMode.capturesAudio)
            .opacity(coordinator.isRecording || coordinator.isStarting || !coordinator.selectedAudioMode.capturesAudio ? 0.62 : 1)

            if let failureMessage = coordinator.failureMessage {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(failureMessage)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
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
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(coordinator.isRecording ? .red : Color(red: 0.05, green: 0.35, blue: 0.68))
            .disabled(coordinator.isStarting)
        }
        .panelStyle()
    }

    private func audioModeButton(_ mode: AudioCaptureMode) -> some View {
        let isSelected = coordinator.selectedAudioMode == mode
        let isDisabled = coordinator.isRecording || coordinator.isStarting

        return Button {
            coordinator.selectedAudioMode = mode
        } label: {
            HStack(spacing: 7) {
                Image(systemName: mode.icon)
                    .font(.body.weight(.semibold))
                    .frame(width: 20)
                Text(t.audioModeLabel(mode))
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity, minHeight: 42)
            .foregroundColor(isSelected ? .white : .primary)
            .background(
                isSelected
                ? Color(red: 0.05, green: 0.35, blue: 0.68)
                : Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 7)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isSelected ? Color.clear : Color(nsColor: .separatorColor).opacity(0.38))
            }
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(t.audioModeLabel(mode))
    }

    private func frameRateButton(_ frameRate: RecordingFrameRate) -> some View {
        let isSelected = coordinator.selectedFrameRate == frameRate
        let isDisabled = coordinator.isRecording || coordinator.isStarting

        return Button {
            coordinator.selectedFrameRate = frameRate
        } label: {
            Text("\(frameRate.rawValue)")
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .frame(maxWidth: .infinity, minHeight: 38)
                .foregroundColor(isSelected ? .white : .primary)
                .background(
                    isSelected
                    ? Color(red: 0.05, green: 0.35, blue: 0.68)
                    : Color(nsColor: .controlBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 7)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isSelected ? Color.clear : Color(nsColor: .separatorColor).opacity(0.38))
                }
                .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(t.frameRateLabel(frameRate))
    }

    private var captureHealthPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelTitle(t(.capturePipeline), icon: "dot.radiowaves.left.and.right")

            healthRow(
                title: t(.screenAndSystemAudio),
                detail: coordinator.screenRecordingPermissionMissing ? t(.screenRecordingPermissionRequired) : "ScreenCaptureKit",
                icon: coordinator.screenRecordingPermissionMissing ? "lock.trianglebadge.exclamationmark" : "display",
                state: coordinator.screenRecordingPermissionMissing ? .warning : .ready,
                actionTitle: coordinator.screenRecordingPermissionMissing ? t(.openSettings) : nil,
                action: coordinator.openScreenRecordingSettings
            )

            healthRow(
                title: t(.mouseClickSmartFocus),
                detail: t(.clickAreaAutoZoom),
                icon: "cursorarrow.click.2",
                state: .ready
            )

            healthRow(
                title: t(.audioMix),
                detail: "\(t.audioModeLabel(coordinator.selectedAudioMode)) / \(t.frameRateLabel(coordinator.selectedFrameRate))",
                icon: coordinator.selectedAudioMode.icon,
                state: .ready
            )
        }
        .panelStyle()
    }

    private var whisperPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelTitle(t(.whisperSubtitles), icon: "captions.bubble")

            healthRow(
                title: t(.mediumModel),
                detail: coordinator.whisperModelMessage,
                icon: coordinator.whisperModelInstalled ? "checkmark.seal.fill" : "arrow.down.circle",
                state: coordinator.whisperModelInstalled ? .ready : .warning
            )

            if let whisperModelPath = coordinator.whisperModelPath {
                Text(whisperModelPath.path)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            if coordinator.isDownloadingWhisperModel {
                VStack(alignment: .leading, spacing: 6) {
                    if let progress = coordinator.whisperModelDownloadProgress {
                        ProgressView(value: progress)
                        Text("\(Int(progress * 100))%")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    } else {
                        ProgressView()
                        Text(t(.connectingDownloadSource))
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    coordinator.downloadWhisperMediumModel()
                } label: {
                    Label(
                        coordinator.isDownloadingWhisperModel ? t(.downloading) : t(.downloadMedium),
                        systemImage: coordinator.isDownloadingWhisperModel ? "hourglass" : "arrow.down"
                    )
                    .font(.title3.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(coordinator.isDownloadingWhisperModel || coordinator.whisperModelInstalled)

                Button {
                    coordinator.revealWhisperModelFolder()
                } label: {
                    Image(systemName: "folder")
                        .frame(width: 24)
                }
                .buttonStyle(.bordered)
                .help(t(.openModelFolder))

                Button {
                    coordinator.openWhisperModelDownloadPage()
                } label: {
                    Image(systemName: "safari")
                        .frame(width: 24)
                }
                .buttonStyle(.bordered)
                .help(t(.openModelDownloadPage))
            }
        }
        .panelStyle()
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(t(.recordingProjects))
                        .font(.system(size: 32, weight: .semibold))
                    Text(t(.projectsDescription))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)
                Spacer()
                metric(t(.projectsMetric), value: "\(projects.count)", icon: "film.stack")
                metric(t(.eventsMetric), value: "\(coordinator.lastEventCount)", icon: "cursorarrow.motionlines")
            }

            if projects.isEmpty {
                ContentUnavailableView(
                    t(.noRecordings),
                    systemImage: "record.circle",
                    description: Text(t(.noRecordingsDescription))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(projects) { project in
                            projectRow(project)
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
        }
        .padding(28)
    }

    private var recordButtonTitle: String {
        if coordinator.isStarting { return t(.starting) }
        return coordinator.isRecording ? t(.stopRecording) : t(.startRecording)
    }

    private var recordButtonIcon: String {
        if coordinator.isStarting { return "hourglass" }
        return coordinator.isRecording ? "stop.fill" : "record.circle"
    }

    private var statusColor: Color {
        if coordinator.isRecording { return .red }
        if coordinator.failureMessage != nil { return .red }
        return .primary
    }

    private var recordAccent: Color {
        coordinator.isRecording ? .red : Color(red: 0.05, green: 0.35, blue: 0.68)
    }

    private var recordingDetail: String {
        if let started = coordinator.recordingStartedAt {
            return t.startedAt(started.formatted(date: .omitted, time: .shortened))
        }
        let subtitle = coordinator.shouldGenerateSubtitles && coordinator.selectedAudioMode.capturesAudio
            ? "VTT"
            : t(.noSubtitles)
        return "\(t.frameRateLabel(coordinator.selectedFrameRate)) / H.264 MP4 / \(subtitle)"
    }

    private var appBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(red: 0.94, green: 0.97, blue: 0.98)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func projectRow(_ project: Project) -> some View {
        let assets = projectAssets(project)
        let expectsSubtitles = project.generatesSubtitles && project.audioCaptureMode.capturesAudio
        let visibleWarnings = project.warnings.filter { warning in
            warning != .audioConverterNotInstalled || !WhisperTranscriber().hasAudioConverter()
        }

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(rowAccent(for: project.status).opacity(0.13))
                    Image(systemName: assets.hasFinalVideo ? "play.rectangle.fill" : "film")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(rowAccent(for: project.status))
                }
                .frame(width: 68, height: 56)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(project.createdAt, format: .dateTime.month().day().hour().minute())
                            .font(.title2.weight(.semibold))
                        Text(durationText(project.duration))
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                        tag(statusLabel(project.status), icon: statusIcon(project.status), tint: rowAccent(for: project.status))
                        tag(t.audioModeLabel(project.audioCaptureMode), icon: project.audioCaptureMode.icon, tint: .purple)
                        tag(t.frameRateLabel(project.frameRate), icon: "speedometer", tint: .indigo)
                        tag(assets.hasFinalVideo ? "H.264 MP4" : t(.waitingMP4), icon: "video", tint: assets.hasFinalVideo ? .green : .secondary)
                        tag(
                            assets.hasFinalVTT ? "VTT medium" : expectsSubtitles ? t(.waitingVTT) : t(.skipVTT),
                            icon: "captions.bubble",
                            tint: assets.hasFinalVTT ? .green : expectsSubtitles ? .secondary : .orange
                        )
                        tag(
                            project.clickEvents.isEmpty ? "SmartFocus \(project.cursorSamples.count)" : "SmartFocus \(project.clickEvents.count)",
                            icon: "cursorarrow.click",
                            tint: project.clickEvents.isEmpty && project.cursorSamples.isEmpty ? .orange : .blue
                        )
                    }
                }
                .layoutPriority(1)

                HStack(spacing: 10) {
                    rowAction(t(.play), icon: "play.fill") {
                        coordinator.open(project: project)
                    }
                    rowAction("Finder", icon: "folder") {
                        coordinator.reveal(project: project)
                    }
                    rowAction(t(.video), icon: "arrow.triangle.2.circlepath") {
                        coordinator.regenerateVideo(for: project, context: context)
                    }
                    rowAction(t(.subtitles), icon: "captions.bubble") {
                        coordinator.regenerateSubtitles(for: project, context: context)
                    }
                    rowAction(t(.delete), icon: "trash", role: .destructive) {
                        delete(project)
                    }
                }
            }

            WrappingHStack(horizontalSpacing: 12, verticalSpacing: 8) {
                assetBadge("screen.mov", ready: assets.hasScreenVideo)
                assetBadge("system.m4a", ready: assets.hasSystemAudio, expected: project.audioCaptureMode.capturesSystemAudio)
                assetBadge("microphone.m4a", ready: assets.hasMicrophoneAudio, expected: project.audioCaptureMode.capturesMicrophone)
                assetBadge("final.mp4", ready: assets.hasFinalVideo)
                assetBadge("final.vtt", ready: assets.hasFinalVTT, expected: expectsSubtitles)
            }

            if !visibleWarnings.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(visibleWarnings.map(warningLabel).joined(separator: " / "))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.88), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35))
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            coordinator.open(project: project)
        }
        .contextMenu {
            Button { coordinator.open(project: project) } label: {
                Label(t(.playRecording), systemImage: "play.rectangle")
            }
            Button { coordinator.regenerateVideo(for: project, context: context) } label: {
                Label(t(.regenerateVideo), systemImage: "arrow.triangle.2.circlepath")
            }
            Button { coordinator.regenerateSubtitles(for: project, context: context) } label: {
                Label(t(.regenerateSubtitles), systemImage: "captions.bubble")
            }
            Button { coordinator.reveal(project: project) } label: {
                Label(t(.showInFinder), systemImage: "folder")
            }
            Button(role: .destructive) { delete(project) } label: {
                Label(t(.delete), systemImage: "trash")
            }
        }
    }

    private func panelTitle(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.title2.weight(.semibold))
    }

    private func healthRow(
        title: String,
        detail: String,
        icon: String,
        state: HealthState,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(state.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.medium))
                Text(detail)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    private func metric(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title2.weight(.semibold))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
    }

    private func rowAction(
        _ title: String,
        icon: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Image(systemName: icon)
                .font(.title3.weight(.medium))
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.borderless)
        .help(title)
    }

    private func assetBadge(_ text: String, ready: Bool, expected: Bool = true) -> some View {
        let icon = ready ? "checkmark.circle.fill" : expected ? "circle" : "minus.circle"
        let color: Color = ready ? .secondary : expected ? .orange : .secondary
        let suffix = expected ? "" : " \(t(.skipped))"

        return Label(text + suffix, systemImage: icon)
            .font(.body)
            .foregroundStyle(color)
            .lineLimit(1)
    }

    private func tag(_ text: String, icon: String, tint: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.body)
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }

    private func durationText(_ duration: Double) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func projectAssets(_ project: Project) -> ProjectAssetPresence {
        guard let bundle = coordinator.recordingBundle(for: project) else {
            return ProjectAssetPresence(
                hasScreenVideo: false,
                hasSystemAudio: false,
                hasMicrophoneAudio: false,
                hasFinalVideo: false,
                hasFinalVTT: false
            )
        }
        return ProjectAssetPresence(
            hasScreenVideo: FileManager.default.fileExists(atPath: bundle.screenVideo.path),
            hasSystemAudio: FileManager.default.fileExists(atPath: bundle.systemAudio.path),
            hasMicrophoneAudio: FileManager.default.fileExists(atPath: bundle.microphoneAudio.path),
            hasFinalVideo: FileManager.default.fileExists(atPath: bundle.finalVideo.path),
            hasFinalVTT: FileManager.default.fileExists(atPath: bundle.finalVTT.path)
        )
    }

    private func statusLabel(_ status: ProjectStatus) -> String {
        switch status {
        case .recording:
            return t(.recording)
        case .recorded:
            return t(.saved)
        case .renderingVideo:
            return t(.renderingVideo)
        case .transcribing:
            return t(.transcribing)
        case .completed:
            return t(.completed)
        case .videoFailed:
            return t(.videoFailed)
        case .subtitleFailed:
            return t(.subtitleFailed)
        }
    }

    private func statusIcon(_ status: ProjectStatus) -> String {
        switch status {
        case .recording:
            return "record.circle"
        case .recorded:
            return "tray.and.arrow.down"
        case .renderingVideo:
            return "film"
        case .transcribing:
            return "captions.bubble"
        case .completed:
            return "checkmark.circle"
        case .videoFailed, .subtitleFailed:
            return "exclamationmark.triangle"
        }
    }

    private func rowAccent(for status: ProjectStatus) -> Color {
        switch status {
        case .completed:
            return .green
        case .renderingVideo, .transcribing:
            return .blue
        case .videoFailed, .subtitleFailed:
            return .red
        case .recording:
            return .red
        case .recorded:
            return Color(red: 0.05, green: 0.35, blue: 0.68)
        }
    }

    private func warningLabel(_ warning: ProjectWarning) -> String {
        switch warning {
        case .missingMicrophoneAudio:
            return t(.missingMicrophoneAudio)
        case .missingSystemAudio:
            return t(.missingSystemAudio)
        case .missingSubtitleAudio:
            return t(.missingSubtitleAudio)
        case .whisperCommandNotInstalled:
            return t(.whisperCommandNotInstalled)
        case .whisperMediumModelMissing:
            return t(.whisperMediumModelMissing)
        case .audioConverterNotInstalled:
            return t(.audioConverterNotInstalled)
        }
    }

    private func delete(_ project: Project) {
        if let bundle = coordinator.recordingBundle(for: project) {
            try? FileManager.default.removeItem(at: bundle.directory)
        }
        context.delete(project)
        try? context.save()
    }
}

private enum HealthState {
    case ready
    case warning

    var color: Color {
        switch self {
        case .ready:
            return .green
        case .warning:
            return .orange
        }
    }
}

private struct PanelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.86), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.34))
            )
    }
}

private struct WrappingHStack: Layout {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return layout(sizes: sizes, maxWidth: proposal.width).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let placements = layout(sizes: sizes, maxWidth: bounds.width).placements

        for index in subviews.indices {
            let size = sizes[index]
            let point = placements[index]
            subviews[index].place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
        }
    }

    private func layout(sizes: [CGSize], maxWidth proposedWidth: CGFloat?) -> (size: CGSize, placements: [CGPoint]) {
        let maxWidth = max(1, proposedWidth ?? CGFloat.greatestFiniteMagnitude)
        var placements: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var contentWidth: CGFloat = 0

        for size in sizes {
            if x > 0, x + size.width > maxWidth {
                y += rowHeight + verticalSpacing
                x = 0
                rowHeight = 0
            }

            placements.append(CGPoint(x: x, y: y))
            contentWidth = max(contentWidth, x + size.width)
            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }

        return (CGSize(width: min(maxWidth, contentWidth), height: y + rowHeight), placements)
    }
}

private extension View {
    func panelStyle() -> some View {
        modifier(PanelStyle())
    }
}

private struct ProjectAssetPresence {
    let hasScreenVideo: Bool
    let hasSystemAudio: Bool
    let hasMicrophoneAudio: Bool
    let hasFinalVideo: Bool
    let hasFinalVTT: Bool
}
