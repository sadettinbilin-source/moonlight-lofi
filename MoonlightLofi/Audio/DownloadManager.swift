import Foundation
import MoonlightCore
import Observation

@MainActor
@Observable
final class DownloadManager {
    private(set) var downloadedIDs: Set<String> = []
    private(set) var inFlight: Set<String> = []
    private(set) var errorKey: String?
    private var locations: [String: URL] = [:]

    private var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("MoonlightTracks", isDirectory: true)
    }

    init() {
        refresh()
    }

    func fileURL(for id: String) -> URL? {
        locations[id]
    }

    func refresh() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        var map: [String: URL] = [:]
        for file in files where !file.hasDirectoryPath {
            map[file.deletingPathExtension().lastPathComponent] = file
        }
        locations = map
        downloadedIDs = Set(map.keys)
    }

    func download(_ track: Track) async {
        guard track.isReadyToPlay else {
            errorKey = "error.placeholder"
            return
        }
        inFlight.insert(track.id)
        errorKey = nil
        defer { inFlight.remove(track.id) }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if let bundled = track.bundledFile, let source = BundleLocator.audioURL(named: bundled) {
                try copy(source, id: track.id)
            } else if let remote = track.fileURL, let url = URL(string: remote) {
                try await fetch(url, id: track.id)
            } else {
                errorKey = "error.download"
                return
            }
            refresh()
        } catch {
            errorKey = "error.download"
        }
    }

    func remove(id: String) {
        if let url = locations[id] {
            try? FileManager.default.removeItem(at: url)
        }
        refresh()
    }

    private func copy(_ source: URL, id: String) throws {
        let ext = source.pathExtension.isEmpty ? "audio" : source.pathExtension
        let destination = directory.appendingPathComponent("\(id).\(ext)")
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
    }

    private func fetch(_ url: URL, id: String) async throws {
        let (temp, response) = try await URLSession.shared.download(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        let destination = directory.appendingPathComponent("\(id).\(fileExtension(url.pathExtension))")
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temp, to: destination)
    }

    private func fileExtension(_ raw: String) -> String {
        let ext = raw.lowercased()
        let allowed = ["mp3", "m4a", "aac", "wav", "aiff", "caf"]
        return allowed.contains(ext) ? ext : "mp3"
    }
}
