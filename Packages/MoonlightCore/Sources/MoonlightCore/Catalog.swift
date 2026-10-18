import Foundation

public struct Track: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var mood: String
    public var duration: TimeInterval
    public var bundledFile: String?
    public var fileURL: String?
    public var isPro: Bool
    public var placeholder: Bool

    public init(
        id: String,
        title: String,
        mood: String,
        duration: TimeInterval,
        bundledFile: String? = nil,
        fileURL: String? = nil,
        isPro: Bool = false,
        placeholder: Bool = false
    ) {
        self.id = id
        self.title = title
        self.mood = mood
        self.duration = duration
        self.bundledFile = bundledFile
        self.fileURL = fileURL
        self.isPro = isPro
        self.placeholder = placeholder
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        mood = try container.decode(String.self, forKey: .mood)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        bundledFile = try container.decodeIfPresent(String.self, forKey: .bundledFile)
        fileURL = try container.decodeIfPresent(String.self, forKey: .fileURL)
        isPro = try container.decodeIfPresent(Bool.self, forKey: .isPro) ?? false
        placeholder = try container.decodeIfPresent(Bool.self, forKey: .placeholder) ?? false
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
