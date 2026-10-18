import AVFoundation
import Foundation
import MediaPlayer
import MoonlightCore
import Observation
import UIKit

@MainActor
@Observable
final class PlaybackController {
    private(set) var current: Track?
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var sleepPlan: SleepPlan?
    private(set) var errorKey: String?
    var shuffle = false
    var loop: LoopMode = .all

    var queueIDs: () -> [String] = { [] }
    var trackForID: (String) -> Track? = { _ in nil }
    var localFile: (Track) -> URL? = { _ in nil }
    var onTrackStarted: (String) -> Void = { _ in }
    var onSleepChanged: (SleepPlan?) -> Void = { _ in }

    private let player = AVPlayer()
    private let bridge = Bridge()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var artwork: UIImage?
    private var resumeAfterInterruption = false

    init() {
        bridge.owner = self
        configureSession()
        configureCommands()
        observeTime()
        observeEnd()
        observeInterruptions()
    }

    func prime(_ track: Track) {
        guard track.isReadyToPlay else { return }
        current = track
        duration = track.duration
        currentTime = 0
        isPlaying = false
    }

    func play(_ track: Track) {
        errorKey = nil
        guard track.isReadyToPlay else {
            errorKey = "error.placeholder"
            return
        }
        guard let url = resolvedURL(for: track) else {
            errorKey = "error.playback"
            return
        }
        activateSession()
        let item = AVPlayerItem(url: url)
        observeStatus(of: item)
        player.replaceCurrentItem(with: item)
        player.volume = Float(sleepPlan?.volume(at: Date()) ?? 1)
        player.play()
        current = track
        isPlaying = true
        currentTime = 0
        duration = track.duration
        onTrackStarted(track.id)
        updateNowPlaying()
    }

