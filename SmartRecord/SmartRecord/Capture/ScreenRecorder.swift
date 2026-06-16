//
//  ScreenRecorder.swift
//  SmartRecord
//
//  Captures the main display + system audio + microphone via ScreenCaptureKit
//  and writes them to a .mov file (one video track + two audio tracks) using
//  AVAssetWriter. Raw capture only — no zoom/cursor effects, no audio mixdown.
//

import ScreenCaptureKit
import AVFoundation

@MainActor
final class ScreenRecorder: NSObject, SCStreamOutput {
    private var stream: SCStream?
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var systemAudioInput: AVAssetWriterInput?
    private var micAudioInput: AVAssetWriterInput?
    private var sessionStarted = false
    private(set) var outputURL: URL?
    private(set) var pixelSize: CGSize = .zero
    private(set) var pointSize: CGSize = .zero

    func start() async throws -> URL {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw NSError(domain: "SmartRecord", code: 1, userInfo: [NSLocalizedDescriptionKey: "找不到主显示器"])
        }
        let myWindows = content.windows.filter {
            $0.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
        }
        let filter = SCContentFilter(display: display, excludingWindows: myWindows)

        let config = SCStreamConfiguration()
        config.width = display.width * 2
        config.height = display.height * 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.capturesAudio = true
        config.captureMicrophone = true
        let size = CGSize(width: config.width, height: config.height)
        pixelSize = size
        pointSize = CGSize(width: display.width, height: display.height)

        let url = Self.makeOutputURL()
        outputURL = url
        try setupWriter(url: url, size: size)

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global())
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global())
        try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: .global())
        self.stream = stream
        try await stream.startCapture()
        return url
    }

    func stop() async throws {
        try await stream?.stopCapture()
        videoInput?.markAsFinished()
        systemAudioInput?.markAsFinished()
        micAudioInput?.markAsFinished()
        await writer?.finishWriting()
        if let writer, writer.status == .failed {
            throw writer.error ?? NSError(domain: "SmartRecord", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "录制文件写入失败"])
        }
    }

    private func setupWriter(url: URL, size: CGSize) throws {
        let w = try AVAssetWriter(outputURL: url, fileType: .mov)
        let vSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height
        ]
        let vIn = AVAssetWriterInput(mediaType: .video, outputSettings: vSettings)
        vIn.expectsMediaDataInRealTime = true
        w.add(vIn)

        let aSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44_100
        ]
        let sysIn = AVAssetWriterInput(mediaType: .audio, outputSettings: aSettings)
        sysIn.expectsMediaDataInRealTime = true
        w.add(sysIn)
        let micIn = AVAssetWriterInput(mediaType: .audio, outputSettings: aSettings)
        micIn.expectsMediaDataInRealTime = true
        w.add(micIn)

        self.writer = w
        self.videoInput = vIn
        self.systemAudioInput = sysIn
        self.micAudioInput = micIn
        guard w.startWriting() else {
            throw w.error ?? NSError(domain: "SmartRecord", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "无法开始写入录制文件"])
        }
    }

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of type: SCStreamOutputType) {
        guard CMSampleBufferDataIsReady(sb) else { return }
        Task { @MainActor in self.append(sb, type: type) }
    }

    private func append(_ sb: CMSampleBuffer, type: SCStreamOutputType) {
        guard let writer, writer.status == .writing else { return }
        if !sessionStarted {
            writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sb))
            sessionStarted = true
        }
        let input: AVAssetWriterInput?
        switch type {
        case .screen: input = videoInput
        case .audio: input = systemAudioInput
        case .microphone: input = micAudioInput
        @unknown default: input = nil
        }
        if let input, input.isReadyForMoreMediaData {
            input.append(sb)
        }
    }

    private static func makeOutputURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SmartRecord/Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(UUID().uuidString).mov")
    }
}
