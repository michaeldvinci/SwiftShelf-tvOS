//
//  GlobalAudioManager.swift
//  SwiftShelf
//
//  Created by michaeldvinci on 10/21/25.
//

import SwiftUI
import AVFoundation
import MediaPlayer
import Combine

@MainActor
final class GlobalAudioManager: NSObject, ObservableObject {
    static let shared = GlobalAudioManager()
    
    @Published var currentItem: LibraryItem?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var rate: Float = 1.0
    @Published var sleepRemaining: TimeInterval?
    @Published var currentTrackIndex: Int = 0
    @Published var currentTrackTitle: String = ""
    @Published var hasAudioStream: Bool = false
    @Published var loadingStatus: String = "Ready"
    @Published var coverArt: (Image, UIImage)?
    
    @Published var currentChapterStart: Double = 0
    @Published var currentChapterDuration: Double = 0
    
    private var playerViewModel: PlayerViewModel?
    private var cancellables = Set<AnyCancellable>()

    // Cached resume position (seconds) to apply on first play after load
    private var pendingResumeSeconds: Double?

    private weak var appViewModel: ViewModel?

    // Session management (canonical ABS flow)
    private var currentSessionId: String?
    private var lastSyncTime: Date?              // When we last sent a sync
    private var lastSyncPosition: Double = 0     // Position at last sync
    private var sessionSyncTimer: Timer?          // Periodic session sync (20s)
    private var progressSyncTimer: Timer?         // Periodic progress PATCH (90s)

    private override init() {
        super.init()
        print("===========================================")
        print("[GlobalAudioManager] 🎬🎬🎬 INITIALIZED v2.0 🎬🎬🎬")
        print("===========================================")
    }
    
    func loadItem(_ item: LibraryItem, appVM: ViewModel) async {
        print("===========================================")
        print("[GlobalAudioManager] 🚀🚀🚀 LOADING ITEM v2.0 🚀🚀🚀")
        print("[GlobalAudioManager] 🚀 Loading item: \(item.title)")
        print("[GlobalAudioManager] 📊 Item ID: \(item.id)")
        print("[GlobalAudioManager] 📊 Duration from item: \(item.duration.map { String($0) } ?? "nil")")
        print("[GlobalAudioManager] 📊 Media present: \(item.media != nil)")
        if let media = item.media {
            print("[GlobalAudioManager] 📊 Media duration: \(media.duration.map { String($0) } ?? "nil")")
        }
        print("===========================================")

        // If duration is missing, fetch full details
        var itemToUse = item
        if item.duration == nil {
            print("[GlobalAudioManager] ⚠️ Duration missing, fetching full item details...")
            if let fullItem = await appVM.fetchLibraryItemDetails(itemId: item.id) {
                print("[GlobalAudioManager] ✅ Full item fetched, duration: \(fullItem.duration.map { String($0) } ?? "nil")")
                itemToUse = fullItem
            } else {
                print("[GlobalAudioManager] ❌ Failed to fetch full item details")
            }
        }

        // Store reference to appViewModel for progress saving
        self.appViewModel = appVM

        // Stop current playback
        await stopCurrentPlayback()

        // Set new current item (use the one with duration if we fetched it)
        currentItem = itemToUse
        loadingStatus = "Loading \(itemToUse.title)..."

        print("[GlobalAudioManager] 🖼️ Loading cover art...")
        // Load cover art
        if let coverTuple = await appVM.loadCover(for: itemToUse) {
            coverArt = coverTuple
            print("[GlobalAudioManager] ✅ Cover art loaded successfully")
        } else {
            print("[GlobalAudioManager] ❌ Failed to load cover art")
        }

        print("[GlobalAudioManager] 🎵 Creating PlayerViewModel...")
        // Create new player view model
        let newPlayerVM = PlayerViewModel(item: itemToUse, appVM: appVM)
        playerViewModel = newPlayerVM

        // Bind to player view model
        print("[GlobalAudioManager] 🔗 Binding to PlayerViewModel...")
        bindToPlayerViewModel(newPlayerVM)

        // Configure and prepare (but don't auto-play)
        print("[GlobalAudioManager] ⚙️ Configuring and preparing player...")
        await newPlayerVM.configureAndPrepare()

        // Pre-fetch last progress but do not seek yet; apply on first play
        if let last = await appVM.loadProgress(for: itemToUse) {
            let resume = max(0, last - 5)
            print("[GlobalAudioManager] ⏪ Cached resume position: \(resume)s (from server: \(last)s)")
            self.pendingResumeSeconds = resume
        } else {
            self.pendingResumeSeconds = nil
        }

        print("[GlobalAudioManager] ✅ Item loading complete")
    }
    
