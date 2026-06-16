import Foundation

enum ProjectStatus: String, Codable, CaseIterable {
    case recording
    case recorded
    case renderingVideo
    case transcribing
    case completed
    case videoFailed
    case subtitleFailed
}
