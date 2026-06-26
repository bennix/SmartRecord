import CoreGraphics
import Testing
@testable import SmartRecord

struct MouseEventBufferTests {
    @Test func normalizesPixelToUnitRange() {
        let buf = MouseEventBuffer(screenWidth: 1000, screenHeight: 500)
        buf.record(kind: .leftMouseDown, time: 1.0, px: 500, py: 250)
        #expect(buf.clicks.count == 1)
        #expect(abs(buf.clicks[0].nx - 0.5) < 1e-9)
        #expect(abs(buf.clicks[0].ny - 0.5) < 1e-9)
    }

    @Test func clicksAndMovesGoToSeparateBuckets() {
        let buf = MouseEventBuffer(screenWidth: 1000, screenHeight: 500)
        buf.record(kind: .leftMouseDown, time: 1.0, px: 0, py: 0)
        buf.record(kind: .mouseMoved, time: 1.1, px: 1000, py: 500)
        buf.record(kind: .leftMouseDragged, time: 1.2, px: 500, py: 250)
        #expect(buf.clicks.count == 1)
        #expect(buf.samples.count == 2)        // moved + dragged
        #expect(buf.samples.last!.dragging == true)
    }

    @Test func clampsOutOfBoundsCoordinates() {
        let buf = MouseEventBuffer(screenWidth: 1000, screenHeight: 500)
        buf.record(kind: .mouseMoved, time: 0.5, px: -50, py: 9999)
        #expect(abs(buf.samples[0].nx - 0.0) < 1e-9)
        #expect(abs(buf.samples[0].ny - 1.0) < 1e-9)
    }

    @Test func normalizesAgainstCapturedDisplayFrameOrigin() {
        let buf = MouseEventBuffer(screenFrame: CGRect(x: 100, y: 50, width: 1000, height: 500))
        buf.record(kind: .leftMouseDown, time: 1.0, px: 600, py: 300)

        #expect(abs(buf.clicks[0].nx - 0.5) < 1e-9)
        #expect(abs(buf.clicks[0].ny - 0.5) < 1e-9)
    }
}
