//
//  ScreenRecorder.swift
//  SmartRecord
//
//  Captures screen, system audio, and microphone audio into separate raw assets
//  inside a project bundle.
//

import AppKit
import AVFoundation
import CoreGraphics
import ScreenCaptureKit

enum ScreenRecorderError: LocalizedError {
    case screenCapturePermissionDenied
    case noDisplayAvailable
    case noFramesCaptured
    case writerFailed(String)

    var errorDescription: String? {
        switch self {
        case .screenCapturePermissionDenied:
            return AppStrings.current(.screenPermissionDenied)
        case .noDisplayAvailable:
            return AppStrings.current(.noRecordableDisplay)
        case .noFramesCaptured:
            return AppStrings.current(.recordingTooShort)
        case .writerFailed(let message):
            return AppStrings.current.writerFailed(message)
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .screenCapturePermissionDenied:
            return AppStrings.current(.screenPermissionRecovery)
        case .noDisplayAvailable, .noFramesCaptured, .writerFailed:
            return nil
        }
    }
}

struct ScreenRecordingResult {
    let bundle: ProjectAssetBundle
    let pointSize: CGSize
    let pixelSize: CGSize
    let displayFrame: CGRect
    let frameRate: RecordingFrameRate
    let capturedSystemAudio: Bool
    let capturedMicrophoneAudio: Bool
}

