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
    
    private var playerViewModel: PlayerViewModel?
    private var cancellables = Set<AnyCancellable>()
    
    // Cached resume position (seconds) to apply on first play after load
    private var pendingResumeSeconds: Double?
    
    private override init() {
        super.init()
        print("[GlobalAudioManager] 🎬 Initialized")
    }
    
    func loadItem(_ item: LibraryItem, appVM: ViewModel) async {
        print("[GlobalAudioManager] 🚀 Loading item: \(item.title)")
        
        // Stop current playback
        await stopCurrentPlayback()
        
        // Set new current item
        currentItem = item
        loadingStatus = "Loading \(item.title)..."
        
        print("[GlobalAudioManager] 🖼️ Loading cover art...")
        // Load cover art
        if let coverTuple = await appVM.loadCover(for: item) {
            coverArt = coverTuple
            print("[GlobalAudioManager] ✅ Cover art loaded successfully")
        } else {
            print("[GlobalAudioManager] ❌ Failed to load cover art")
        }
        
        print("[GlobalAudioManager] 🎵 Creating PlayerViewModel...")
        // Create new player view model
        let newPlayerVM = PlayerViewModel(item: item, appVM: appVM)
        playerViewModel = newPlayerVM
        
        // Bind to player view model
        print("[GlobalAudioManager] 🔗 Binding to PlayerViewModel...")
        bindToPlayerViewModel(newPlayerVM)
        
        // Configure and prepare (but don't auto-play)
        print("[GlobalAudioManager] ⚙️ Configuring and preparing player...")
        await newPlayerVM.configureAndPrepare()
        
        // Pre-fetch last progress but do not seek yet; apply on first play
        if let last = await appVM.loadProgress(for: item) {
            let resume = max(0, last - 5)
            print("[GlobalAudioManager] ⏪ Cached resume position: \(resume)s (from server: \(last)s)")
            self.pendingResumeSeconds = resume
        } else {
            self.pendingResumeSeconds = nil
        }
        
        print("[GlobalAudioManager] ✅ Item loading complete")
    }
    
    func play() {
        print("[GlobalAudioManager] ▶️ Play requested")
        if let resume = pendingResumeSeconds, resume > 0 {
            print("[GlobalAudioManager] ⤴️ Applying cached resume before play: \(resume)s")
            playerViewModel?.seek(to: resume)
            pendingResumeSeconds = nil
        }
        playerViewModel?.play()
    }
    
    func pause() {
        print("[GlobalAudioManager] ⏸️ Pause requested")
        playerViewModel?.pause()
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
        
        print("[GlobalAudioManager] ✅ Bindings setup complete")
    }
}

