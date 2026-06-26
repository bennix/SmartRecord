import AVFoundation
import CoreMedia
import Foundation
import Testing
@testable import SmartRecord

struct VideoExporterTests {
    @Test func exportsSmartFocusH264MP4WithMixedAudioInputs() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartRecordVideoExporterTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ProjectAssetStore(rootDirectory: root)
        let bundle = try store.createProjectBundle()
        try await makeScreenVideo(at: bundle.screenVideo)
        try makeAudioFile(at: bundle.systemAudio, frequency: 440, amplitude: 0.08)
        try makeAudioFile(at: bundle.microphoneAudio, frequency: 880, amplitude: 0.12)

        try await VideoExporter().export(
            bundle: bundle,
            clickEvents: [SmartFocusEvent(time: 0.30, nx: 0.25, ny: 0.65)]
        )

        #expect(FileManager.default.fileExists(atPath: bundle.finalVideo.path))

        let asset = AVURLAsset(url: bundle.finalVideo)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let descriptions = try await #require(tracks.first).load(.formatDescriptions)
        let codec = CMFormatDescriptionGetMediaSubType(try #require(descriptions.first))

        #expect(codec == kCMVideoCodecType_H264)
    }

    @Test func exportRespectsAudioCaptureModeNone() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartRecordVideoExporterTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ProjectAssetStore(rootDirectory: root)
        let bundle = try store.createProjectBundle()
        try await makeScreenVideo(at: bundle.screenVideo)
        try makeAudioFile(at: bundle.systemAudio, frequency: 440, amplitude: 0.08)
        try makeAudioFile(at: bundle.microphoneAudio, frequency: 880, amplitude: 0.12)

        try await VideoExporter().export(
            bundle: bundle,
            clickEvents: [],
            audioMode: .none
        )

        let asset = AVURLAsset(url: bundle.finalVideo)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        #expect(audioTracks.isEmpty)
    }

    @Test func exportUsesOnlySelectedAudioTracks() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartRecordVideoExporterTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ProjectAssetStore(rootDirectory: root)
        let bundle = try store.createProjectBundle()
        try await makeScreenVideo(at: bundle.screenVideo)
        try makeAudioFile(at: bundle.systemAudio, frequency: 440, amplitude: 0.08)
        try makeAudioFile(at: bundle.microphoneAudio, frequency: 880, amplitude: 0.12)

        try await VideoExporter().export(
            bundle: bundle,
            clickEvents: [],
            audioMode: .systemOnly
        )

        let asset = AVURLAsset(url: bundle.finalVideo)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        #expect(audioTracks.count == 1)
    }

    private func makeScreenVideo(at url: URL) async throws {
        let width = 320
        let height = 180
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height
            ]
        )
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )

        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        for frame in 0..<30 {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 2_000_000)
            }
            let pixelBuffer = try makePixelBuffer(width: width, height: height, frame: frame)
            let time = CMTime(value: CMTimeValue(frame), timescale: 30)
            #expect(adaptor.append(pixelBuffer, withPresentationTime: time))
        }

        input.markAsFinished()
        await writer.finishWriting()
        if writer.status != .completed {
            throw writer.error ?? CocoaError(.fileWriteUnknown)
        }
    }

    private func makePixelBuffer(width: Int, height: Int, frame: Int) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw CocoaError(.fileWriteUnknown)
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let base = CVPixelBufferGetBaseAddress(pixelBuffer)!.assumingMemoryBound(to: UInt8.self)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                base[offset] = UInt8((x + frame * 3) % 255)
                base[offset + 1] = UInt8((y + frame * 5) % 255)
                base[offset + 2] = UInt8((80 + frame * 4) % 255)
                base[offset + 3] = 255
            }
        }
        return pixelBuffer
    }

    private func makeAudioFile(at url: URL, frequency: Double, amplitude: Float) throws {
        let sampleRate = 44_100.0
        let frameCount = AVAudioFrameCount(sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let channel = buffer.floatChannelData![0]
        for frame in 0..<Int(frameCount) {
            let phase = 2 * Double.pi * frequency * Double(frame) / sampleRate
            channel[frame] = sin(Float(phase)) * amplitude
        }

        let file = try AVAudioFile(
            forWriting: url,
            settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 64_000
            ]
        )
        try file.write(from: buffer)
    }

}
