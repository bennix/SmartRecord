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
                clickEvents: project.clickEvents.map {
                    SmartFocusEvent(time: $0.time, nx: $0.nx, ny: $0.ny)
                },
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
        guard let bundle = try? assetStore.bundle(named: project.assetDirectoryName) else {
            project.status = .subtitleFailed
            save(context)
            return
        }

        project.status = .transcribing
        save(context)

        do {
            try await whisperTranscriber.transcribe(bundle: bundle)
            project.status = .completed
            save(context)
        } catch WhisperTranscriberError.missingCommand {
            project.addWarning(.whisperCommandNotInstalled)
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
        guard let settings = project.settings else { return .defaults }
        let mix = min(max(settings.micSystemMix, 0), 1)
        return VideoRenderOptions(
            zoomEnabled: settings.zoomEnabled,
            zoomScale: settings.zoomScale,
            microphoneGain: Float(0.25 + 0.65 * mix),
            systemGain: Float(0.25 + 0.55 * (1 - mix))
        )
    }

    private func save(_ context: ModelContext) {
        try? context.save()
    }
}
