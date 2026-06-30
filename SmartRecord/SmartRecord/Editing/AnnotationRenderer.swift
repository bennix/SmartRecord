import AppKit
import CoreImage
import Foundation

nonisolated struct AnnotationRenderer {
    private let assetDirectory: URL?

    init(assetDirectory: URL? = nil) {
        self.assetDirectory = assetDirectory
    }

    func render(
        sourceImage: CIImage,
        annotations: [RenderedAnnotation],
        captions: [RenderedCaption],
        at time: Double,
        renderSize: CGSize,
        burnCaptions: Bool
    ) -> CIImage {
        let visibleAnnotations = annotations
            .filter { $0.startTime <= time && time <= $0.endTime }
            .sorted { $0.zIndex < $1.zIndex }
        let visibleCaptions = burnCaptions
            ? captions.filter { $0.isEnabled && $0.startTime <= time && time <= $0.endTime }
            : []

        guard !visibleAnnotations.isEmpty || !visibleCaptions.isEmpty else {
            return sourceImage
        }

        guard let overlay = makeOverlay(
            annotations: visibleAnnotations,
            captions: visibleCaptions,
            renderSize: renderSize
        ) else {
            return sourceImage
        }

        return overlay.composited(over: sourceImage)
    }

    private func makeOverlay(
        annotations: [RenderedAnnotation],
        captions: [RenderedCaption],
        renderSize: CGSize
    ) -> CIImage? {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(renderSize.width),
            pixelsHigh: Int(renderSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        guard let bitmap else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: renderSize).fill()

        for annotation in annotations {
            draw(annotation, renderSize: renderSize)
        }

        if !captions.isEmpty {
            drawCaptions(captions, renderSize: renderSize)
        }

        NSGraphicsContext.restoreGraphicsState()

        guard let cgImage = bitmap.cgImage else { return nil }
        return CIImage(cgImage: cgImage)
    }

    private func draw(_ annotation: RenderedAnnotation, renderSize: CGSize) {
        let rect = CGRect(
            x: annotation.normalizedX * renderSize.width,
            y: annotation.normalizedY * renderSize.height,
            width: max(1, annotation.normalizedWidth * renderSize.width),
            height: max(1, annotation.normalizedHeight * renderSize.height)
        )
        let color = color(from: annotation.colorHex).withAlphaComponent(annotation.opacity)

        switch annotation.kind {
        case .text:
            drawText(annotation.text.isEmpty ? "Text" : annotation.text, in: rect, color: color, size: 30)
        case .arrow:
            drawArrow(in: rect, color: color)
        case .highlightRectangle:
            drawHighlight(rect, color: color, ellipse: false)
        case .highlightEllipse:
            drawHighlight(rect, color: color, ellipse: true)
        case .blur:
            drawBlurPlaceholder(rect, opacity: annotation.opacity)
        case .image:
            drawImage(annotation.assetFilename, in: rect)
        }
    }

    private func drawText(_ text: String, in rect: CGRect, color: NSColor, size: CGFloat) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: .bold),
            .foregroundColor: color,
            .paragraphStyle: paragraph,
            .strokeColor: NSColor.black.withAlphaComponent(0.35),
            .strokeWidth: -2.0
        ]
        NSString(string: text).draw(in: rect, withAttributes: attributes)
    }

    private func drawArrow(in rect: CGRect, color: NSColor) {
        let path = NSBezierPath()
        path.lineWidth = 8
        path.lineCapStyle = .round
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.line(to: CGPoint(x: rect.maxX, y: rect.maxY))
        color.setStroke()
        path.stroke()

        let head = NSBezierPath()
        head.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
        head.line(to: CGPoint(x: rect.maxX - 26, y: rect.maxY - 6))
        head.line(to: CGPoint(x: rect.maxX - 8, y: rect.maxY - 28))
        head.close()
        color.setFill()
        head.fill()
    }

    private func drawHighlight(_ rect: CGRect, color: NSColor, ellipse: Bool) {
        let path = ellipse ? NSBezierPath(ovalIn: rect) : NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)
        color.withAlphaComponent(0.18).setFill()
        path.fill()
        color.setStroke()
        path.lineWidth = 6
        path.stroke()
    }

    private func drawBlurPlaceholder(_ rect: CGRect, opacity: Double) {
        NSColor.black.withAlphaComponent(min(max(opacity, 0.18), 0.45)).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10).fill()
    }

    private func drawImage(_ filename: String?, in rect: CGRect) {
        guard
            let filename,
            let assetDirectory,
            let image = NSImage(contentsOf: assetDirectory.appendingPathComponent(filename))
        else {
            drawBlurPlaceholder(rect, opacity: 0.22)
            return
        }
        image.draw(in: rect)
    }

    private func drawCaptions(_ captions: [RenderedCaption], renderSize: CGSize) {
        let text = captions.map(\.text).joined(separator: " ")
        guard !text.isEmpty else { return }

        let inset = max(28, renderSize.width * 0.04)
        let height = max(72, renderSize.height * 0.12)
        let rect = CGRect(x: inset, y: inset, width: renderSize.width - inset * 2, height: height)
        NSColor.black.withAlphaComponent(0.58).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12).fill()
        drawText(text, in: rect.insetBy(dx: 18, dy: 16), color: .white, size: 26)
    }

    private func color(from hexString: String) -> NSColor {
        let trimmed = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(trimmed, radix: 16) ?? 0x0B65C2
        return NSColor(
            calibratedRed: CGFloat((value >> 16) & 0xff) / 255,
            green: CGFloat((value >> 8) & 0xff) / 255,
            blue: CGFloat(value & 0xff) / 255,
            alpha: 1
        )
    }
}

nonisolated struct RenderedAnnotation: Sendable {
    let kind: AnnotationKind
    let startTime: Double
    let endTime: Double
    let normalizedX: Double
    let normalizedY: Double
    let normalizedWidth: Double
    let normalizedHeight: Double
    let text: String
    let assetFilename: String?
    let zIndex: Int
    let colorHex: String
    let opacity: Double
    let blurRadius: Double

    init(_ annotation: AnnotationItem) {
        self.kind = annotation.kind
        self.startTime = annotation.startTime
        self.endTime = annotation.endTime
        self.normalizedX = annotation.normalizedX
        self.normalizedY = annotation.normalizedY
        self.normalizedWidth = annotation.normalizedWidth
        self.normalizedHeight = annotation.normalizedHeight
        self.text = annotation.text
        self.assetFilename = annotation.assetFilename
        self.zIndex = annotation.zIndex
        self.colorHex = annotation.colorHex
        self.opacity = annotation.opacity
        self.blurRadius = annotation.blurRadius
    }
}

nonisolated struct RenderedCaption: Sendable {
    let startTime: Double
    let endTime: Double
    let text: String
    let isEnabled: Bool

    init(_ caption: CaptionSegment) {
        self.startTime = caption.startTime
        self.endTime = caption.endTime
        self.text = caption.text
        self.isEnabled = caption.isEnabled
    }
}