    func play() {
        print("===========================================")
        print("[GlobalAudioManager] ▶️▶️▶️ PLAY (Canonical ABS Flow) ▶️▶️▶️")
        print("[GlobalAudioManager] currentItem: \(currentItem?.title ?? "nil")")
        print("[GlobalAudioManager] currentItem.id: \(currentItem?.id ?? "nil")")
        print("[GlobalAudioManager] currentItem.duration: \(currentItem?.duration.map { String($0) } ?? "nil")")
        print("===========================================")

        // Apply cached resume position if this is the first play
        if let resume = pendingResumeSeconds, resume > 0 {
            print("[GlobalAudioManager] ⤴️ Applying cached resume before play: \(resume)s")
            playerViewModel?.seek(to: resume)
            pendingResumeSeconds = nil
        }

        playerViewModel?.play()

        // Start periodic timers for session sync (20s) and progress PATCH (90s)
        startPeriodicTimers()

        // Start playback session if not already started
        if currentSessionId == nil {
            startPlaybackSession()
        }
    }

    func pause() {
        print("[GlobalAudioManager] ⏸️ Pause requested")

        playerViewModel?.pause()

        // Stop periodic timers
        stopPeriodicTimers()

        // Save progress immediately when pausing (canonical flow)
        saveProgressAndSyncSession()
    }
    
    func togglePlayPause() {
        print("[GlobalAudioManager] ⏯️ Toggle play/pause requested")

        // Check current state before toggle
        let wasPlaying = isPlaying

        playerViewModel?.togglePlayPause()

        // Wait a moment for the state to update, then handle timers
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }

