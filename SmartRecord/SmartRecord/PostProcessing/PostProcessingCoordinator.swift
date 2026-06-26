import Foundation
import SwiftData

@MainActor
@Observable
final class PostProcessingCoordinator {
    private let assetStore: ProjectAssetStore
    private let videoExporter: VideoExporter
    private let whisperTranscriber: WhisperTranscriber

    init(
        assetStore: ProjectAssetStore = ProjectAssetStore(),
        videoExporter: VideoExporter = VideoExporter(),
        whisperTranscriber: WhisperTranscriber = WhisperTranscriber()
    ) {
        self.assetStore = assetStore
        self.videoExporter = videoExporter
        self.whisperTranscriber = whisperTranscriber
    }

    func process(project: Project, context: ModelContext) async {
        await renderFinalVideo(project: project, context: context)
        guard project.status != .videoFailed else { return }
        await transcribeSubtitles(project: project, context: context)
    }

    func renderFinalVideo(project: Project, context: ModelContext) async {
        guard let bundle = try? assetStore.bundle(named: project.assetDirectoryName) else {
            project.status = .videoFailed
            save(context)
            return
        }

        project.status = .renderingVideo
        save(context)

        do {
            try await videoExporter.export(
                bundle: bundle,
                clickEvents: smartFocusEvents(for: project),
                audioMode: project.audioCaptureMode,
                options: renderOptions(for: project)
            )
            project.status = .recorded
            save(context)
        } catch {
            project.status = .videoFailed
            save(context)
        }
    }

    func transcribeSubtitles(project: Project, context: ModelContext) async {
        let subtitleWarnings: Set<ProjectWarning> = [
            .whisperCommandNotInstalled,
            .missingSubtitleAudio,
            .whisperMediumModelMissing,
            .audioConverterNotInstalled
        ]

        guard let bundle = try? assetStore.bundle(named: project.assetDirectoryName) else {
            project.status = .subtitleFailed
            save(context)
            return
        }

        guard project.generatesSubtitles, project.audioCaptureMode.capturesAudio else {
            project.status = .completed
            save(context)
            return
        }

        project.removeWarnings(subtitleWarnings)
        project.status = .transcribing
        save(context)

        do {
            try await whisperTranscriber.transcribe(bundle: bundle, audioMode: project.audioCaptureMode)
            project.removeWarnings(subtitleWarnings)
            project.status = .completed
            save(context)
        } catch WhisperTranscriberError.missingCommand {
            project.addWarning(.whisperCommandNotInstalled)
            project.status = .subtitleFailed
            save(context)
        } catch WhisperTranscriberError.missingSubtitleAudio {
            project.addWarning(.missingSubtitleAudio)
            project.status = .subtitleFailed
            save(context)
        } catch WhisperTranscriberError.missingMediumModel {
            project.addWarning(.whisperMediumModelMissing)
            project.status = .subtitleFailed
            save(context)
        } catch WhisperTranscriberError.missingAudioConverter {
            project.addWarning(.audioConverterNotInstalled)
            project.status = .subtitleFailed
            save(context)
        } catch {
            project.status = .subtitleFailed
            save(context)
        }
    }

    private func renderOptions(for project: Project) -> VideoRenderOptions {
        guard let settings = project.settings else {
            return VideoRenderOptions(
                zoomEnabled: true,
                zoomScale: 1.6,
                microphoneGain: 0.70,
                systemGain: 0.45,
                frameRate: project.frameRate
            )
        }
        let mix = min(max(settings.micSystemMix, 0), 1)
        return VideoRenderOptions(
            zoomEnabled: settings.zoomEnabled,
            zoomScale: settings.zoomScale,
            microphoneGain: Float(0.25 + 0.65 * mix),
            systemGain: Float(0.25 + 0.55 * (1 - mix)),
            frameRate: project.frameRate
        )
    }

    private func smartFocusEvents(for project: Project) -> [SmartFocusEvent] {
        let clickEvents = project.clickEvents.map {
            SmartFocusEvent(time: $0.time, nx: $0.nx, ny: $0.ny)
        }
        if !clickEvents.isEmpty {
            return clickEvents
        }

        let sortedSamples = project.cursorSamples.sorted { $0.time < $1.time }
        var events: [SmartFocusEvent] = []
        var lastAccepted: CursorSample?

        for sample in sortedSamples {
            guard sample.time.isFinite else { continue }
            if let lastAccepted {
                let movedEnough = abs(sample.nx - lastAccepted.nx) >= 0.06
                    || abs(sample.ny - lastAccepted.ny) >= 0.06
                guard sample.time - lastAccepted.time >= 0.9 && movedEnough else {
                    continue
                }
            }
            events.append(SmartFocusEvent(time: sample.time, nx: sample.nx, ny: sample.ny))
            lastAccepted = sample
        }

        return events
    }

    private func save(_ context: ModelContext) {
        try? context.save()
    }
}
