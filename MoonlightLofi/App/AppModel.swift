import Foundation
import MoonlightCore
import Observation
import SwiftData

@MainActor
@Observable
final class AppModel {
    let catalog: Catalog
    let catalogErrorKey: String?
    let playback: PlaybackController
    let focus: FocusTimerController
    let store: StoreManager
    let downloads: DownloadManager

    var selectedScene: AmbientScene {
        didSet { defaults.set(selectedScene.rawValue, forKey: Prefs.scene) }
    }
    var showPaywall = false
    var showSleep = false
    var showDark = false
    private(set) var sleepSceneDismissed = false
    var alertKey: String?
    var restoreNote = false
    var notificationOn: Bool?
    private(set) var totalFocusMinutes = 0
    private(set) var streak = 0
    private(set) var week: [DayTotal] = []

    private var modelContext: ModelContext?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let loaded = Self.loadCatalog()
        catalog = loaded.catalog
        catalogErrorKey = loaded.errorKey
        downloads = DownloadManager()
        playback = PlaybackController()
        focus = FocusTimerController()
        store = StoreManager()

        let storedScene = defaults.string(forKey: Prefs.scene) ?? AmbientScene.defaultScene.rawValue
        selectedScene = AmbientScene(rawValue: storedScene) ?? .defaultScene

        if defaults.object(forKey: Prefs.shuffle) != nil {
            playback.shuffle = defaults.bool(forKey: Prefs.shuffle)
        }
        if let raw = defaults.string(forKey: Prefs.loop), let mode = LoopMode(rawValue: raw) {
            playback.loop = mode
        } else {
            playback.loop = .all
        }
        if let data = defaults.data(forKey: Prefs.sleep),
           let plan = SleepPlan.decoded(data),
           !plan.isFinished(at: Date()) {
            playback.restoreSleep(plan)
        }

        playback.queueIDs = { [weak self] in self?.playableIDs ?? [] }
        playback.trackForID = { [weak self] id in
            self?.catalog.tracks.first { $0.id == id }
        }
        playback.localFile = { [weak self] track in
            self?.downloads.fileURL(for: track.id)
        }
        playback.onTrackStarted = { [weak self] id in
            self?.defaults.set(id, forKey: Prefs.lastTrack)
        }
        playback.onSleepChanged = { [weak self] plan in
            guard let self else { return }
            if let plan, let data = plan.encoded() {
                self.defaults.set(data, forKey: Prefs.sleep)
            } else {
                self.defaults.removeObject(forKey: Prefs.sleep)
                self.sleepSceneDismissed = false
            }
        }
        focus.statsProvider = { [weak self] in
            guard let self, self.store.isPro else { return (0, 0) }
            return (self.streak, self.totalFocusMinutes)
        }
        focus.onCompleted = { [weak self] interval in
            self?.record(interval)
        }