            if self.isPlaying && !wasPlaying {
                // Transitioned from paused to playing
                print("[GlobalAudioManager] ▶️ Resumed from pause - restarting timers")
                self.startPeriodicTimers()

                // Start session if needed
                if self.currentSessionId == nil {
                    self.startPlaybackSession()
                }
            } else if !self.isPlaying && wasPlaying {
                // Transitioned from playing to paused
                print("[GlobalAudioManager] ⏸️ Paused - stopping timers and saving")
                self.stopPeriodicTimers()
                self.saveProgressAndSyncSession()
            }
        }
    }
    
    func seek(to seconds: Double) {
        print("[GlobalAudioManager] ⏩ Seek to \(seconds)s requested")
        playerViewModel?.seek(to: seconds)

        // Per canonical ABS flow: send immediate sync with timeListened=0 on seek
        Task { @MainActor in
            await syncSessionAfterSeek()
        }
    }
    
    func skip(_ by: Double) {
        print("[GlobalAudioManager] ⏭️ Skip by \(by)s requested")
        playerViewModel?.skip(by)
    }
    
    func previousChapter() {
        print("[GlobalAudioManager] ⏮️ Previous chapter requested")
        playerViewModel?.previousChapter()
    }
    
    func nextChapter() {
        print("[GlobalAudioManager] ⏭️ Next chapter requested")
        playerViewModel?.nextChapter()
    }
    
    func toggleRate() {
        print("[GlobalAudioManager] 🏃‍♂️ Toggle rate requested")
        playerViewModel?.toggleRate()
    }
    
    func setRate(_ newRate: Float) {
        print("[GlobalAudioManager] 🏃‍♂️ Set rate: \(newRate)")
        playerViewModel?.setRate(newRate)
        self.rate = playerViewModel?.rate ?? newRate
    }
    
    func setSleep(minutes: Int) {
        print("[GlobalAudioManager] 😴 Set sleep timer: \(minutes) minutes")
        playerViewModel?.setSleep(minutes: minutes)
    }
    
    func cancelSleepTimer() {
        print("[GlobalAudioManager] ⏰ Cancel sleep timer")
        playerViewModel?.cancelSleepTimer()
    }
    
    var avPlayer: AVPlayer? {
        return playerViewModel?.avPlayer
    }
    
    private func stopCurrentPlayback() async {
        print("[GlobalAudioManager] ⏹️ Stopping current playback")

        // Stop periodic timers
        stopPeriodicTimers()

        // Save final progress and close session
        saveProgressAndSyncSession()
        await closeCurrentSession()

        playerViewModel?.teardown()
        playerViewModel = nil
        cancellables.removeAll()

        // Reset state
        isPlaying = false
        currentTime = 0
        duration = 0
        rate = 1.0
        sleepRemaining = nil
        currentTrackIndex = 0
        currentTrackTitle = ""
        hasAudioStream = false
        pendingResumeSeconds = nil
        currentChapterStart = 0
        currentChapterDuration = 0
        print("[GlobalAudioManager] 🔄 State reset complete")
    }
    
    private func bindToPlayerViewModel(_ playerVM: PlayerViewModel) {
        print("[GlobalAudioManager] 📡 Setting up bindings...")
        cancellables.removeAll()
        
        // Use sink instead of assign for cross-object bindings
        playerVM.$isPlaying
            .sink { [weak self] value in
                self?.isPlaying = value
            }
            .store(in: &cancellables)
        
        playerVM.$currentTime
            .sink { [weak self] value in
                self?.currentTime = value
            }
            .store(in: &cancellables)
        
        playerVM.$duration
            .sink { [weak self] value in
                self?.duration = value
            }
            .store(in: &cancellables)
        
        playerVM.$rate
            .sink { [weak self] value in
                self?.rate = value
            }
            .store(in: &cancellables)
        
        playerVM.$sleepRemaining
            .sink { [weak self] value in
                self?.sleepRemaining = value
            }
            .store(in: &cancellables)
        
        playerVM.$currentTrackIndex
            .sink { [weak self] value in
                self?.currentTrackIndex = value
            }
            .store(in: &cancellables)
        
        playerVM.$currentTrackTitle
            .sink { [weak self] value in
                self?.currentTrackTitle = value
            }
            .store(in: &cancellables)
        
        playerVM.$hasAudioStream
            .sink { [weak self] value in
                self?.hasAudioStream = value
            }
            .store(in: &cancellables)
        
        playerVM.$loadingStatus
            .sink { [weak self] value in
                self?.loadingStatus = value
            }
            .store(in: &cancellables)
        
        playerVM.$currentChapterStart
            .sink { [weak self] value in
                self?.currentChapterStart = value
            }
            .store(in: &cancellables)

        playerVM.$currentChapterDuration
            .sink { [weak self] value in
                self?.currentChapterDuration = value
            }
            .store(in: &cancellables)
        
        print("[GlobalAudioManager] ✅ Bindings setup complete")
    }


    // MARK: - Session Management (Canonical ABS Flow)

    /// Start playback session using canonical /api/items/{id}/play
    private func startPlaybackSession() {
        guard let item = currentItem else { return }
        guard let appVM = appViewModel else { return }

        Task {
            if let result = await appVM.startPlaybackSession(for: item) {
                currentSessionId = result.sessionId
                lastSyncTime = Date()
                lastSyncPosition = currentTime
                print("[GlobalAudioManager] ✅ Playback session started: \(result.sessionId)")
            } else {
                print("[GlobalAudioManager] ❌ Failed to start playback session")
            }
        }
    }

    /// Send periodic sync every 20s with delta timeListened
    private func syncSessionPeriodic() {
        guard let sessionId = currentSessionId else { return }
        guard let appVM = appViewModel else { return }
        guard isPlaying else { return } // Only sync while playing

        let now = Date()
        let currentPosition = currentTime
        let totalDuration = duration

        // Calculate delta time listened since last sync
        let deltaTime: Double
        if let lastSync = lastSyncTime {
            deltaTime = now.timeIntervalSince(lastSync)
        } else {
            deltaTime = 0
        }

        print("[GlobalAudioManager] 📤 Periodic session sync: pos=\(currentPosition)s, delta=\(deltaTime)s")

        Task {
            await appVM.syncSession(
                sessionId: sessionId,
                currentTime: currentPosition,
                timeListened: deltaTime,
                duration: totalDuration
            )
        }

        // Update last sync tracking
        lastSyncTime = now
        lastSyncPosition = currentPosition
    }

    /// Immediate sync after seek with timeListened=0
    private func syncSessionAfterSeek() async {
        guard let sessionId = currentSessionId else { return }
        guard let appVM = appViewModel else { return }

        let currentPosition = currentTime
        let totalDuration = duration

        print("[GlobalAudioManager] ⏩ Seek sync: pos=\(currentPosition)s, timeListened=0")

        await appVM.syncSession(
            sessionId: sessionId,
            currentTime: currentPosition,
            timeListened: 0,
            duration: totalDuration
        )

        // Update tracking
        lastSyncTime = Date()
        lastSyncPosition = currentPosition
    }

    /// Save durable progress via PATCH /api/me/progress
    private func saveProgressAndSyncSession() {
        guard let item = currentItem else { return }
        guard let appVM = appViewModel else { return }

        let currentPosition = currentTime
        let totalDuration = duration

        print("[GlobalAudioManager] 💾 Saving durable progress: \(currentPosition)s / \(totalDuration)s")

        Task {
            // Save progress to durable storage
            await appVM.saveProgress(for: item, seconds: currentPosition, duration: totalDuration)

            // Also send session sync if session is active
            if let sessionId = currentSessionId {
                let deltaTime: Double
                if let lastSync = lastSyncTime {
                    deltaTime = Date().timeIntervalSince(lastSync)
                } else {
                    deltaTime = 0
                }

                await appVM.syncSession(
                    sessionId: sessionId,
                    currentTime: currentPosition,
                    timeListened: deltaTime,
                    duration: totalDuration
                )

                lastSyncTime = Date()
                lastSyncPosition = currentPosition
            }
        }
    }

    /// Close session with final state
    private func closeCurrentSession() async {
        guard let sessionId = currentSessionId else { return }
        guard let appVM = appViewModel else { return }

        let currentPosition = currentTime
        let totalDuration = duration

        // Calculate final delta
        let deltaTime: Double
        if let lastSync = lastSyncTime {
            deltaTime = Date().timeIntervalSince(lastSync)
        } else {
            deltaTime = 0
        }

        print("[GlobalAudioManager] 📝 Closing session with final state: pos=\(currentPosition)s, delta=\(deltaTime)s")

        await appVM.closeSession(
            sessionId: sessionId,
            currentTime: currentPosition,
            timeListened: deltaTime,
            duration: totalDuration
        )

        currentSessionId = nil
        lastSyncTime = nil
        lastSyncPosition = 0
        print("[GlobalAudioManager] ✅ Session closed")
    }

    // MARK: - Periodic Timers

    /// Start periodic timers: session sync (20s), progress PATCH (90s)
    private func startPeriodicTimers() {
        stopPeriodicTimers()

        // Session sync every 20s
        sessionSyncTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.syncSessionPeriodic()
            }
        }

        // Progress PATCH every 90s
        progressSyncTimer = Timer.scheduledTimer(withTimeInterval: 90.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.saveProgressAndSyncSession()
            }
        }

        print("[GlobalAudioManager] ⏲️ Periodic timers started: session=20s, progress=90s")
    }

    /// Stop all periodic timers
    private func stopPeriodicTimers() {
        sessionSyncTimer?.invalidate()
        sessionSyncTimer = nil

        progressSyncTimer?.invalidate()
        progressSyncTimer = nil

        print("[GlobalAudioManager] ⏲️ Periodic timers stopped")
    }
}

