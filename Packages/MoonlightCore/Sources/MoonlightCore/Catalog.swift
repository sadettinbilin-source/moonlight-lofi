import Foundation

public struct Track: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var artist: String
    public var mood: String
    /// Spelling stored in the catalog, such as `Eb` or `Bb`.
    public var musicalKey: String?
    public var bpm: Int?
    public var duration: TimeInterval
    public var bundledFile: String?
    public var fileURL: String?
    public var isPro: Bool
    public var placeholder: Bool
    /// The file's end joins its start. Loop one repeats it with `AVPlayerLooper`.
    public var seamless: Bool

    public init(
        id: String,
        title: String,
        mood: String,
        duration: TimeInterval,
        artist: String = "Moonlight Lofi",
        musicalKey: String? = nil,
        bpm: Int? = nil,
        bundledFile: String? = nil,
        fileURL: String? = nil,
        isPro: Bool = false,
        placeholder: Bool = false,
        seamless: Bool = false
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.mood = mood
        self.musicalKey = musicalKey
        self.bpm = bpm
        self.duration = duration
        self.bundledFile = bundledFile
        self.fileURL = fileURL
        self.isPro = isPro
        self.placeholder = placeholder
        self.seamless = seamless
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, artist, mood, bpm, duration, bundledFile, fileURL, isPro, placeholder, seamless
        case musicalKey = "key"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        artist = try container.decodeIfPresent(String.self, forKey: .artist) ?? "Moonlight Lofi"
        mood = try container.decode(String.self, forKey: .mood)
        musicalKey = try container.decodeIfPresent(String.self, forKey: .musicalKey)
        bpm = try container.decodeIfPresent(Int.self, forKey: .bpm)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        bundledFile = try container.decodeIfPresent(String.self, forKey: .bundledFile)
        fileURL = try container.decodeIfPresent(String.self, forKey: .fileURL)
        isPro = try container.decodeIfPresent(Bool.self, forKey: .isPro) ?? false
        placeholder = try container.decodeIfPresent(Bool.self, forKey: .placeholder) ?? false
        seamless = try container.decodeIfPresent(Bool.self, forKey: .seamless) ?? false
    }

    public var hasBundledAudio: Bool {
        guard let bundledFile, !bundledFile.isEmpty else { return false }
        return true
    }

    /// Placeholder rows document the file-URL schema and are not playable
    /// until a real master replaces them.
    public var isReadyToPlay: Bool {
        if placeholder { return false }
        if hasBundledAudio { return true }
        if let fileURL, !fileURL.isEmpty { return true }
        return false
    }
}

public struct Catalog: Codable, Equatable, Sendable {
    public var tracks: [Track]

    public init(tracks: [Track]) {
        self.tracks = tracks
    }
}

public enum CatalogError: Error, Equatable {
    case invalidJSON
    case empty
    case invalidTrack(String)
}

public enum CatalogDecoder {
    public static func decode(_ data: Data) throws -> Catalog {
        let catalog: Catalog
        do {
            catalog = try JSONDecoder().decode(Catalog.self, from: data)
        } catch {
            throw CatalogError.invalidJSON
        }
        if catalog.tracks.isEmpty {
            throw CatalogError.empty
        }
        var seen = Set<String>()
        for track in catalog.tracks {
            try validate(track, seen: &seen)
        }
        return catalog
    }

    private static func validate(_ track: Track, seen: inout Set<String>) throws {
        let id = track.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = track.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        let idIsSafe = !id.isEmpty && id.unicodeScalars.allSatisfy { allowed.contains($0) }
        if !idIsSafe || title.isEmpty || track.duration <= 0 || seen.contains(id) {
            throw CatalogError.invalidTrack(track.id)
        }
        if let bpm = track.bpm, bpm <= 0 {
            throw CatalogError.invalidTrack(track.id)
        }
        if let musicalKey = track.musicalKey?.trimmingCharacters(in: .whitespacesAndNewlines), musicalKey.isEmpty {
            throw CatalogError.invalidTrack(track.id)
        }
        seen.insert(id)

        let bundled = track.bundledFile?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let remote = track.fileURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if bundled.isEmpty && remote.isEmpty {
            throw CatalogError.invalidTrack(track.id)
        }
        if !remote.isEmpty {
            guard let url = URL(string: remote), url.scheme == "https" else {
                throw CatalogError.invalidTrack(track.id)
            }
        }
    }
}
