import Foundation
import SwiftData

enum ExportDestinationMode: String, Codable, CaseIterable {
    case updateFinalVideo
    case saveCopy
}

@Model
final class ExportSettings {
    var burnCaptions: Bool
    var includeAnnotations: Bool
    var includeSmartFocus: Bool
    var destinationModeRawValue: String

    init(
        burnCaptions: Bool = false,
        includeAnnotations: Bool = true,
        includeSmartFocus: Bool = true,
        destinationMode: ExportDestinationMode = .updateFinalVideo
    ) {
        self.burnCaptions = burnCaptions
        self.includeAnnotations = includeAnnotations
        self.includeSmartFocus = includeSmartFocus
        self.destinationModeRawValue = destinationMode.rawValue
    }

    var destinationMode: ExportDestinationMode {
        get { ExportDestinationMode(rawValue: destinationModeRawValue) ?? .updateFinalVideo }
        set { destinationModeRawValue = newValue.rawValue }
    }
}
