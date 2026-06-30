import Foundation

enum ProjectWarning: String, Codable, CaseIterable, Comparable, Hashable {
    case missingMicrophoneAudio
    case missingSystemAudio

    static func < (lhs: ProjectWarning, rhs: ProjectWarning) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
