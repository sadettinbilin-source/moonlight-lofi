import Foundation

enum BundleLocator {
    static func catalogData(in bundle: Bundle = .main) -> Data? {
        guard let url = catalogURL(in: bundle) else { return nil }
        return try? Data(contentsOf: url)
    }

    static func catalogURL(in bundle: Bundle = .main) -> URL? {
        let subdirectories: [String?] = [nil, "Catalog", "Resources/Catalog"]
        for subdirectory in subdirectories {
            if let url = bundle.url(forResource: "tracks", withExtension: "json", subdirectory: subdirectory) {
                return url
            }
        }
        return nil
    }

    static func audioURL(named file: String, in bundle: Bundle = .main) -> URL? {
        let ns = file as NSString
        let base = ns.deletingPathExtension
        let ext = ns.pathExtension
        let fileExtension = ext.isEmpty ? nil : ext
        let subdirectories: [String?] = ["Audio", nil, "Resources/Audio"]
        for subdirectory in subdirectories {
            if let url = bundle.url(forResource: base, withExtension: fileExtension, subdirectory: subdirectory) {
                return url
            }
        }
        return nil
    }
}

enum Links {
    static let channel = URL(string: "https://www.youtube.com/@moonlight-lofii")!
    static let terms = URL(string: "https://moonlightlofi.app/terms")!
    static let privacy = URL(string: "https://moonlightlofi.app/privacy")!
    static let subscriptions = URL(string: "https://apps.apple.com/account/subscriptions")!
}

enum Prefs {
    static let scene = "prefs.scene"
    static let shuffle = "prefs.shuffle"
    static let loop = "prefs.loop"
    static let sleep = "prefs.sleep"
    static let lastTrack = "prefs.lastTrack"
}
