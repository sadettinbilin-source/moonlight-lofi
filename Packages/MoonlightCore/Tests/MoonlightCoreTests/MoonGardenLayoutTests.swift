import XCTest
@testable import MoonlightCore

final class MoonGardenLayoutTests: XCTestCase {
    func testIPhone16MoonSitsInTheRightSideOfTheMeasuredGap() {
        let gap = MoonGap(x: 24, y: 330, width: 345, height: 190)
        let disc = MoonGardenLayout.disc(canvasWidth: 393, canvasHeight: 852, gap: gap)

        assertGlow(disc, inside: gap, canvasWidth: 393, canvasHeight: 852)
        XCTAssertGreaterThan(disc.centerX, gap.x + gap.width * 0.7)
        XCTAssertEqual(disc.centerY, gap.y + gap.height / 2, accuracy: 20)
        XCTAssertGreaterThan(disc.centerY - disc.glow, 300)
        XCTAssertLessThan(disc.centerY + disc.glow, 520)
    }

    func testShortPhoneUsesTheMeasuredGapInsteadOfTheScaledBand() {
        // iPhone SE: the title sits higher than a proportional 330–520 band, so only the
        // measured opening between the picker and the title is safe.
        let gap = MoonGap(x: 24, y: 216, width: 327, height: 96)
        let disc = MoonGardenLayout.disc(canvasWidth: 375, canvasHeight: 667, gap: gap)
        let scaled = MoonGardenLayout.fallbackBand(canvasWidth: 375, canvasHeight: 667)

        assertGlow(disc, inside: gap, canvasWidth: 375, canvasHeight: 667)
        XCTAssertLessThan(disc.centerY + disc.glow, scaled.y + scaled.height * 0.5)
        XCTAssertGreaterThan(disc.centerX, gap.x + gap.width * 0.7)
    }

    func testUnmeasuredGapScalesTheIPhone16Band() {
        let sizes: [(Double, Double)] = [(393, 852), (402, 874), (430, 932), (375, 667)]
        for (width, height) in sizes {
            let band = MoonGardenLayout.fallbackBand(canvasWidth: width, canvasHeight: height)
            let disc = MoonGardenLayout.disc(canvasWidth: width, canvasHeight: height, gap: .zero)

            XCTAssertEqual(band.y, height * 330 / 852, accuracy: 0.01)
            XCTAssertEqual(band.maxY, height * 520 / 852, accuracy: 0.01)
            XCTAssertEqual(band.x, width * 0.50, accuracy: 0.01)
            assertGlow(disc, inside: band, canvasWidth: width, canvasHeight: height)
            XCTAssertGreaterThan(disc.centerX, width * 0.7)
        }
    }

    func testTinyGapStillContainsTheGlow() {
        let gap = MoonGap(x: 20, y: 400, width: 340, height: 20)
        let disc = MoonGardenLayout.disc(canvasWidth: 393, canvasHeight: 852, gap: gap)

        assertGlow(disc, inside: gap, canvasWidth: 393, canvasHeight: 852)
        XCTAssertGreaterThan(disc.radius, 0)
    }

    func testThumbnailMoonStaysInsideTheChip() {
        let disc = MoonGardenLayout.disc(canvasWidth: 72, canvasHeight: 92, gap: .zero)
        XCTAssertEqual(disc.centerX, 72 * 0.62, accuracy: 0.01)
        XCTAssertEqual(disc.centerY, 92 * 0.28, accuracy: 0.01)
        XCTAssertEqual(disc.radius, 72 * 0.16, accuracy: 0.01)
    }

    private func assertGlow(
        _ disc: MoonDisc,
        inside band: MoonGap,
        canvasWidth: Double,
        canvasHeight: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertGreaterThanOrEqual(disc.centerX - disc.glow, band.x - 0.01, file: file, line: line)
        XCTAssertLessThanOrEqual(disc.centerX + disc.glow, band.maxX + 0.01, file: file, line: line)
        XCTAssertGreaterThanOrEqual(disc.centerY - disc.glow, band.y - 0.01, file: file, line: line)
        XCTAssertLessThanOrEqual(disc.centerY + disc.glow, band.maxY + 0.01, file: file, line: line)
        XCTAssertGreaterThanOrEqual(disc.centerX - disc.glow, 0, file: file, line: line)
        XCTAssertLessThanOrEqual(disc.centerX + disc.glow, canvasWidth, file: file, line: line)
        XCTAssertGreaterThanOrEqual(disc.centerY - disc.glow, 0, file: file, line: line)
        XCTAssertLessThanOrEqual(disc.centerY + disc.glow, canvasHeight, file: file, line: line)
        XCTAssertLessThan(disc.radius, disc.glow, file: file, line: line)
    }
}
