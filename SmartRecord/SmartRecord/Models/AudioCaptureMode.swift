nonisolated enum AudioCaptureMode: String, CaseIterable, Codable, Hashable {
    case both
    case microphoneOnly
    case systemOnly
    case none

    var capturesMicrophone: Bool {
        self == .both || self == .microphoneOnly
    }

    var capturesSystemAudio: Bool {
        self == .both || self == .systemOnly
    }

    var capturesAudio: Bool {
        capturesMicrophone || capturesSystemAudio
    }

    var label: String {
        AppStrings.current.audioModeLabel(self)
    }

    var icon: String {
        switch self {
        case .both:
            return "waveform.and.mic"
        case .microphoneOnly:
            return "mic"
        case .systemOnly:
            return "speaker.wave.2"
        case .none:
            return "speaker.slash"
        }
    }
}