        if let id = defaults.string(forKey: Prefs.lastTrack),
           let track = catalog.tracks.first(where: { $0.id == id && $0.isReadyToPlay && !$0.isPro }) {
            playback.prime(track)
        } else if let track = catalog.tracks.first(where: { $0.isReadyToPlay && !$0.isPro }) {
            playback.prime(track)
        }
    }

    var isPro: Bool { store.isPro }

    /// Scene actually on screen. A saved Pro scene stays put while the Apple ID
    /// is not Pro, and comes back after a purchase without being overwritten.
    var activeScene: AmbientScene {
        if EntitlementPolicy.canUseScene(sceneIsPro: selectedScene.isPro, userIsPro: store.isPro) {
            return selectedScene
        }
        return .defaultScene
    }

    var offersSleepScene: Bool {
        SleepSceneOffer.shouldOffer(
            sleepTimerActive: playback.sleepPlan != nil,
            selected: selectedScene,
            dismissed: sleepSceneDismissed
        )
    }

    func acceptSleepScene() {
        select(scene: SleepSceneOffer.scene)
    }

    func dismissSleepScene() {
        sleepSceneDismissed = true
    }

    func attach(context: ModelContext) {
        guard modelContext == nil else { return }
        modelContext = context
        for interval in focus.takePending() {
            record(interval)
        }
        refreshStats()
        focus.persist()
    }

    func select(scene: AmbientScene) {
        guard EntitlementPolicy.canUseScene(sceneIsPro: scene.isPro, userIsPro: store.isPro) else {
            showPaywall = true
            return
        }
        selectedScene = scene
    }

    func play(_ track: Track) {
        guard EntitlementPolicy.canPlay(trackIsPro: track.isPro, userIsPro: store.isPro) else {
            showPaywall = true
            return
        }
        guard track.isReadyToPlay else {
            alertKey = "error.placeholder"
            return
        }
        playback.play(track)
    }

    func toggleShuffle() {
        playback.shuffle.toggle()
        defaults.set(playback.shuffle, forKey: Prefs.shuffle)
    }

    func cycleLoop() {
        playback.cycleLoop()
        defaults.set(playback.loop.rawValue, forKey: Prefs.loop)
    }

    func downloadCurrent() async {
        guard let track = playback.current else { return }
        await download(track)
    }

    func download(_ track: Track) async {
        guard EntitlementPolicy.canDownload(userIsPro: store.isPro) else {
            showPaywall = true
            return
        }
        guard track.isReadyToPlay else {
            alertKey = "error.placeholder"
            return
        }
        if downloads.downloadedIDs.contains(track.id) {
            return
        }
        await downloads.download(track)
        if downloads.errorKey != nil {
            alertKey = downloads.errorKey
        }
    }

    func refreshNotifications() async {
        let status = await focus.notificationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral:
            notificationOn = true
        case .denied:
            notificationOn = false
        case .notDetermined:
            notificationOn = nil
        @unknown default:
            notificationOn = nil
        }
    }

    func enableNotifications() async {
        notificationOn = await focus.requestNotifications()
    }

    func restorePurchases() async {
        await store.restore()
        restoreNote = store.errorKey == nil
        focus.persist()
    }

    private var playableIDs: [String] {
        catalog.tracks.filter { track in
            track.isReadyToPlay && EntitlementPolicy.canPlay(trackIsPro: track.isPro, userIsPro: store.isPro)
        }.map(\.id)
    }

    private func record(_ interval: CompletedInterval) {
        let minutes = FocusStats.minutesCounted(
            phase: interval.phase,
            elapsed: interval.elapsed,
            finishedNaturally: interval.finishedNaturally
        )
        guard minutes > 0 else { return }
        guard let modelContext else {
            focus.enqueue(interval)
            return
        }
        modelContext.insert(
            FocusSessionRecord(
                startedAt: interval.startedAt,
                endedAt: interval.endedAt,
                focusMinutes: minutes
            )
        )
        try? modelContext.save()
        refreshStats()
    }

    private func refreshStats() {
        guard let modelContext else { return }
        let records = (try? modelContext.fetch(FetchDescriptor<FocusSessionRecord>())) ?? []
        let useful = records.filter { $0.focusMinutes > 0 }
        totalFocusMinutes = FocusStats.totalMinutes(useful.map(\.focusMinutes))
        streak = FocusStats.currentStreak(sessionDays: useful.map(\.endedAt), today: Date())
        week = FocusStats.minutesByDay(
            records: useful.map { (date: $0.endedAt, minutes: $0.focusMinutes) },
            endingOn: Date()
        )
    }

    private static func loadCatalog() -> (catalog: Catalog, errorKey: String?) {
        guard let data = BundleLocator.catalogData() else {
            return (Catalog(tracks: []), "error.catalog")
        }
        do {
            return (try CatalogDecoder.decode(data), nil)
        } catch {
            return (Catalog(tracks: []), "error.catalog")
        }
    }
}
