import MoonlightCore
import UIKit
import XCTest
@testable import MoonlightLofi

final class BundleResourceTests: XCTestCase {
    func testCatalogAudioStringsAndSceneImagesAreInTheAppBundle() throws {
        let bundle = Bundle.main
        let data = try XCTUnwrap(
            BundleLocator.catalogData(in: bundle),
            "tracks.json is missing from the app bundle"
        )
        XCTAssertTrue(bundle.bundlePath.hasSuffix(".app"))

        let catalog = try CatalogDecoder.decode(data)
        XCTAssertEqual(catalog.tracks.count, 11)

        for track in catalog.tracks {
            let file = try XCTUnwrap(track.bundledFile, "Track \(track.id) has no bundled audio")
            let url = try XCTUnwrap(
                BundleLocator.audioURL(named: file, in: bundle),
                "Audio \(file) is missing from the app bundle"
            )
            XCTAssertTrue(url.path.hasPrefix(bundle.bundlePath), "\(file) resolved outside the app bundle")
            XCTAssertGreaterThan(try Data(contentsOf: url).count, 0, "Audio \(file) is empty")
        }

        let header = bundle.localizedString(forKey: "library.header", value: nil, table: nil)
        XCTAssertNotEqual(header, "library.header")
        XCTAssertTrue(
            header == "Tracks" || header == "Titel",
            "library.header resolved to \(header)"
        )

        let imageNames = AmbientScene.allCases.compactMap(\.imageName)
        XCTAssertEqual(Set(imageNames), Set(["luna_focus", "luna_sleep", "luna_rooftop"]))
        for name in imageNames {
            XCTAssertNotNil(
                UIImage(named: name, in: bundle, compatibleWith: nil),
                "Scene image \(name) did not load"
            )
        }
    }
}
