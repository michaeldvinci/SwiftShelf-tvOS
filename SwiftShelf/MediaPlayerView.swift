import SwiftUI
import AVFoundation
import AVKit
import MediaPlayer
import Combine
import Foundation

// MARK: - Array Extension for Safe Subscripting
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Custom button style to prevent hover/focus bubble from overlapping neighbors
struct BubbledButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 12
    var fill: Color = .accentColor
    var foreground: Color = .white
    var pressedScale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .frame(minWidth: 44, minHeight: 44, alignment: .center)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .compositingGroup()
            .clipped()
    }
}

// MARK: - NowPlayingBanner (small tweaks: externalized scrub geometry, added optional speed/sleep)
struct NowPlayingBanner: View {
    let scrubberFocus: FocusState<Bool>.Binding?

    let artwork: Image
    let title: String
    let chapterTitle: String?
    let duration: Double
    let currentTime: Double
    let isPlaying: Bool

    let onPlayPause: () -> Void
    let onRewind: () -> Void
    let onForward: () -> Void
    let onSeek: (Double) -> Void

    // optional controls
    var onPrevChapter: (() -> Void)? = nil
    var onNextChapter: (() -> Void)? = nil
    var rate: Float = 1.0
    var onToggleRate: (() -> Void)? = nil
    var sleepLabel: String? = nil
    var onSetSleep: (() -> Void)? = nil

