import Foundation

enum ProjectStatus: String, Codable, CaseIterable {
    case recording
    case recorded
    case renderingVideo
    case completed
    case videoFailed
}
