import CoreMedia

nonisolated enum RecordingFrameRate: Int, CaseIterable, Codable, Hashable {
    case fps1 = 1
    case fps5 = 5
    case fps10 = 10
    case fps15 = 15
    case fps24 = 24

    static let `default`: RecordingFrameRate = .fps24

    var label: String {
        "\(rawValue) fps"
    }

    var frameDuration: CMTime {
        CMTime(value: 1, timescale: CMTimeScale(rawValue))
    }
}