    @FocusState private var localScrubberFocus: Bool

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    VStack(spacing: 2) {
                        Text(title)
                            .font(.headline)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                        if let chapter = chapterTitle, !chapter.isEmpty {
                            Text(chapter)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    HStack(spacing: 8) {
                        Text(formatDuration(currentTime))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                            .frame(minWidth: 72, alignment: .leading)

                        // Timeline scrubber (focusable, left/right moves 10s)
                        Group {
                            GeometryReader { proxy in
                                let trackWidth = max(80, proxy.size.width)
                                let progress = CGFloat(min(max(currentTime / max(duration, 0.0001), 0), 1))
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill((scrubberFocus?.wrappedValue ?? localScrubberFocus) ? Color.accentColor.opacity(0.4) : Color.secondary.opacity(0.25))
                                        .frame(height: 8)
                                    Capsule()
                                        .fill(Color.accentColor)
                                        .frame(width: max(8, progress * trackWidth), height: 8)
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 20, height: 20)
                                        .offset(x: max(0, min(progress * trackWidth - 10, trackWidth - 10)))
                                }
                            }
                        }
                        .frame(height: 24)
                        .padding(.horizontal, 6)
                        .focusable(true)
                        .modifier(FocusBindingModifier(scrubberFocus: scrubberFocus, localScrubberFocus: $localScrubberFocus))
                        .onMoveCommand { move in
                            switch move {
                            case .left:
                                onSeek(max(currentTime - 10, 0))
                            case .right:
                                onSeek(min(currentTime + 10, duration))
                            default: break
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke((scrubberFocus?.wrappedValue ?? localScrubberFocus) ? Color.accentColor : Color.clear, lineWidth: 2)
                        )

                        Text(formatDuration(duration))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                            .frame(minWidth: 72, alignment: .trailing)
                    }
                    .padding(.horizontal, 12)

                    HStack(spacing: 24) {
                        if let onPrevChapter {
                            Button(action: onPrevChapter) {
                                Image(systemName: "backward.end.fill")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            .buttonStyle(.plain)
                            .focusEffectDisabled(true)
                            .accessibilityLabel("Previous chapter")
                        }

                        Button(action: onRewind) {
                            Image(systemName: "gobackward.15")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .focusEffectDisabled(true)
                        .accessibilityLabel("Rewind 15 seconds")

                        Button(action: onPlayPause) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 22, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .focusEffectDisabled(true)
                        .accessibilityLabel(isPlaying ? "Pause" : "Play")

                        Button(action: onForward) {
                            Image(systemName: "goforward.15")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .focusEffectDisabled(true)
                        .accessibilityLabel("Forward 15 seconds")

                        if let onNextChapter {
                            Button(action: onNextChapter) {
                                Image(systemName: "forward.end.fill")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            .buttonStyle(.plain)
                            .focusEffectDisabled(true)
                            .accessibilityLabel("Next chapter")
                        }

                        if let onToggleRate {
                            Button(action: onToggleRate) {
                                Text(String(format: "%.1fx", rate))
                                    .font(.caption)
                                    .monospacedDigit()
                            }
                            .buttonStyle(.plain)
                            .focusEffectDisabled(true)
                            .accessibilityLabel("Playback speed \(rate)x")
                        }

                        if let onSetSleep {
                            Button(action: onSetSleep) {
                                Image(systemName: "moon.zzz")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            .buttonStyle(.plain)
                            .focusEffectDisabled(true)
                            .accessibilityLabel("Set sleep timer")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 10)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: -4)
            .padding(.horizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(minHeight: 320, maxHeight: 500)
    }

    private func formatDuration(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, secs)
                         : String(format: "%d:%02d", minutes, secs)
    }
}

// Helper modifier for conditional focus binding
fileprivate struct FocusBindingModifier: ViewModifier {
    let scrubberFocus: FocusState<Bool>.Binding?
    let localScrubberFocus: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        if let scrubberFocus = scrubberFocus {
            content.focused(scrubberFocus)
        } else {
            content.focused(localScrubberFocus)
        }
    }
}

// MARK: - PlayerViewModel (owns AVPlayer so SwiftUI view can be lightweight)
final class PlayerViewModel: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var rate: Float = 1.0
    @Published var sleepRemaining: TimeInterval? = nil
    @Published var currentTrackIndex: Int = 0
    @Published var currentTrackTitle: String = ""
    @Published var hasAudioStream: Bool = true // New flag to indicate if audio stream is available
    @Published var loadingStatus: String = "Initializing..."
    
    @Published var currentChapterStart: Double = 0
    @Published var currentChapterDuration: Double = 0

    // Logging / observer tokens
    private var statusObservations: [NSKeyValueObservation] = []
    private var perItemNotificationTokens: [NSObjectProtocol] = []
    private var playerItemChangeObservation: NSKeyValueObservation?  // Added for currentItem changes

    let item: LibraryItem
    let appVM: ViewModel

    @Published var player: AVPlayer?
    var timeObserver: Any?
    var endObserver: NSObjectProtocol?
    var sleepTimer: Timer?
    var detailedItem: LibraryItem?
    var playlist: [LibraryItem.Track] = []
    var playlistItems: [AVPlayerItem] = []

    init(item: LibraryItem, appVM: ViewModel) {
        self.item = item
        self.appVM = appVM
    }

    func configureAndPlay() async {
        // This method is kept for backward compatibility but now just prepares without auto-playing
        await configureAndPrepare()
        // Only play if explicitly requested by calling play() separately
    }

    func configureAndPrepare() async {
        AppLogger.shared.log("PlayerVM", "configureAndPrepare for item: \(item.title)")
        print("[PlayerViewModel] 🚀 Starting configureAndPrepare for item: \(item.title)")
        
        await MainActor.run {
            self.setupSession()
            self.loadingStatus = "Fetching item details..."

            // Initialize playback rate from global preference
            let preferred = UserDefaults.standard.object(forKey: "preferredPlaybackRate") as? Double ?? 1.0
            self.rate = Float(preferred)
        }

        // First, try to fetch the detailed item to see what endpoints are actually available
        if let fullItem = await appVM.fetchLibraryItemDetails(itemId: item.id) {
            print("[PlayerViewModel] ✅ Successfully fetched detailed item with \(fullItem.tracks.count) tracks and \(fullItem.audioFiles.count) audio files")

            if !fullItem.tracks.isEmpty {
                print("[PlayerViewModel] 📚 TRACKS FOUND - Using track-based approach")
                await MainActor.run {
                    self.loadingStatus = "Found \(fullItem.tracks.count) tracks, building playlist..."
                }
                self.playlist = fullItem.tracks.sorted { $0.index < $1.index }

                // Build all playlist items
                var playerItems: [AVPlayerItem] = []
                var totalDuration: Double = 0

                for track in playlist {
                    if let url = appVM.streamURL(for: track, in: fullItem) {
                        let asset = AVURLAsset(url: url)
                        let playerItem = AVPlayerItem(asset: asset)
                        setupPlayerItemErrorObserver(playerItem)
                        playerItems.append(playerItem)
                        totalDuration += track.duration ?? 0

                        print("[PlayerViewModel] ➕ Added track to playlist: \(track.title ?? "Track \(track.index)")")
                    }
                }

                if !playerItems.isEmpty {
                    await MainActor.run {
                        self.loadingStatus = "Creating player with \(playerItems.count) items..."
                    }

                    let queuePlayer = AVQueuePlayer(items: playerItems)
                    queuePlayer.automaticallyWaitsToMinimizeStalling = true
                    self.player = queuePlayer
                    self.playlistItems = playerItems

                    // Add KVO for currentItem changes to update UI and re-apply rate
                    self.playerItemChangeObservation = queuePlayer.observe(\AVQueuePlayer.currentItem, options: [.new]) { [weak self] _, _ in
                        guard let self else { return }
                        DispatchQueue.main.async {
                            if let currentItem = queuePlayer.currentItem,
                               let index = self.playlistItems.firstIndex(of: currentItem) {
                                self.currentTrackIndex = index
                                self.currentTrackTitle = self.playlist[safe: index]?.title ?? "Track \(index + 1)"
                                let idx = self.currentTrackIndex
                                let start = self.playlist.prefix(idx).reduce(0.0) { $0 + ($1.duration ?? 0) }
                                let dur = self.playlist[safe: idx]?.duration ?? 0
                                self.currentChapterStart = start
                                self.currentChapterDuration = dur
                            }
                            if self.isPlaying {
                                queuePlayer.rate = self.rate
                            }
                            self.updateNowPlaying()
                        }
                    }

                    await MainActor.run {
                        self.duration = totalDuration
                        self.currentTrackTitle = playlist.first?.title ?? "Track 1"
                        self.currentChapterStart = 0
                        self.currentChapterDuration = self.playlist.first?.duration ?? 0
                        self.hasAudioStream = true
                        self.loadingStatus = "Ready to play!"
                    }

                    setupTimeObserver()
                    setupTrackEndObserver()
                    setupRemoteCommands()
                    updateNowPlaying()
                    
                    print("[PlayerViewModel] ✅ Queue player setup complete")
                    return
                }
            } else if let audioFile = fullItem.audioFiles.first {
                print("[PlayerViewModel] 🎵 No tracks found, using direct file endpoint")
                
                // Handle direct file endpoint
                guard var components = URLComponents(string: appVM.host) else {
                    print("[PlayerViewModel] ❌ Invalid host URL")
                    await MainActor.run { self.hasAudioStream = false }
                    return
                }
                components.path = "/api/items/\(item.id)/file/\(audioFile.ino)"
                let cleanToken = appVM.apiKey.hasPrefix("Bearer ") ? String(appVM.apiKey.dropFirst(7)) : appVM.apiKey
                components.queryItems = [URLQueryItem(name: "token", value: cleanToken)]
                
                if let directURL = components.url {
                    print("[PlayerViewModel] 🎯 Using direct endpoint: \(directURL)")
                    
                    let asset = AVURLAsset(url: directURL)
                    let playerItem = AVPlayerItem(asset: asset)
                    let player = AVPlayer(playerItem: playerItem)
                    player.automaticallyWaitsToMinimizeStalling = true
                    self.player = player
                    setupPlayerItemErrorObserver(playerItem)

                    setupTimeObserver()

                    await MainActor.run {
                        self.duration = audioFile.duration ?? 0
                        self.currentTrackTitle = item.title
                        self.currentChapterStart = 0
                        self.currentChapterDuration = audioFile.duration ?? 0
                        self.hasAudioStream = true
                        self.loadingStatus = "Ready to play!"
                    }
                    
                    setupRemoteCommands()
                    updateNowPlaying()
                    
                    print("[PlayerViewModel] ✅ Direct player setup complete")
                    return
                } else {
                    print("[PlayerViewModel] ❌ Failed to construct direct URL")
                }
            } else {
                print("[PlayerViewModel] ❌ No tracks or audio files found")
            }
        } else {
            print("[PlayerViewModel] ❌ Failed to fetch detailed item")
        }

        // If we reach here, nothing worked
        print("[PlayerViewModel] 💥 Configuration failed - no playable audio found")
        await MainActor.run {
            self.hasAudioStream = false
            self.loadingStatus = "No playable audio found"
        }
    }
    
    func setupTimeObserver() {
        AppLogger.shared.log("PlayerVM", "setupTimeObserver")
        print("[PlayerViewModel] ⏰ Setting up time observer")
        guard let player = player else { 
            print("[PlayerViewModel] ❌ No player available for time observer")
            return 
        }
        
        let interval = CMTime(value: 1, timescale: 2) // 0.5s
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main) { [weak self] (t: CMTime) in
            guard let self else { return }
            self.currentTime = CMTimeGetSeconds(t)
            self.updateNowPlaying(elapsedOnly: true)
            self.persistProgressIfNeeded()
        }
    }


    func teardown() {
        AppLogger.shared.log("PlayerVM", "Teardown called")
        pause()
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        timeObserver = nil
        endObserver = nil
        
        // Remove per-item NotificationCenter tokens
        for token in perItemNotificationTokens { NotificationCenter.default.removeObserver(token) }
        perItemNotificationTokens.removeAll()

        // Invalidate KVO observations
        statusObservations.removeAll()
        playerItemChangeObservation = nil
        
        player = nil
        cancelSleepTimer()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        
        // Properly cleanup remote command targets
        let cmd = MPRemoteCommandCenter.shared()
        cmd.playCommand.removeTarget(nil)
        cmd.pauseCommand.removeTarget(nil)
        cmd.skipBackwardCommand.removeTarget(nil)
        cmd.skipForwardCommand.removeTarget(nil)
    }

    func setupTrackEndObserver() {
        AppLogger.shared.log("PlayerVM", "setupTrackEndObserver")
        // For AVQueuePlayer, observe when current item changes
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            guard let queue = self.player as? AVQueuePlayer else { return }

            // Ensure the queue advances if it didn't automatically
            if queue.items().isEmpty == false {
                queue.advanceToNextItem()
            }

            // Update index/title based on new current item
            if let currentItem = queue.currentItem,
               let index = self.playlistItems.firstIndex(of: currentItem) {
                self.currentTrackIndex = index
                self.currentTrackTitle = self.playlist[safe: index]?.title ?? "Track \(index + 1)"
                let idx = self.currentTrackIndex
                let start = self.playlist.prefix(idx).reduce(0.0) { $0 + ($1.duration ?? 0) }
                let dur = self.playlist[safe: idx]?.duration ?? 0
                self.currentChapterStart = start
                self.currentChapterDuration = dur
            } else {
                // Reached end of queue
                self.isPlaying = false
            }

            // Re-apply rate if we should be playing
            if self.isPlaying {
                queue.rate = self.rate
            }

            self.updateNowPlaying()
        }
    }

    // MARK: Controls
    func play() { player?.play(); player?.rate = rate; isPlaying = true; updateNowPlaying() }
    func pause() { player?.pause(); isPlaying = false; updateNowPlaying() }

    func togglePlayPause() { isPlaying ? pause() : play() }

    func seek(to seconds: Double) {
        let target = CMTime(seconds: max(0, min(seconds, duration)), preferredTimescale: 600)
        player?.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = seconds
        updateNowPlaying(elapsedOnly: true)
    }

    func skip(_ by: Double) { seek(to: max(0, min(currentTime + by, duration))) }
    
    func skip(by seconds: Double) { 
        skip(seconds) 
    }
    
    func nextChapter() {
        // Advance to the next track if using a queue; otherwise, do nothing
        guard let player = player else { return }
        if let queue = player as? AVQueuePlayer {
            // Attempt to advance
            queue.advanceToNextItem()
            if let currentItem = queue.currentItem,
               let index = playlistItems.firstIndex(of: currentItem) {
                currentTrackIndex = index
                currentTrackTitle = playlist[safe: index]?.title ?? "Track \(index + 1)"
                currentTime = 0
                let idx = currentTrackIndex
                let start = playlist.prefix(idx).reduce(0.0) { $0 + ($1.duration ?? 0) }
                let dur = playlist[safe: idx]?.duration ?? 0
                currentChapterStart = start
                currentChapterDuration = dur
                if isPlaying { queue.rate = rate }
                updateNowPlaying()
            } else {
                // No next item — reached end of queue
                isPlaying = false
                updateNowPlaying()
            }
        } else {
            // Single-item player: just seek to end
            seek(to: duration)
            pause()
        }
    }

    func previousChapter() {
        // If far enough into the current track, just restart it; otherwise go to previous
        guard let player = player else { return }
        if let queue = player as? AVQueuePlayer {
            if let currentItem = queue.currentItem,
               let index = playlistItems.firstIndex(of: currentItem) {
                if currentTime > 3 {
                    // Restart current track
                    seek(to: 0)
                    let idx = index
                    let start = playlist.prefix(idx).reduce(0.0) { $0 + ($1.duration ?? 0) }
                    let dur = playlist[safe: idx]?.duration ?? 0
                    currentChapterStart = start
                    currentChapterDuration = dur
                    return
                }
                // Go to previous track if available
                if index > 0 {
                    let newItems = Array(playlistItems[(index - 1)...])
                    let newQueue = AVQueuePlayer(items: newItems)
                    newQueue.automaticallyWaitsToMinimizeStalling = true
                    self.player = newQueue

                    // Reinstall observers for the new player
                    setupTimeObserver()
                    setupTrackEndObserver()
                    setupRemoteCommands()

                    currentTrackIndex = index - 1
                    currentTrackTitle = playlist[safe: currentTrackIndex]?.title ?? "Track \(currentTrackIndex + 1)"
                    currentTime = 0
                    let idx = currentTrackIndex
                    let start = playlist.prefix(idx).reduce(0.0) { $0 + ($1.duration ?? 0) }
                    let dur = playlist[safe: idx]?.duration ?? 0
                    currentChapterStart = start
                    currentChapterDuration = dur
                    if isPlaying { newQueue.play(); newQueue.rate = rate }
                    updateNowPlaying()
                } else {
                    // At the start of the queue — just restart current
                    seek(to: 0)
                    let idx = index
                    let start = playlist.prefix(idx).reduce(0.0) { $0 + ($1.duration ?? 0) }
                    let dur = playlist[safe: idx]?.duration ?? 0
                    currentChapterStart = start
                    currentChapterDuration = dur
                }
            }
        } else {
            // Single-item player: restart
            seek(to: 0)
        }
    }

    func toggleRate() {
        let options: [Float] = [0.8, 1.0, 1.25, 1.5, 1.75, 2.0]
        if let idx = options.firstIndex(of: rate) { rate = options[(idx + 1) % options.count] } else { rate = 1.0 }
        player?.rate = isPlaying ? rate : 0
        UserDefaults.standard.set(Double(rate), forKey: "preferredPlaybackRate")
        updateNowPlaying()
    }

    func setRate(_ newRate: Float) {
        let clamped = max(1.0, min(newRate, 2.5))
        rate = clamped
        if isPlaying {
            player?.rate = clamped
        } else {
            player?.rate = 0
        }
        UserDefaults.standard.set(Double(rate), forKey: "preferredPlaybackRate")
        updateNowPlaying()
    }

    func setSleep(minutes: Int) {
        cancelSleepTimer()
        guard minutes > 0 else { return }
        sleepRemaining = TimeInterval(minutes * 60)
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
            guard let self else { return }
            self.sleepRemaining = max(0, (self.sleepRemaining ?? 0) - 1)
            if self.sleepRemaining == 0 { t.invalidate(); self.pause(); self.sleepRemaining = nil }
        }
    }

