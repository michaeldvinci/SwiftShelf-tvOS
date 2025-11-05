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

    // Progress saving
    private var progressTimer: Timer?
    private var lastProgressSave: Date = .distantPast
    private weak var appViewModel: ViewModel?

    // Session management
    private var currentSessionId: String?
    private var sessionStartTime: Date?
    private var totalListeningTime: TimeInterval = 0 // cumulative listening time in seconds
    private var lastPlayTime: Date?

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
        print("[GlobalAudioManager] ▶️▶️▶️ PLAY v2.0 ▶️▶️▶️")
        print("[GlobalAudioManager] currentItem: \(currentItem?.title ?? "nil")")
        print("[GlobalAudioManager] currentItem.id: \(currentItem?.id ?? "nil")")
        print("[GlobalAudioManager] currentItem.duration: \(currentItem?.duration.map { String($0) } ?? "nil")")
        print("===========================================")

        if let resume = pendingResumeSeconds, resume > 0 {
            print("[GlobalAudioManager] ⤴️ Applying cached resume before play: \(resume)s")
            playerViewModel?.seek(to: resume)
            pendingResumeSeconds = nil
        }

        // Track play time for listening duration calculation
        lastPlayTime = Date()

        // Set session start time if this is the first play
        if sessionStartTime == nil {
            sessionStartTime = Date()
        }

        playerViewModel?.play()
        startProgressTimer()

        // Start session if not already started
        if currentSessionId == nil {
            startSession()
        }
    }

    func pause() {
        print("[GlobalAudioManager] ⏸️ Pause requested")

        // Update total listening time
        if let lastPlay = lastPlayTime {
            totalListeningTime += Date().timeIntervalSince(lastPlay)
            lastPlayTime = nil
        }

        playerViewModel?.pause()
        stopProgressTimer()
        // Save progress immediately when pausing
        saveProgressNow()
    }
    
    func togglePlayPause() {
        print("[GlobalAudioManager] ⏯️ Toggle play/pause requested")
        playerViewModel?.togglePlayPause()
    }
    
    func seek(to seconds: Double) {
        print("[GlobalAudioManager] ⏩ Seek to \(seconds)s requested")
        playerViewModel?.seek(to: seconds)
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

        // Stop progress timer and save final progress
        stopProgressTimer()
        saveProgressNow()

        // Close session
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
        sessionStartTime = nil
        totalListeningTime = 0
        lastPlayTime = nil
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

    // MARK: - Progress Saving

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            let strongSelf = self
            Task { @MainActor in
                strongSelf?.saveProgressNow()
            }
        }
        print("[GlobalAudioManager] 💾 Progress timer started (10s interval)")
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
        print("[GlobalAudioManager] 💾 Progress timer stopped")
    }

    private func saveProgressNow() {
        print("===========================================")
        print("[GlobalAudioManager] 💾💾💾 SAVE PROGRESS v2.0 💾💾💾")

        guard let item = currentItem else {
            print("[GlobalAudioManager] ⚠️ Cannot save progress: no current item")
            print("===========================================")
            return
        }

        print("[GlobalAudioManager] Item: \(item.title)")
        print("[GlobalAudioManager] Item ID: \(item.id)")
        print("[GlobalAudioManager] GlobalAudioManager.duration (from player): \(duration)")

        guard let appVM = appViewModel else {
            print("[GlobalAudioManager] ⚠️ Cannot save progress: no appViewModel")
            print("===========================================")
            return
        }

        // Throttle saves to avoid spamming the server
        let now = Date()
        guard now.timeIntervalSince(lastProgressSave) >= 5.0 else {
            print("[GlobalAudioManager] ⏰ Throttled (last save was \(now.timeIntervalSince(lastProgressSave))s ago)")
            print("===========================================")
            return
        }
        lastProgressSave = now

        let currentPosition = currentTime
        let totalDuration = duration  // Use the duration from the player, not from the item

        // Calculate current listening time (includes time since last play if currently playing)
        var currentListeningTime = totalListeningTime
        if let lastPlay = lastPlayTime {
            currentListeningTime += Date().timeIntervalSince(lastPlay)
        }

        // Get session start timestamp
        let startedAtMs = sessionStartTime.map { Int($0.timeIntervalSince1970 * 1000) }

        // If we have a session, sync it. Otherwise fall back to progress API
        if let sessionId = currentSessionId {
            print("[GlobalAudioManager] 💾 Syncing session: \(Int(currentPosition))s / \(Int(totalDuration))s, listened: \(Int(currentListeningTime))s")
            print("===========================================")
            Task {
                await appVM.syncSession(sessionId: sessionId, currentTime: currentPosition, duration: totalDuration, timeListened: currentListeningTime)
            }
        } else {
            print("[GlobalAudioManager] 💾 Saving progress (no session): \(Int(currentPosition))s / \(Int(totalDuration))s, listened: \(Int(currentListeningTime))s")
            print("===========================================")
            Task {
                await appVM.saveProgress(
                    for: item,
                    seconds: currentPosition,
                    duration: totalDuration,
                    timeListened: currentListeningTime,
                    startedAt: startedAtMs
                )
            }
        }
    }

    // MARK: - Session Management

    private func startSession() {
        guard let item = currentItem else { return }
        guard let appVM = appViewModel else { return }

        Task {
            if let sessionId = await appVM.startSession(for: item) {
                currentSessionId = sessionId
                print("[GlobalAudioManager] 📝 Session started: \(sessionId)")
            }
        }
    }

    private func closeCurrentSession() async {
        guard let sessionId = currentSessionId else { return }
        guard let appVM = appViewModel else { return }

        await appVM.closeSession(sessionId: sessionId)
        currentSessionId = nil
        print("[GlobalAudioManager] 📝 Session closed")
    }
}