    func togglePlay() {
        if player.currentItem == nil, let current {
            play(current)
            return
        }
        guard current != nil else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            if let sleepPlan, sleepPlan.isFinished(at: Date()) {
                clearSleep()
            }
            activateSession()
            player.play()
            isPlaying = true
        }
        updateNowPlaying()
    }

    func skipForward() {
        let ids = queueIDs()
        let advanceLoop: LoopMode = loop == .one ? .all : loop
        guard
            let id = PlaybackOrder.nextID(
                after: current?.id,
                in: ids,
                shuffle: shuffle,
                loop: advanceLoop,
                randomIndex: randomIndex
            ),
            let track = trackForID(id)
        else {
            player.pause()
            isPlaying = false
            updateNowPlaying()
            return
        }
        play(track)
    }

    func skipBackward() {
        if currentTime > 3 {
            commitScrub(0)
            return
        }
        let ids = queueIDs()
        let wrap: LoopMode = loop == .off ? .off : .all
        guard
            let id = PlaybackOrder.previousID(before: current?.id, in: ids, loop: wrap),
            let track = trackForID(id)
        else {
            commitScrub(0)
            return
        }
        play(track)
    }

    func previewScrub(_ time: TimeInterval) {
        currentTime = max(0, time)
    }

    func commitScrub(_ time: TimeInterval) {
        let clamped = max(0, time)
        currentTime = clamped
        let cmTime = CMTime(seconds: clamped, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        updateNowPlaying()
    }

    func cycleLoop() {
        loop = loop.next
    }

    func startSleep(minutes: Int, fadeMinutes: Int) {
        let plan = SleepPlan.make(
            now: Date(),
            duration: TimeInterval(minutes * 60),
            fade: TimeInterval(fadeMinutes * 60)
        )
        sleepPlan = plan
        player.volume = Float(plan.volume(at: Date()))
        onSleepChanged(plan)
    }

    func cancelSleep() {
        clearSleep()
        player.volume = 1
    }

    func restoreSleep(_ plan: SleepPlan) {
        sleepPlan = plan
        player.volume = Float(plan.volume(at: Date()))
    }

    func reconcileSleep(now: Date = Date()) {
        applySleep(now: now)
    }

    private func clearSleep() {
        sleepPlan = nil
        onSleepChanged(nil)
    }

    private func resolvedURL(for track: Track) -> URL? {
        if let local = localFile(track) {
            return local
        }
        if let bundled = track.bundledFile, let bundledURL = BundleLocator.audioURL(named: bundled) {
            return bundledURL
        }
        if let remote = track.fileURL {
            return URL(string: remote)
        }
        return nil
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
    }

    private func activateSession() {
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func configureCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true
        center.changePlaybackPositionCommand.isEnabled = true

        center.playCommand.addTarget { [bridge] _ in
            Task { @MainActor in bridge.owner?.resumeFromRemote() }
            return .success
        }
        center.pauseCommand.addTarget { [bridge] _ in
            Task { @MainActor in bridge.owner?.pauseFromRemote() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [bridge] _ in
            Task { @MainActor in bridge.owner?.togglePlay() }
            return .success
        }
        center.nextTrackCommand.addTarget { [bridge] _ in
            Task { @MainActor in bridge.owner?.skipForward() }
            return .success
        }
        center.previousTrackCommand.addTarget { [bridge] _ in
            Task { @MainActor in bridge.owner?.skipBackward() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [bridge] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let time = event.positionTime
            Task { @MainActor in bridge.owner?.commitScrub(time) }
            return .success
        }
    }

    private func resumeFromRemote() {
        guard current != nil else { return }
        if player.currentItem == nil, let current {
            play(current)
            return
        }
        activateSession()
        player.play()
        isPlaying = true
        updateNowPlaying()
    }

    private func pauseFromRemote() {
        player.pause()
        isPlaying = false
        updateNowPlaying()
    }

    private func observeTime() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [bridge] time in
            let seconds = time.seconds
            Task { @MainActor in
                bridge.owner?.handleTick(seconds: seconds)
            }
        }
    }

    private func observeEnd() {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [bridge] notification in
            let ended = notification.object as? AVPlayerItem
            Task { @MainActor in
                guard let owner = bridge.owner, ended === owner.player.currentItem else { return }
                owner.handleEnded()
            }
        }
    }

    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [bridge] notification in
            let info = notification.userInfo ?? [:]
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor in
                bridge.owner?.handleInterruption(typeValue: typeValue, optionsValue: optionsValue)
            }
        }
    }

    private func handleInterruption(typeValue: UInt?, optionsValue: UInt?) {
        guard
            let typeValue,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }
        switch type {
        case .began:
            resumeAfterInterruption = isPlaying
            isPlaying = false
            updateNowPlaying()
        case .ended:
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue ?? 0)
            if resumeAfterInterruption, options.contains(.shouldResume) {
                player.play()
                isPlaying = true
                updateNowPlaying()
            }
            resumeAfterInterruption = false
        @unknown default:
            break
        }
    }

    private func observeStatus(of item: AVPlayerItem) {
        statusObservation = item.observe(\.status, options: [.new]) { [bridge] item, _ in
            guard item.status == .failed else { return }
            Task { @MainActor in
                bridge.owner?.errorKey = "error.playback"
                bridge.owner?.isPlaying = false
            }
        }
    }

    private func handleTick(seconds: Double) {
        if seconds.isFinite, seconds >= 0 {
            currentTime = seconds
        }
        if let item = player.currentItem {
            let itemDuration = item.duration.seconds
            if itemDuration.isFinite, itemDuration > 0 {
                duration = itemDuration
            }
        }
        applySleep(now: Date())
    }

    private func handleEnded() {
        let ids = queueIDs()
        guard
            let next = PlaybackOrder.nextID(
                after: current?.id,
                in: ids,
                shuffle: shuffle,
                loop: loop,
                randomIndex: randomIndex
            )
        else {
            isPlaying = false
            updateNowPlaying()
            return
        }
        if next == current?.id, loop == .one {
            player.seek(to: .zero)
            player.play()
            isPlaying = true
            currentTime = 0
            updateNowPlaying()
            return
        }
        guard let track = trackForID(next) else { return }
        play(track)
    }

    private func applySleep(now: Date) {
        guard let plan = sleepPlan else { return }
        if plan.isFinished(at: now) {
            player.volume = 0
            player.pause()
            isPlaying = false
            clearSleep()
            updateNowPlaying()
            return
        }
        player.volume = Float(plan.volume(at: now))
    }

    private func updateNowPlaying() {
        guard let current else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: current.title,
            MPMediaItemPropertyArtist: "Moonlight Lofi",
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        let image = artwork ?? Self.makeArtwork()
        artwork = image
        info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func randomIndex(upper: Int) -> Int {
        guard upper > 0 else { return 0 }
        return Int.random(in: 0..<upper)
    }

    private static func makeArtwork() -> UIImage {
        let size = CGSize(width: 600, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor(red: 0.05, green: 0.06, blue: 0.14, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.79, green: 0.71, blue: 0.98, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 170, y: 150, width: 260, height: 260))
        }
    }

    private final class Bridge: @unchecked Sendable {
        weak var owner: PlaybackController?
    }
}
