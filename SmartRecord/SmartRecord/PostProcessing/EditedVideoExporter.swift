import AVFoundation
import CoreImage
import Foundation

nonisolated struct EditedVideoExporter {
    func export(
        bundle: ProjectAssetBundle,
        timeline: EditTimeline,
        clickEvents: [SmartFocusEvent],
        audioMode: AudioCaptureMode,
        options: VideoRenderOptions,
        outputURL: URL? = nil
    ) async throws {
        guard FileManager.default.fileExists(atPath: bundle.screenVideo.path) else {
            throw VideoExporterError.missingScreenVideo
        }

        let destination = outputURL ?? bundle.finalVideo
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        let normalizedSegments = TimelineMapper.normalizedSegments(from: timeline.segments)
        guard !normalizedSegments.isEmpty else {
            throw VideoExporterError.noVideoTrack
        }

        let composition = AVMutableComposition()
        let screenAsset = AVURLAsset(url: bundle.screenVideo)
        guard let sourceVideoTrack = try await screenAsset.loadTracks(withMediaType: .video).first else {
            throw VideoExporterError.noVideoTrack
        }

        let preferredTransform = try await sourceVideoTrack.load(.preferredTransform)
        let naturalSize = try await sourceVideoTrack.load(.naturalSize)
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoExporterError.noVideoTrack
        }
        videoTrack.preferredTransform = preferredTransform

        for segment in normalizedSegments {
            let sourceRange = CMTimeRange(
                start: CMTime(seconds: segment.sourceStartTime, preferredTimescale: 600),
                duration: CMTime(seconds: segment.duration, preferredTimescale: 600)
            )
            try videoTrack.insertTimeRange(
                sourceRange,
                of: sourceVideoTrack,
                at: CMTime(seconds: segment.timelineStartTime, preferredTimescale: 600)
            )
        }

        let duration = CMTime(seconds: TimelineMapper(segments: normalizedSegments).duration, preferredTimescale: 600)
        let audioMixParameters = try await addAudioTracks(
            to: composition,
            segments: normalizedSegments,
            bundle: bundle,
            audioMode: audioMode,
            options: options
        )

        let mapper = TimelineMapper(segments: normalizedSegments)
        let focusEvents = focusEvents(for: timeline, fallbackEvents: clickEvents, mapper: mapper)
        let settings = timeline.exportSettings
        let includeAnnotations = settings?.includeAnnotations ?? true
        let burnCaptions = settings?.burnCaptions ?? false
        let zoomEnabled = (settings?.includeSmartFocus ?? true) && options.zoomEnabled
        let zoomScale = focusEvents.first?.zoomScale ?? options.zoomScale
        let annotations = includeAnnotations ? timeline.annotations.map(RenderedAnnotation.init) : []
        let captions = timeline.captions.map(RenderedCaption.init)
        let solver = SmartFocusSolver(events: focusEvents.map(\.event), duration: max(duration.seconds, 0), zoomScale: zoomScale)
        let renderSize = evenSize(naturalSize.applying(preferredTransform))
        let renderer = AnnotationRenderer(assetDirectory: bundle.annotationAssetsDirectory)

        let videoComposition = AVMutableVideoComposition(asset: composition) { request in
            let sample = zoomEnabled
                ? solver.sample(at: request.compositionTime.seconds)
                : SmartFocusSample(nx: 0.5, ny: 0.5, zoom: 1.0)
            let focused = render(sourceImage: request.sourceImage, sample: sample)
            let annotated = renderer.render(
                sourceImage: focused,
                annotations: annotations,
                captions: captions,
                at: request.compositionTime.seconds,
                renderSize: renderSize,
                burnCaptions: burnCaptions
            )
            request.finish(with: annotated, context: nil)
        }
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = options.frameRate.frameDuration

        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = audioMixParameters

        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoExporterError.exportUnavailable
        }

        exporter.shouldOptimizeForNetworkUse = true
        exporter.videoComposition = videoComposition
        if !audioMixParameters.isEmpty {
            exporter.audioMix = audioMix
        }

        do {
            try await exporter.export(to: destination, as: .mp4)
        } catch {
            throw VideoExporterError.exportFailed(Self.errorSummary(error))
        }
    }

    private func addAudioTracks(
        to composition: AVMutableComposition,
        segments: [EditSegment],
        bundle: ProjectAssetBundle,
        audioMode: AudioCaptureMode,
        options: VideoRenderOptions
    ) async throws -> [AVAudioMixInputParameters] {
        var parameters: [AVAudioMixInputParameters] = []

        if audioMode.capturesSystemAudio,
           let systemTrack = try await addAudioTrack(from: bundle.systemAudio, to: composition, segments: segments) {
            let input = AVMutableAudioMixInputParameters(track: systemTrack)
            input.setVolume(options.systemGain, at: .zero)
            parameters.append(input)
        }

        if audioMode.capturesMicrophone,
           let microphoneTrack = try await addAudioTrack(from: bundle.microphoneAudio, to: composition, segments: segments) {
            let input = AVMutableAudioMixInputParameters(track: microphoneTrack)
            input.setVolume(options.microphoneGain, at: .zero)
            parameters.append(input)
        }

        return parameters
    }

    private func addAudioTrack(
        from url: URL,
        to composition: AVMutableComposition,
        segments: [EditSegment]
    ) async throws -> AVMutableCompositionTrack? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let asset = AVURLAsset(url: url)
        guard let sourceTrack = try await asset.loadTracks(withMediaType: .audio).first else { return nil }
        guard let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            return nil
        }
        let assetDuration = try await asset.load(.duration).seconds
        for segment in segments {
            let start = min(segment.sourceStartTime, assetDuration)
            let end = min(segment.sourceEndTime, assetDuration)
            guard end > start else { continue }
            try track.insertTimeRange(
                CMTimeRange(
                    start: CMTime(seconds: start, preferredTimescale: 600),
                    duration: CMTime(seconds: end - start, preferredTimescale: 600)
                ),
                of: sourceTrack,
                at: CMTime(seconds: segment.timelineStartTime, preferredTimescale: 600)
            )
        }
        return track
    }

    private func focusEvents(
        for timeline: EditTimeline,
        fallbackEvents: [SmartFocusEvent],
        mapper: TimelineMapper
    ) -> [(event: SmartFocusEvent, zoomScale: Double)] {
        if !timeline.smartFocusKeyframes.isEmpty {
            return timeline.smartFocusKeyframes
                .sorted { $0.time < $1.time }
                .map { (SmartFocusEvent(time: $0.time, nx: $0.nx, ny: $0.ny), $0.zoomScale) }
        }
        return fallbackEvents.compactMap { event in
            guard let timelineTime = mapper.timelineTime(forSourceTime: event.time) else { return nil }
            return (SmartFocusEvent(time: timelineTime, nx: event.nx, ny: event.ny), 1.6)
        }
    }

    private func evenSize(_ size: CGSize) -> CGSize {
        let width = max(2, abs(Int(size.width)) - abs(Int(size.width)) % 2)
        let height = max(2, abs(Int(size.height)) - abs(Int(size.height)) % 2)
        return CGSize(width: width, height: height)
    }

    private static func errorSummary(_ error: Error?) -> String {
        guard let error else { return AppStrings.current(.unknownError) }
        let nsError = error as NSError
        return "\(nsError.domain) \(nsError.code): \(nsError.localizedDescription)"
    }
}
