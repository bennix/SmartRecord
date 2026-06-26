import Testing
@testable import SmartRecord

struct SmartFocusSolverTests {
    @Test func noEventsStayFullScreen() {
        let solver = SmartFocusSolver(events: [], duration: 5, zoomScale: 1.6)

        #expect(solver.sample(at: 1).zoom == 1)
        #expect(solver.sample(at: 1).nx == 0.5)
        #expect(solver.sample(at: 1).ny == 0.5)
    }

    @Test func clickCreatesZoomedFocusWindow() {
        let solver = SmartFocusSolver(
            events: [SmartFocusEvent(time: 2, nx: 0.25, ny: 0.75)],
            duration: 6,
            zoomScale: 1.6
        )

        let sample = solver.sample(at: 2.2)

        #expect(sample.zoom > 1.4)
        #expect(sample.nx == 0.25)
        #expect(sample.ny == 0.75)
    }

    @Test func zoomReturnsToFullScreenAfterInactivity() {
        let solver = SmartFocusSolver(
            events: [SmartFocusEvent(time: 1, nx: 0.25, ny: 0.75)],
            duration: 5,
            zoomScale: 1.6
        )

        #expect(solver.sample(at: 3).zoom == 1)
    }

    @Test func zoomScaleIsClamped() {
        let solver = SmartFocusSolver(
            events: [SmartFocusEvent(time: 1, nx: 0.25, ny: 0.75)],
            duration: 5,
            zoomScale: 9
        )

        #expect(solver.sample(at: 1.2).zoom <= 2.4)
    }

    @Test func closeClicksDoNotMoveFocusBeforeSecondClick() {
        let solver = SmartFocusSolver(
            events: [
                SmartFocusEvent(time: 1.0, nx: 0.2, ny: 0.3),
                SmartFocusEvent(time: 1.8, nx: 0.8, ny: 0.7)
            ],
            duration: 5,
            zoomScale: 1.8
        )

        #expect(solver.sample(at: 1.4).nx == 0.2)
        #expect(solver.sample(at: 1.4).ny == 0.3)
        #expect(solver.sample(at: 1.9).nx == 0.8)
        #expect(solver.sample(at: 1.9).ny == 0.7)
    }
}