    func cancelSleepTimer() { sleepTimer?.invalidate(); sleepTimer = nil; sleepRemaining = nil }

    // MARK: Now Playing / Remote
    func setupSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, options: [.allowAirPlay, .allowBluetoothHFP])
            try session.setActive(true)
        } catch { print("[AudioSession] error: \(error)") }
    }

    func setupRemoteCommands() {
        AppLogger.shared.log("PlayerVM", "setupRemoteCommands")
        let cmd = MPRemoteCommandCenter.shared()
        
        // Remove existing targets first to prevent duplicates
        cmd.playCommand.removeTarget(nil)
        cmd.pauseCommand.removeTarget(nil)
        cmd.skipBackwardCommand.removeTarget(nil)
        cmd.skipForwardCommand.removeTarget(nil)
        
        cmd.playCommand.isEnabled = true
        cmd.playCommand.addTarget { [weak self] _ in self?.play(); return .success }
        cmd.pauseCommand.isEnabled = true
        cmd.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }
        cmd.skipBackwardCommand.isEnabled = true
        cmd.skipBackwardCommand.preferredIntervals = [15]
        cmd.skipBackwardCommand.addTarget { [weak self] _ in self?.skip(-15); return .success }
        cmd.skipForwardCommand.isEnabled = true
        cmd.skipForwardCommand.preferredIntervals = [15]
        cmd.skipForwardCommand.addTarget { [weak self] _ in self?.skip(15); return .success }
    }

    func updateNowPlaying(elapsedOnly: Bool = false) {
        AppLogger.shared.log("PlayerVM", "updateNowPlaying elapsedOnly=\(elapsedOnly) time=\(currentTime) playing=\(isPlaying) rate=\(rate)")
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        if !elapsedOnly {
            info[MPMediaItemPropertyTitle] = item.title
            if let author = item.authorNameLF ?? item.authorName { info[MPMediaItemPropertyArtist] = author }
            info[MPMediaItemPropertyPlaybackDuration] = duration
            info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? rate : 0.0
        }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func setupPlayerItemErrorObserver(_ playerItem: AVPlayerItem) {
        AppLogger.shared.log("PlayerVM", "Adding observers for item: \(String(describing: playerItem))")

        // KVO via NSKeyValueObservation
        let statusObs = playerItem.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard let self else { return }
            switch item.status {
            case .readyToPlay:
                AppLogger.shared.log("PlayerVM", "KVO status readyToPlay for item")
                if let asset = item.asset as? AVURLAsset {
                    AppLogger.shared.log("PlayerVM", "Asset URL: \(asset.url)")
                }
                DispatchQueue.main.async { self.hasAudioStream = true }
            case .failed:
                AppLogger.shared.log("PlayerVM", "KVO status FAILED for item: \(item.error?.localizedDescription ?? "unknown error")")
                if let asset = item.asset as? AVURLAsset {
                    AppLogger.shared.log("PlayerVM", "Failed asset URL: \(asset.url)")
                }
                DispatchQueue.main.async { self.hasAudioStream = false }
            case .unknown:
                AppLogger.shared.log("PlayerVM", "KVO status unknown for item")
            @unknown default:
                AppLogger.shared.log("PlayerVM", "KVO status unknown default: \(item.status.rawValue)")
            }
        }
        statusObservations.append(statusObs)

        // Notifications — store tokens
        let failToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let errDesc = (notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error)?.localizedDescription ?? "nil"
            AppLogger.shared.log("PlayerVM", "AVPlayerItemFailedToPlayToEndTime: \(errDesc)")
            self.hasAudioStream = false
        }
        perItemNotificationTokens.append(failToken)

        let errLogToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemNewErrorLogEntry,
            object: playerItem,
            queue: .main
        ) { notification in
            if let playerItem = notification.object as? AVPlayerItem,
               let errorLog = playerItem.errorLog() {
                AppLogger.shared.log("PlayerVM", "AVPlayerItemNewErrorLogEntry: \(errorLog)")
            }
        }
        perItemNotificationTokens.append(errLogToken)
    }

    private func testURLAccessibility(_ url: URL, trackTitle: String) async {
        print("[PlayerViewModel] Testing URL accessibility for: \(trackTitle)")

        // Log to file for easy debugging
        let logMessage = "Testing URL: \(url.absoluteString) for track: \(trackTitle)"
        await logToFile(logMessage)

        // Test with query parameter (current approach)
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                let statusMessage = "URL test result for \(trackTitle) (query param): Status \(httpResponse.statusCode)"
                print("[PlayerViewModel] \(statusMessage)")
                await logToFile(statusMessage)

                if httpResponse.statusCode == 200 {
                    let successMessage = "✅ URL is accessible with query param"
                    print("[PlayerViewModel] \(successMessage)")
                    await logToFile(successMessage)

                    if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") {
                        let typeMessage = "Content-Type: \(contentType)"
                        print("[PlayerViewModel] \(typeMessage)")
                        await logToFile(typeMessage)
                    }
                    if let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length") {
                        let lengthMessage = "Content-Length: \(contentLength)"
                        print("[PlayerViewModel] \(lengthMessage)")
                        await logToFile(lengthMessage)
                    }
                    return
                } else {
                    let errorMessage = "❌ URL returned status \(httpResponse.statusCode) with query param"
                    print("[PlayerViewModel] \(errorMessage)")
                    await logToFile(errorMessage)
                }
            }
        } catch {
            let errorMessage = "❌ URL test failed for \(trackTitle) with query param: \(error.localizedDescription)"
            print("[PlayerViewModel] \(errorMessage)")
            await logToFile(errorMessage)
        }

        // If query param failed, try with Authorization header
        let urlWithoutToken = url.absoluteString.components(separatedBy: "?").first ?? url.absoluteString
        if let urlWithoutQuery = URL(string: urlWithoutToken) {
            var authRequest = URLRequest(url: urlWithoutQuery)
            authRequest.httpMethod = "HEAD"
            authRequest.timeoutInterval = 5
            authRequest.setValue("Bearer \(appVM.apiKey)", forHTTPHeaderField: "Authorization")

            do {
                let (_, response) = try await URLSession.shared.data(for: authRequest)
                if let httpResponse = response as? HTTPURLResponse {
                    let statusMessage = "URL test result for \(trackTitle) (auth header): Status \(httpResponse.statusCode)"
                    print("[PlayerViewModel] \(statusMessage)")
                    await logToFile(statusMessage)

                    if httpResponse.statusCode == 200 {
                        let successMessage = "✅ URL is accessible with Authorization header"
                        print("[PlayerViewModel] \(successMessage)")
                        await logToFile(successMessage)
                        if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") {
                            let typeMessage = "Content-Type: \(contentType)"
                            print("[PlayerViewModel] \(typeMessage)")
                            await logToFile(typeMessage)
                        }
                    } else {
                        let errorMessage = "❌ URL returned status \(httpResponse.statusCode) with auth header"
                        print("[PlayerViewModel] \(errorMessage)")
                        await logToFile(errorMessage)
                    }
                }
            } catch {
                let errorMessage = "❌ URL test failed for \(trackTitle) with auth header: \(error.localizedDescription)"
                print("[PlayerViewModel] \(errorMessage)")
                await logToFile(errorMessage)
            }
        }
    }


    private var lastPersist: TimeInterval = 0
    private func persistProgressIfNeeded() {
        // throttle to ~5s
        let now = Date().timeIntervalSince1970
        guard now - lastPersist > 5 else { return }
        lastPersist = now
        Task { await appVM.saveProgress(for: item, seconds: currentTime) }
    }

    // Log to file for debugging endpoint tests
    private func logToFile(_ message: String) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let logLine = "[\(timestamp)] \(message)\n"

        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let logFileURL = documentsDirectory.appendingPathComponent("streaming_debug.log")

        if let data = logLine.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logFileURL)
            }
        }
    }

    // Expose player for embedding
    var avPlayer: AVPlayer? {
        return player
    }
}

