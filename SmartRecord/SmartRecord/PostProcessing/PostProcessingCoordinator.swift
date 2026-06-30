import Foundation
import SwiftData

@MainActor
@Observable
final class PostProcessingCoordinator {
    private let assetStore: ProjectAssetStore
    private let videoExporter: VideoExporter
    private let editedVideoExporter: EditedVideoExporter

    init(
        assetStore: ProjectAssetStore = ProjectAssetStore(),
        videoExporter: VideoExporter = VideoExporter(),
        editedVideoExporter: EditedVideoExporter = EditedVideoExporter()
    ) {
        self.assetStore = assetStore
        self.videoExporter = videoExporter
        self.editedVideoExporter = editedVideoExporter
    }

    func process(project: Project, context: ModelContext) async {
        await renderFinalVideo(project: project, context: context)
    }

    func renderFinalVideo(project: Project, context: ModelContext) async {
        do {
            try await export(project: project, context: context, destination: nil, updatesStatus: true)
        } catch {
            project.status = .videoFailed
            save(context)
        }
    }

    func exportCopy(project: Project, context: ModelContext, destination: URL) async throws {
        try await export(project: project, context: context, destination: destination, updatesStatus: false)
    }

    private func export(project: Project, context: ModelContext, destination: URL?, updatesStatus: Bool) async throws {
        guard let bundle = try? assetStore.bundle(named: project.assetDirectoryName) else {
            if updatesStatus {
                project.status = .videoFailed
                save(context)
            }
            throw VideoExporterError.missingScreenVideo
        }

        if updatesStatus {
            project.status = .renderingVideo
            save(context)
        }

        do {
            if let timeline = project.editTimeline {
                try await editedVideoExporter.export(
                    bundle: bundle,
                    timeline: timeline,
                    clickEvents: smartFocusEvents(for: project),
                    audioMode: project.audioCaptureMode,
                    options: renderOptions(for: project),
                    outputURL: destination
                )
            } else {
                try await videoExporter.export(
                    bundle: bundle,
                    clickEvents: smartFocusEvents(for: project),
                    audioMode: project.audioCaptureMode,
                    options: renderOptions(for: project)
                )
                if let destination {
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.copyItem(at: bundle.finalVideo, to: destination)
                }
            }
            if updatesStatus {
                project.status = .completed
                save(context)
            }
        } catch {
            if updatesStatus {
                project.status = .videoFailed
                save(context)
            }
            throw error
        }
    }

    private func renderOptions(for project: Project) -> VideoRenderOptions {
        let includeSmartFocus = project.editTimeline?.exportSettings?.includeSmartFocus ?? true
        guard let settings = project.settings else {
            return VideoRenderOptions(
                zoomEnabled: includeSmartFocus,
                zoomScale: 1.6,
                microphoneGain: 0.70,
                systemGain: 0.45,
                frameRate: project.frameRate
            )
        }
        let mix = min(max(settings.micSystemMix, 0), 1)
        return VideoRenderOptions(
            zoomEnabled: settings.zoomEnabled && includeSmartFocus,
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