nonisolated final class ScreenRecorder: NSObject, SCStreamOutput {
    private let sampleQueue = DispatchQueue(label: "fudan.miniS.SmartRecord.ScreenRecorder.samples", qos: .userInitiated)
    private var stream: SCStream?
    private var screenWriter: AVAssetWriter?
    private var systemAudioWriter: AVAssetWriter?
    private var microphoneWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var systemAudioInput: AVAssetWriterInput?
    private var microphoneInput: AVAssetWriterInput?
    private var screenSessionStarted = false
    private var systemAudioSessionStarted = false
    private var microphoneSessionStarted = false
    private var capturedScreenFrame = false
    private var microphoneCaptureEnabled = false
    private var bundle: ProjectAssetBundle?

    private(set) var pointSize: CGSize = .zero
    private(set) var pixelSize: CGSize = .zero
    private(set) var displayFrame: CGRect = .zero
    private(set) var frameRate: RecordingFrameRate = .default

    func start(
        bundle: ProjectAssetBundle,
        audioMode: AudioCaptureMode = .both,
        frameRate: RecordingFrameRate = .default
    ) async throws {
        if !CGPreflightScreenCaptureAccess() {
            guard CGRequestScreenCaptureAccess() else {
                throw ScreenRecorderError.screenCapturePermissionDenied
            }
        }

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            if Self.isScreenCapturePermissionError(error) {
                throw ScreenRecorderError.screenCapturePermissionDenied
            }
            throw error
        }

        guard let display = content.displays.first else {
            throw ScreenRecorderError.noDisplayAvailable
        }

        let ownWindows = content.windows.filter {
            $0.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
        }
        let filter = SCContentFilter(display: display, excludingWindows: ownWindows)

        let config = SCStreamConfiguration()
        config.width = Self.evenDimension(display.width)
        config.height = Self.evenDimension(display.height)
        config.minimumFrameInterval = frameRate.frameDuration
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.capturesAudio = audioMode.capturesSystemAudio
        microphoneCaptureEnabled = audioMode.capturesMicrophone
            ? await Self.requestMicrophoneAccessIfNeeded()
            : false
        config.captureMicrophone = microphoneCaptureEnabled

        self.bundle = bundle
        self.frameRate = frameRate
        let displayFrame = display.frame.isEmpty ? CGDisplayBounds(display.displayID) : display.frame
        self.displayFrame = displayFrame
        pixelSize = CGSize(width: config.width, height: config.height)
        pointSize = displayFrame.size == .zero
            ? CGSize(width: display.width, height: display.height)
            : displayFrame.size

        try setupWriters(
            bundle: bundle,
            size: pixelSize,
            capturesSystemAudio: audioMode.capturesSystemAudio,
            capturesMicrophone: microphoneCaptureEnabled
        )

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        do {
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
            if audioMode.capturesSystemAudio {
                try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: sampleQueue)
            }
            if microphoneCaptureEnabled {
                do {
                    try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: sampleQueue)
                } catch {
                    microphoneCaptureEnabled = false
                    microphoneWriter?.cancelWriting()
                    microphoneWriter = nil
                    microphoneInput = nil
                    try? FileManager.default.removeItem(at: bundle.microphoneAudio)
                }
            }
            self.stream = stream
            try await stream.startCapture()
        } catch {
            cancelWriters()
            if Self.isScreenCapturePermissionError(error) {
                throw ScreenRecorderError.screenCapturePermissionDenied
            }
            throw error
        }
    }

    func stop() async throws -> ScreenRecordingResult {
        try await stream?.stopCapture()

        guard let bundle else {
            throw ScreenRecorderError.writerFailed(AppStrings.current(.missingAssetDirectory))
        }
        let finishState = sampleQueue.sync {
            let state = FinishState(
                capturedScreenFrame: capturedScreenFrame,
                capturedSystemAudio: systemAudioSessionStarted,
                capturedMicrophoneAudio: microphoneSessionStarted
            )
            videoInput?.markAsFinished()
            systemAudioInput?.markAsFinished()
            microphoneInput?.markAsFinished()
            return state
        }

        guard finishState.capturedScreenFrame else {
            cancelWriters()
            try? FileManager.default.removeItem(at: bundle.directory)
            throw ScreenRecorderError.noFramesCaptured
        }

        try await finish(writer: screenWriter)
        let capturedSystemAudio = await finishOptionalAudio(
            writer: systemAudioWriter,
            sessionStarted: finishState.capturedSystemAudio,
            url: bundle.systemAudio
        )
        let capturedMicrophoneAudio = await finishOptionalAudio(
            writer: microphoneWriter,
            sessionStarted: finishState.capturedMicrophoneAudio,
            url: bundle.microphoneAudio
        )

        return ScreenRecordingResult(
            bundle: bundle,
            pointSize: pointSize,
            pixelSize: pixelSize,
            displayFrame: displayFrame,
            frameRate: frameRate,
            capturedSystemAudio: capturedSystemAudio,
            capturedMicrophoneAudio: capturedMicrophoneAudio
        )
    }

    nonisolated func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        append(sampleBuffer, type: type)
    }

    private func setupWriters(
        bundle: ProjectAssetBundle,
        size: CGSize,
        capturesSystemAudio: Bool,
        capturesMicrophone: Bool
    ) throws {
        let codec: AVVideoCodecType = max(size.width, size.height) > 4096 ? .hevc : .h264
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height
        ]

        let screenWriter = try AVAssetWriter(outputURL: bundle.screenVideo, fileType: .mov)
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true
        screenWriter.add(videoInput)
        guard screenWriter.startWriting() else {
            throw ScreenRecorderError.writerFailed(Self.errorSummary(screenWriter.error))
        }

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44_100,
            AVEncoderBitRateKey: 128_000
        ]

        self.screenWriter = screenWriter
        self.videoInput = videoInput

        if capturesSystemAudio {
            let systemAudioWriter = try AVAssetWriter(outputURL: bundle.systemAudio, fileType: .m4a)
            let systemAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            systemAudioInput.expectsMediaDataInRealTime = true
            systemAudioWriter.add(systemAudioInput)
            guard systemAudioWriter.startWriting() else {
                throw ScreenRecorderError.writerFailed(Self.errorSummary(systemAudioWriter.error))
            }

            self.systemAudioWriter = systemAudioWriter
            self.systemAudioInput = systemAudioInput
        }

        if capturesMicrophone {
            let microphoneWriter = try AVAssetWriter(outputURL: bundle.microphoneAudio, fileType: .m4a)
            let microphoneInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            microphoneInput.expectsMediaDataInRealTime = true
            microphoneWriter.add(microphoneInput)
            guard microphoneWriter.startWriting() else {
                throw ScreenRecorderError.writerFailed(Self.errorSummary(microphoneWriter.error))
            }

            self.microphoneWriter = microphoneWriter
            self.microphoneInput = microphoneInput
        }
    }

    private func append(_ sampleBuffer: CMSampleBuffer, type: SCStreamOutputType) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        switch type {
        case .screen:
            guard Self.isCompleteScreenFrame(sampleBuffer) else { return }
            guard let screenWriter, let videoInput, screenWriter.status == .writing else { return }
            if videoInput.isReadyForMoreMediaData {
                if !screenSessionStarted {
                    screenWriter.startSession(atSourceTime: timestamp)
                    screenSessionStarted = true
                }
                capturedScreenFrame = videoInput.append(sampleBuffer) || capturedScreenFrame
            }
        case .audio:
            guard let systemAudioWriter, let systemAudioInput, systemAudioWriter.status == .writing else { return }
            if !systemAudioSessionStarted {
                systemAudioWriter.startSession(atSourceTime: timestamp)
                systemAudioSessionStarted = true
            }
            if systemAudioInput.isReadyForMoreMediaData {
                _ = systemAudioInput.append(sampleBuffer)
            }
        case .microphone:
            guard let microphoneWriter, let microphoneInput, microphoneWriter.status == .writing else { return }
            if !microphoneSessionStarted {
                microphoneWriter.startSession(atSourceTime: timestamp)
                microphoneSessionStarted = true
            }
            if microphoneInput.isReadyForMoreMediaData {
                _ = microphoneInput.append(sampleBuffer)
            }
        @unknown default:
            return
        }
    }

    private func finish(writer: AVAssetWriter?) async throws {
        guard let writer else { return }
        await writer.finishWriting()
        if writer.status == .failed {
            throw ScreenRecorderError.writerFailed(Self.errorSummary(writer.error))
        }
    }

    private func finishOptionalAudio(writer: AVAssetWriter?, sessionStarted: Bool, url: URL) async -> Bool {
        guard sessionStarted else {
            writer?.cancelWriting()
            try? FileManager.default.removeItem(at: url)
            return false
        }

        do {
            try await finish(writer: writer)
            return true
        } catch {
            writer?.cancelWriting()
            try? FileManager.default.removeItem(at: url)
            return false
        }
    }

    private func cancelWriters() {
        screenWriter?.cancelWriting()
        systemAudioWriter?.cancelWriting()
        microphoneWriter?.cancelWriting()
    }

    private static func evenDimension(_ value: Int) -> Int {
        max(2, value - value % 2)
    }

    private static func isScreenCapturePermissionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == "com.apple.ScreenCaptureKit.SCStreamErrorDomain" && nsError.code == -3801
    }

    private static func isCompleteScreenFrame(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard
            let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
            let statusRawValue = attachments.first?[.status] as? Int,
            let status = SCFrameStatus(rawValue: statusRawValue)
        else {
            return false
        }
        return status == .complete
    }

    private static func requestMicrophoneAccessIfNeeded() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private static func errorSummary(_ error: Error?) -> String {
        guard let error else { return AppStrings.current(.unknownWriterError) }
        let nsError = error as NSError
        var parts = ["\(nsError.domain) \(nsError.code)", nsError.localizedDescription]
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            parts.append("底层错误：\(underlying.domain) \(underlying.code) \(underlying.localizedDescription)")
        }
        return parts.joined(separator: "；")
    }

    private struct FinishState {
        let capturedScreenFrame: Bool
        let capturedSystemAudio: Bool
        let capturedMicrophoneAudio: Bool
    }
}