// MARK: - MediaPlayerView (SwiftUI) - Uses Global Audio Manager
struct MediaPlayerView: View {
    let item: LibraryItem
    @EnvironmentObject var viewModel: ViewModel
    @EnvironmentObject var audioManager: GlobalAudioManager
    @Environment(\.dismiss) private var dismiss

    @FocusState private var focusMiniPlayer: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if !audioManager.hasAudioStream && audioManager.currentItem?.id == item.id {
                // Show error only if this item failed to load
                VStack(spacing: 24) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.red)

                    Text("Audio Stream Not Available")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Unable to load playable audio for this item. Please check your connection and try again.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Button("Close") {
                        print("[MediaPlayerView] 🚪 Close button tapped")
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .background(Color.black.opacity(0.8))
                .cornerRadius(24)
                .shadow(radius: 20)
                .padding(40)
            } else {
                // Popup overlay showing selected item's info. If this item is the active one, show full controls; otherwise offer Play to switch.
                VStack(spacing: 20) {
                    if let img = audioManager.coverArt?.0 {
                        img
                            .resizable()
                            .aspectRatio(1, contentMode: .fit)
                            .frame(maxWidth: 380)
                            .cornerRadius(16)
                            .shadow(radius: 10)
                    } else {
                        Image(systemName: "music.note")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 180, height: 180)
                            .foregroundColor(.gray)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.08)))
                    }

                    VStack(spacing: 4) {
                        Text(item.title)
                            .font(.title.bold())
                            .foregroundColor(.white)
                        if let author = item.authorNameLF ?? item.authorName {
                            Text(author)
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }

                    if audioManager.currentItem?.id == item.id, audioManager.avPlayer != nil {
                        NowPlayingBanner(
                            scrubberFocus: $focusMiniPlayer,
                            artwork: (audioManager.coverArt?.0) ?? Image(systemName: "music.note"),
                            title: item.title,
                            chapterTitle: audioManager.currentTrackTitle,
                            duration: audioManager.duration,
                            currentTime: audioManager.currentTime,
                            isPlaying: audioManager.isPlaying,
                            onPlayPause: { audioManager.togglePlayPause() },
                            onRewind: { audioManager.skip(-15) },
                            onForward: { audioManager.skip(15) },
                            onSeek: { audioManager.seek(to: $0) },
                            onPrevChapter: { audioManager.previousChapter() },
                            onNextChapter: { audioManager.nextChapter() },
                            rate: audioManager.rate,
                            onToggleRate: { audioManager.toggleRate() },
                            sleepLabel: audioManager.sleepRemaining.map { secs in
                                let m = Int(secs) / 60; let s = Int(secs) % 60; return String(format: "%d:%02d", m, s)
                            },
                            onSetSleep: { audioManager.setSleep(minutes: 15) }
                        )
                        .padding(.bottom, 12)
                    } else {
                        VStack(spacing: 12) {
                            Text("This item is not currently active.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            HStack(spacing: 16) {
                                Button("Play") {
                                    Task {
                                        print("[MediaPlayerView] ▶️ Play selected item from overlay: \(item.title)")
                                        await audioManager.loadItem(item, appVM: viewModel)
                                        if let last = await viewModel.loadProgress(for: item) {
                                            print("[MediaPlayerView] ⏭️ Restoring progress to: \(last)s")
                                            audioManager.seek(to: last)
                                        }
                                        audioManager.togglePlayPause()
                                    }
                                }
                                .buttonStyle(.borderedProminent)

                                Button("Close") {
                                    dismiss()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.bottom, 12)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            }
        }
        .task {
            AppLogger.shared.log("PlayerUI", "initialLoad for item: \(item.title)")
            await initialLoad()
        }
        .onAppear {
            print("[MediaPlayerView] 👀 MediaPlayerView appeared for item: \(item.title)")
        }
        .onDisappear {
            print("[MediaPlayerView] 👋 MediaPlayerView disappeared")
        }
        .onMoveCommand { move in
            if move == .down {
                focusMiniPlayer = true
            }
        }
    }

    private func initialLoad() async {
        print("[MediaPlayerView] 🚀 Initial load starting for item: \(item.title)")
        print("[MediaPlayerView] 🔍 Current item in audioManager: \(audioManager.currentItem?.title ?? "None")")
        
        // Only load if there's no current item; don't auto-switch from an existing mini player item
        if audioManager.currentItem == nil {
            print("[MediaPlayerView] 🆕 No current item — loading selected item into audioManager")
            await audioManager.loadItem(item, appVM: viewModel)

            // Restore last position from server
            if let last = await viewModel.loadProgress(for: item) {
                print("[MediaPlayerView] ⏭️ Restoring progress to: \(last)s")
                audioManager.seek(to: last)
            }
        } else if audioManager.currentItem?.id == item.id {
            print("[MediaPlayerView] ✅ Item already loaded in audioManager")
        } else {
            print("[MediaPlayerView] ⏸️ Different item is already in mini player — not auto-switching")
        }
        
        print("[MediaPlayerView] ✅ Initial load complete")
    }
}

