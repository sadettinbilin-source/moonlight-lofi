import Foundation
import XCTest
@testable import MoonlightCore

final class LocalizationParityTests: XCTestCase {
    func testGermanStringsCoverEnglishKeys() throws {
        let root = RepoPaths.root.appendingPathComponent("Shared/Resources")
        let english = try String(contentsOf: root.appendingPathComponent("en.lproj/Localizable.strings"), encoding: .utf8)
        let german = try String(contentsOf: root.appendingPathComponent("de.lproj/Localizable.strings"), encoding: .utf8)
        let englishKeys = stringKeys(in: english)
        let germanKeys = stringKeys(in: german)
        XCTAssertFalse(englishKeys.isEmpty)
        XCTAssertEqual(englishKeys.subtracting(germanKeys), [])
        XCTAssertEqual(germanKeys.subtracting(englishKeys), [])

        let englishDict = try String(contentsOf: root.appendingPathComponent("en.lproj/Localizable.stringsdict"), encoding: .utf8)
        let germanDict = try String(contentsOf: root.appendingPathComponent("de.lproj/Localizable.stringsdict"), encoding: .utf8)
        XCTAssertTrue(englishDict.contains("<key>streak.days</key>"))
        XCTAssertTrue(germanDict.contains("<key>streak.days</key>"))

        for scene in AmbientScene.allCases {
            XCTAssertTrue(englishKeys.contains(scene.titleKey), scene.titleKey)
            XCTAssertTrue(germanKeys.contains(scene.titleKey), scene.titleKey)
        }
    }

    private func stringKeys(in text: String) -> Set<String> {
        var cleaned = text
        while let start = cleaned.range(of: "/*"),
              let end = cleaned.range(of: "*/", range: start.upperBound..<cleaned.endIndex) {
            cleaned.removeSubrange(start.lowerBound..<end.upperBound)
        }
        let pattern = #"(?m)^\"([^\"]+)\"\s*="#
        let regex = try! NSRegularExpression(pattern: pattern)
        let ns = cleaned as NSString
        let range = NSRange(location: 0, length: ns.length)
        var keys = Set<String>()
        for match in regex.matches(in: cleaned, range: range) {
            keys.insert(ns.substring(with: match.range(at: 1)))
        }
        return keys
    }
}
