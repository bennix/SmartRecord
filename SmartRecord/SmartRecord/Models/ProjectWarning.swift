import Foundation

enum ProjectWarning: String, Codable, CaseIterable, Comparable, Hashable {
    case missingMicrophoneAudio
    case missingSystemAudio
    case missingSubtitleAudio
    case whisperCommandNotInstalled
    case whisperMediumModelMissing
    case audioConverterNotInstalled

    static func < (lhs: ProjectWarning, rhs: ProjectWarning) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