// MARK: - Global Player View with Artwork
struct GlobalPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    let artwork: UIImage?
    let item: LibraryItem

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = false
        controller.view.backgroundColor = .black
        
        // Ensure proper view hierarchy setup
        controller.view.translatesAutoresizingMaskIntoConstraints = false

        print("[GlobalPlayerView] Creating player view controller")
        if artwork != nil {
            print("[GlobalPlayerView] ✅ Artwork available: \(artwork!.size)")
        } else {
            print("[GlobalPlayerView] ❌ No artwork")
        }

        // Defer metadata configuration to avoid early view hierarchy issues
        DispatchQueue.main.async {
            self.configureMetadata(for: controller)
        }
        
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Only update if actually different to avoid unnecessary updates
        if uiViewController.player !== player {
            uiViewController.player = player
            
            // Defer metadata configuration to avoid view hierarchy issues
            DispatchQueue.main.async {
                self.configureMetadata(for: uiViewController)
            }
        }
    }

    private func configureMetadata(for controller: AVPlayerViewController) {
        AppLogger.shared.log("PlayerUI", "configureMetadata for item: \(item.title)")
        // Create external metadata for tvOS
        var metadata: [AVMetadataItem] = []

        // Title
        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = .commonIdentifierTitle
        titleItem.value = item.title as NSString
        titleItem.extendedLanguageTag = "und"
        metadata.append(titleItem)

        // Artist/Author
        if let author = item.authorNameLF ?? item.authorName {
            let artistItem = AVMutableMetadataItem()
            artistItem.identifier = .commonIdentifierArtist
            artistItem.value = author as NSString
            artistItem.extendedLanguageTag = "und"
            metadata.append(artistItem)
        }

        // Artwork - try JPEG first, then PNG
        if let artworkImage = artwork {
            let artworkItem = AVMutableMetadataItem()
            artworkItem.identifier = .commonIdentifierArtwork

            if let jpegData = artworkImage.jpegData(compressionQuality: 0.9) {
                artworkItem.value = jpegData as NSData
                artworkItem.dataType = kCMMetadataBaseDataType_JPEG as String
                metadata.append(artworkItem)
            } else if let pngData = artworkImage.pngData() {
                artworkItem.value = pngData as NSData
                artworkItem.dataType = kCMMetadataBaseDataType_PNG as String
                metadata.append(artworkItem)
            }
        }

        // Description
        if let series = item.seriesName {
            let descriptionItem = AVMutableMetadataItem()
            descriptionItem.identifier = .commonIdentifierDescription
            descriptionItem.value = series as NSString
            descriptionItem.extendedLanguageTag = "und"
            metadata.append(descriptionItem)
        }

        // Apply metadata to ALL player items in queue
        if let queuePlayer = player as? AVQueuePlayer {
            for item in queuePlayer.items() {
                item.externalMetadata = metadata
            }
        } else if let currentItem = player.currentItem {
            currentItem.externalMetadata = metadata
        }
    }
}

