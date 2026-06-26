import AVFoundation
import CoreImage
import Foundation

enum VideoExporterError: LocalizedError {
    case missingScreenVideo
    case noVideoTrack
    case exportUnavailable
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingScreenVideo:
            return AppStrings.current(.missingScreenVideo)
        case .noVideoTrack:
            return AppStrings.current(.noVideoTrack)
        case .exportUnavailable:
            return AppStrings.current(.exportUnavailable)
        case .exportFailed(let message):
            return AppStrings.current.exportFailed(message)
        }
    }
}

nonisolated struct VideoRenderOptions {
    let zoomEnabled: Bool
    let zoomScale: Double
    let microphoneGain: Float
    let systemGain: Float
    let frameRate: RecordingFrameRate

    static let defaults = VideoRenderOptions(
        zoomEnabled: true,
        zoomScale: 1.6,
        microphoneGain: 0.70,
        systemGain: 0.45,
        frameRate: .default
    )
}

nonisolated struct VideoExporter {
    func export(
        bundle: ProjectAssetBundle,
        clickEvents: [SmartFocusEvent],
        audioMode: AudioCaptureMode = .both,
        options: VideoRenderOptions = .defaults
    ) async throws {
        guard FileManager.default.fileExists(atPath: bundle.screenVideo.path) else {
            throw VideoExporterError.missingScreenVideo
        }

        try? FileManager.default.removeItem(at: bundle.finalVideo)

        let composition = AVMutableComposition()
        let screenAsset = AVURLAsset(url: bundle.screenVideo)
        guard let sourceVideoTrack = try await screenAsset.loadTracks(withMediaType: .video).first else {
            throw VideoExporterError.noVideoTrack
        }

        let duration = try await screenAsset.load(.duration)
        let preferredTransform = try await sourceVideoTrack.load(.preferredTransform)
        let naturalSize = try await sourceVideoTrack.load(.naturalSize)
        let timeRange = CMTimeRange(start: .zero, duration: duration)
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoExporterError.noVideoTrack
        }
        try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: .zero)
        videoTrack.preferredTransform = preferredTransform

        let audioMixParameters = try await addAudioTracks(
            to: composition,
            duration: duration,
            bundle: bundle,
            audioMode: audioMode,
            options: options
        )

        let renderSize = evenSize(naturalSize.applying(preferredTransform))
        let solver = SmartFocusSolver(
            events: clickEvents,
            duration: max(duration.seconds, 0),
            zoomScale: options.zoomScale
        )
        let videoComposition = AVMutableVideoComposition(asset: composition) { request in
            let sample = options.zoomEnabled
                ? solver.sample(at: request.compositionTime.seconds)
                : SmartFocusSample(nx: 0.5, ny: 0.5, zoom: 1.0)
            let image = render(sourceImage: request.sourceImage, sample: sample)
            request.finish(with: image, context: nil)
        }
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = options.frameRate.frameDuration

        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = audioMixParameters

        guard let exporter = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw VideoExporterError.exportUnavailable
        }

        exporter.shouldOptimizeForNetworkUse = true
        exporter.videoComposition = videoComposition
        if !audioMixParameters.isEmpty {
            exporter.audioMix = audioMix
        }

        do {
            try await exporter.export(to: bundle.finalVideo, as: .mp4)
        } catch {
            throw VideoExporterError.exportFailed(Self.errorSummary(error))
        }
    }

    private func addAudioTracks(
        to composition: AVMutableComposition,
        duration: CMTime,
        bundle: ProjectAssetBundle,
        audioMode: AudioCaptureMode,
        options: VideoRenderOptions
    ) async throws -> [AVAudioMixInputParameters] {
        var parameters: [AVAudioMixInputParameters] = []

        if audioMode.capturesSystemAudio,
           let systemTrack = try await addAudioTrack(from: bundle.systemAudio, to: composition, duration: duration) {
            let input = AVMutableAudioMixInputParameters(track: systemTrack)
            input.setVolume(options.systemGain, at: .zero)
            parameters.append(input)
        }

        if audioMode.capturesMicrophone,
           let microphoneTrack = try await addAudioTrack(from: bundle.microphoneAudio, to: composition, duration: duration) {
            let input = AVMutableAudioMixInputParameters(track: microphoneTrack)
            input.setVolume(options.microphoneGain, at: .zero)
            parameters.append(input)
        }

        return parameters
    }

    private func addAudioTrack(
        from url: URL,
        to composition: AVMutableComposition,
        duration: CMTime
    ) async throws -> AVMutableCompositionTrack? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let asset = AVURLAsset(url: url)
        guard let sourceTrack = try await asset.loadTracks(withMediaType: .audio).first else { return nil }
        guard let track = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            return nil
        }
        let sourceDuration = CMTimeMinimum(try await asset.load(.duration), duration)
        try track.insertTimeRange(CMTimeRange(start: .zero, duration: sourceDuration), of: sourceTrack, at: .zero)
        return track
    }

    private func evenSize(_ size: CGSize) -> CGSize {
        let width = max(2, abs(Int(size.width)) - abs(Int(size.width)) % 2)
        let height = max(2, abs(Int(size.height)) - abs(Int(size.height)) % 2)
        return CGSize(width: width, height: height)
    }

    private static func errorSummary(_ error: Error?) -> String {
        guard let error else { return AppStrings.current(.unknownError) }
        let nsError = error as NSError
        return "\(nsError.domain) \(nsError.code)：\(nsError.localizedDescription)"
    }
}

private func render(sourceImage: CIImage, sample: SmartFocusSample) -> CIImage {
    let extent = sourceImage.extent
    let zoom = max(CGFloat(sample.zoom), 1.0)
    guard zoom > 1.001 else {
        return sourceImage.cropped(to: extent)
    }

    let cropWidth = extent.width / zoom
    let cropHeight = extent.height / zoom
    let centerX = extent.minX + CGFloat(sample.nx) * extent.width
    let centerY = extent.minY + (1 - CGFloat(sample.ny)) * extent.height
    let originX = min(max(centerX - cropWidth / 2, extent.minX), extent.maxX - cropWidth)
    let originY = min(max(centerY - cropHeight / 2, extent.minY), extent.maxY - cropHeight)
    let cropRect = CGRect(x: originX, y: originY, width: cropWidth, height: cropHeight)

    let translated = sourceImage
        .cropped(to: cropRect)
        .transformed(by: CGAffineTransform(translationX: -cropRect.minX, y: -cropRect.minY))
    return translated
        .transformed(by: CGAffineTransform(scaleX: zoom, y: zoom))
        .cropped(to: CGRect(origin: .zero, size: extent.size))
}
