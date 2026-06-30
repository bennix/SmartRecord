import Foundation
import SwiftData

enum AnnotationKind: String, Codable, CaseIterable {
    case text
    case arrow
    case highlightRectangle
    case highlightEllipse
    case blur
    case image
}

@Model
final class AnnotationItem {
    var kindRawValue: String
    var startTime: Double
    var endTime: Double
    var normalizedX: Double
    var normalizedY: Double
    var normalizedWidth: Double
    var normalizedHeight: Double
    var text: String
    var assetFilename: String?
    var zIndex: Int
    var colorHex: String
    var opacity: Double
    var blurRadius: Double

    init(
        kind: AnnotationKind,
        startTime: Double,
        endTime: Double,
        normalizedX: Double,
        normalizedY: Double,
        normalizedWidth: Double,
        normalizedHeight: Double,
        text: String = "",
        assetFilename: String? = nil,
        zIndex: Int = 0,
        colorHex: String = "#0B65C2",
        opacity: Double = 1,
        blurRadius: Double = 12
    ) {
        let clampedStartTime = max(0, startTime)
        self.kindRawValue = kind.rawValue
        self.startTime = clampedStartTime
        self.endTime = max(clampedStartTime, endTime)
        self.normalizedX = min(max(normalizedX, 0), 1)
        self.normalizedY = min(max(normalizedY, 0), 1)
        self.normalizedWidth = min(max(normalizedWidth, 0), 1)
        self.normalizedHeight = min(max(normalizedHeight, 0), 1)
        self.text = text
        self.assetFilename = assetFilename
        self.zIndex = zIndex
        self.colorHex = colorHex
        self.opacity = min(max(opacity, 0), 1)
        self.blurRadius = max(0, blurRadius)
    }

    var kind: AnnotationKind {
        get { AnnotationKind(rawValue: kindRawValue) ?? .text }
        set { kindRawValue = newValue.rawValue }
    }

    var duration: Double {
        max(0, endTime - startTime)
    }
}
