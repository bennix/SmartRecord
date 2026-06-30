import Foundation
import Speech

enum LocalSpeechCaptionerError: LocalizedError, Equatable {
    case noAudio
    case speechPermissionDenied
    case onDeviceRecognitionUnavailable(String)
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .noAudio:
            return "No recorded audio is available for local caption generation."
        case .speechPermissionDenied:
            return "Speech recognition permission is required to generate local captions."
        case .onDeviceRecognitionUnavailable(let language):
            return "On-device speech recognition is unavailable for \(language)."
        case .recognitionFailed(let detail):
            return detail
        }
    }
}

nonisolated struct CaptionLanguage: Hashable, Identifiable {
    var id: String { identifier }
    let identifier: String
    let displayName: String

    static let defaults = [
        CaptionLanguage(identifier: Locale.current.identifier, displayName: Locale.current.localizedString(forIdentifier: Locale.current.identifier) ?? Locale.current.identifier),
        CaptionLanguage(identifier: "en-US", displayName: "English"),
        CaptionLanguage(identifier: "zh-CN", displayName: "简体中文"),
        CaptionLanguage(identifier: "ja-JP", displayName: "日本語"),
        CaptionLanguage(identifier: "fr-FR", displayName: "Français"),
        CaptionLanguage(identifier: "de-DE", displayName: "Deutsch")
    ]
}

nonisolated struct LocalSpeechCaptioner {
    typealias RecognizerFactory = @Sendable (Locale) -> SFSpeechRecognizer?

    private let recognizerFactory: RecognizerFactory

    init(recognizerFactory: @escaping RecognizerFactory = { SFSpeechRecognizer(locale: $0) }) {
        self.recognizerFactory = recognizerFactory
    }

    static func audioSource(bundle: ProjectAssetBundle, audioMode: AudioCaptureMode) -> URL? {
        switch audioMode {
        case .both:
            if FileManager.default.fileExists(atPath: bundle.microphoneAudio.path) { return bundle.microphoneAudio }
            if FileManager.default.fileExists(atPath: bundle.systemAudio.path) { return bundle.systemAudio }
            return nil
        case .microphoneOnly:
            return FileManager.default.fileExists(atPath: bundle.microphoneAudio.path) ? bundle.microphoneAudio : nil
        case .systemOnly:
            return FileManager.default.fileExists(atPath: bundle.systemAudio.path) ? bundle.systemAudio : nil
        case .none:
            return nil
        }
    }

    func transcribe(bundle: ProjectAssetBundle, audioMode: AudioCaptureMode, language: CaptionLanguage) async throws -> [CaptionSegment] {
        guard let audioURL = Self.audioSource(bundle: bundle, audioMode: audioMode) else {
            throw LocalSpeechCaptionerError.noAudio
        }
        guard await Self.requestSpeechAuthorization() else {
            throw LocalSpeechCaptionerError.speechPermissionDenied
        }
        let locale = Locale(identifier: language.identifier)
        guard let recognizer = recognizerFactory(locale), recognizer.supportsOnDeviceRecognition else {
            throw LocalSpeechCaptionerError.onDeviceRecognitionUnavailable(language.identifier)
        }
        return try await transcribe(audioURL: audioURL, recognizer: recognizer, language: language)
    }

    private func transcribe(audioURL: URL, recognizer: SFSpeechRecognizer, language: CaptionLanguage) async throws -> [CaptionSegment] {
        try await withCheckedThrowingContinuation { continuation in
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = false

            var didResume = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !didResume else { return }
                if let error {
                    didResume = true
                    continuation.resume(throwing: LocalSpeechCaptionerError.recognitionFailed(error.localizedDescription))
                    return
                }
                guard let result, result.isFinal else { return }
                didResume = true
                let segments = result.bestTranscription.segments.map {
                    CaptionSegment(
                        startTime: $0.timestamp,
                        endTime: $0.timestamp + max($0.duration, 0.4),
                        text: $0.substring,
                        languageCode: language.identifier,
                        confidence: Double($0.confidence)
                    )
                }
                continuation.resume(returning: segments)
            }
        }
    }

    private static func requestSpeechAuthorization() async -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .authorized {
            return true
        }
        guard status == .notDetermined else {
            return false
        }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { nextStatus in
                continuation.resume(returning: nextStatus == .authorized)
            }
        }
    }
}
