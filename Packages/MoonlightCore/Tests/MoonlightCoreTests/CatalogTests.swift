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
        XCTAssertFalse(catalog.tracks[0].seamless)
        XCTAssertEqual(catalog.tracks[0].artist, "Moonlight Lofi")
        XCTAssertNil(catalog.tracks[0].musicalKey)
        XCTAssertNil(catalog.tracks[0].bpm)
        XCTAssertTrue(catalog.tracks[0].isReadyToPlay)
    }

    func testDecodesKeyTempoAndSeamlessLoop() throws {
        let json = """
        {"tracks":[{"id":"rainy-window","title":"Rainy Window","artist":"Moonlight Lofi","mood":"mood.rainGlass","key":"D","bpm":80,"duration":150,"bundledFile":"rainy-window.m4a","seamless":true}]}
        """.data(using: .utf8)!
        let track = try CatalogDecoder.decode(json).tracks[0]
        XCTAssertEqual(track.musicalKey, "D")
        XCTAssertEqual(track.bpm, 80)
        XCTAssertTrue(track.seamless)
        XCTAssertEqual(track.artist, "Moonlight Lofi")
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
        let expected: [(String, String, String, Int, Bool)] = [
            ("rainy-window", "Rainy Window", "D", 80, false),
            ("midnight-tea", "Midnight Tea", "F", 76, false),
            ("streetlight-drift", "Streetlight Drift", "A", 84, true),
            ("slow-moon-rising", "Slow Moon Rising", "Eb", 72, true),
            ("rooftop-breeze", "Rooftop Breeze", "G", 82, true),
            ("notebook-margins", "Notebook Margins", "C", 78, false),
            ("last-train-home", "Last Train Home", "Bb", 86, true),
            ("sleepy-cat-nap", "Sleepy Cat Nap", "E", 74, false),
            ("fogged-glass", "Fogged Glass", "Ab", 80, true),
            ("neon-puddles", "Neon Puddles", "B", 83, true),
            ("lantern-glow", "Lantern Glow", "Db", 75, true)
        ]
        XCTAssertEqual(catalog.tracks.map(\.id), expected.map(\.0))
        let free = Set(catalog.tracks.filter { !$0.isPro }.map(\.id))
        XCTAssertEqual(free, ["rainy-window", "midnight-tea", "notebook-margins", "sleepy-cat-nap"])
        for (track, row) in zip(catalog.tracks, expected) {
            XCTAssertEqual(track.title, row.1)
            XCTAssertEqual(track.artist, "Moonlight Lofi")
            XCTAssertEqual(track.musicalKey, row.2)
            XCTAssertEqual(track.bpm, row.3)
            XCTAssertEqual(track.isPro, row.4)
            XCTAssertEqual(track.duration, 150, accuracy: 0.001)
            XCTAssertTrue(track.seamless)
            XCTAssertFalse(track.placeholder)
            XCTAssertTrue(track.isReadyToPlay)
            XCTAssertEqual(track.bundledFile, "\(track.id).m4a")
            let file = root.appendingPathComponent("MoonlightLofi/Resources/Audio/\(track.id).m4a")
            XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), track.id)
        }
        let audio = root.appendingPathComponent("MoonlightLofi/Resources/Audio")
        let names = try FileManager.default.contentsOfDirectory(at: audio, includingPropertiesForKeys: nil)
            .map(\.lastPathComponent)
            .filter { !$0.hasPrefix(".") }
        XCTAssertEqual(Set(names), Set(expected.map { "\($0.0).m4a" }))
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
