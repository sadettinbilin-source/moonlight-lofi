import XCTest
@testable import MoonlightCore

final class CatalogTests: XCTestCase {
    func testDecodesOptionalFlags() throws {
        let json = """
        {"tracks":[{"id":"midnight-kettle","title":"Midnight Kettle","mood":"mood.softKeys","duration":10,"bundledFile":"midnight-kettle.wav"}]}
        """.data(using: .utf8)!
        let catalog = try CatalogDecoder.decode(json)
        XCTAssertEqual(catalog.tracks.count, 1)
        XCTAssertFalse(catalog.tracks[0].isPro)
        XCTAssertFalse(catalog.tracks[0].placeholder)
        XCTAssertTrue(catalog.tracks[0].isReadyToPlay)
    }

    func testRejectsMissingSourceDuplicateIdsAndInsecureURLs() {
        XCTAssertThrowsError(try CatalogDecoder.decode(Data("{}".utf8)))
        XCTAssertNil(try? CatalogDecoder.decode(Data(#"{"tracks":[]}"#.utf8)))

        let missing = Data(#"{"tracks":[{"id":"a","title":"A","mood":"m","duration":10}]}"#.utf8)
        XCTAssertThrowsError(try CatalogDecoder.decode(missing)) { error in
            XCTAssertEqual(error as? CatalogError, .invalidTrack("a"))
        }

        let http = Data(#"{"tracks":[{"id":"a","title":"A","mood":"m","duration":10,"fileURL":"http://example.com/a.mp3"}]}"#.utf8)
        XCTAssertThrowsError(try CatalogDecoder.decode(http))

        let dup = Data(#"{"tracks":[{"id":"a","title":"A","mood":"m","duration":10,"bundledFile":"a.wav"},{"id":"a","title":"B","mood":"m","duration":10,"bundledFile":"b.wav"}]}"#.utf8)
        XCTAssertThrowsError(try CatalogDecoder.decode(dup))

        let unsafe = Data(#"{"tracks":[{"id":"../etc","title":"A","mood":"m","duration":10,"bundledFile":"a.wav"}]}"#.utf8)
        XCTAssertThrowsError(try CatalogDecoder.decode(unsafe))
    }

    func testPlaceholderTracksAreNotPlayable() throws {
        let json = Data(#"{"tracks":[{"id":"harbor-lights","title":"Harbor","mood":"m","duration":180,"fileURL":"https://example.com/a.mp3","isPro":true,"placeholder":true}]}"#.utf8)
        let track = try CatalogDecoder.decode(json).tracks[0]
        XCTAssertFalse(track.isReadyToPlay)
        XCTAssertTrue(track.isPro)
    }

    func testShippedCatalogAndAudioMatch() throws {
        let root = RepoPaths.root
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("project.yml").path))
        let catalogURL = root.appendingPathComponent("MoonlightLofi/Resources/Catalog/tracks.json")
        let data = try Data(contentsOf: catalogURL)
        let catalog = try CatalogDecoder.decode(data)
        XCTAssertGreaterThanOrEqual(catalog.tracks.filter { !$0.isPro && $0.isReadyToPlay }.count, 2)
        XCTAssertGreaterThanOrEqual(catalog.tracks.filter(\.isPro).count, 1)
        for track in catalog.tracks where track.hasBundledAudio {
            let file = root.appendingPathComponent("MoonlightLofi/Resources/Audio/\(track.bundledFile ?? "")")
            XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), track.bundledFile ?? "")
        }
    }

    func testStoreKitConfigUsesTheSameProductIDs() throws {
        let url = RepoPaths.root.appendingPathComponent("MoonlightLofi/Resources/Products.storekit")
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data)
        let ids = productIDs(in: json)
        XCTAssertEqual(ids, Set(ProductIDs.all))
    }

    private func productIDs(in value: Any) -> Set<String> {
        var ids = Set<String>()
        if let dict = value as? [String: Any] {
            if let id = dict["productID"] as? String {
                ids.insert(id)
            }
            for child in dict.values {
                ids.formUnion(productIDs(in: child))
            }
        } else if let array = value as? [Any] {
            for child in array {
                ids.formUnion(productIDs(in: child))
            }
        }
        return ids
    }
}
