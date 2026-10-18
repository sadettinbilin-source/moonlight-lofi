import Foundation

enum BundleLocator {
    static func catalogData() -> Data? {
        guard let url = Bundle.main.url(forResource: "tracks", withExtension: "json") else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    static func audioURL(named file: String) -> URL? {
        let ns = file as NSString
        let base = ns.deletingPathExtension
        let ext = ns.pathExtension
        let fileExtension = ext.isEmpty ? nil : ext
        return Bundle.main.url(forResource: base, withExtension: fileExtension, subdirectory: "Audio")
            ?? Bundle.main.url(forResource: base, withExtension: fileExtension)
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
