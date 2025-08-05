import SwiftUI
import AVFoundation
import AVKit

struct MediaPlayerView: View {
    let item: LibraryItem
    @EnvironmentObject var viewModel: ViewModel
    @State private var player: AVPlayer? = nil
    @State private var isPlaying = false
    @State private var duration: Double = 1
    @State private var currentTime: Double = 0
    @State private var coverArt: (Image, UIImage)? = nil
    @State private var isSeeking = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            VStack(spacing: 24) {
                // Cover Art
                if let (image, uiImage) = coverArt {
                    CoverArtView(image: image, uiImage: uiImage, maxWidth: 260, maxHeight: 260)
                        .shadow(radius: 12, y: 6)
                        .padding(.top)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 240, height: 240)
                        .overlay(
                            ProgressView()
                        )
                        .shadow(radius: 10, y: 4)
                        .padding(.top)
                }
                // Title and author
                Text(item.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                if let author = item.authorNameLF ?? item.authorName {
                    Text(author)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                // Time display
                HStack {
                    Text(formatTime(currentTime)).font(.caption.monospacedDigit())
                    Spacer()
                    Text(formatTime(duration)).font(.caption.monospacedDigit())
                }
                .padding(.horizontal, 16)
                // Playback controls
                HStack(spacing: 50) {
                    Button(action: seekBackward) {
                        Image(systemName: "gobackward.30")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundStyle(.ultraThickMaterial)
                            .background(Circle().fill(.ultraThinMaterial).frame(width: 56, height: 56))
                            .shadow(radius: 4, y: 2)
                    }
                    Button(action: togglePlayPause) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.accentColor)
                            .background(Circle().fill(.ultraThinMaterial).frame(width: 80, height: 80))
                            .shadow(radius: 8, y: 4)
                    }
                    Button(action: seekForward) {
                        Image(systemName: "goforward.30")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundStyle(.ultraThickMaterial)
                            .background(Circle().fill(.ultraThinMaterial).frame(width: 56, height: 56))
                            .shadow(radius: 4, y: 2)
                    }
                }
                Spacer(minLength: 24)
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding(.top, 12)
                }
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 28)
            .background(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.12), radius: 32, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1.2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.vertical, 32)
        }
        .onAppear {
            loadCoverAsync()
            Task { await startPlayback() }
        }
        .onDisappear { player?.pause() }
    }
    
    // MARK: - Actions
    func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    func seekBackward() {
        guard let player = player else { return }
        let newTime = max(currentTime - 30, 0)
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 1))
    }
    func seekForward() {
        guard let player = player else { return }
        let newTime = min(currentTime + 30, duration)
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 1))
    }
    func sliderEditingChanged(_ editing: Bool) {
        isSeeking = editing
        if !editing, let player = player {
            player.seek(to: CMTime(seconds: currentTime, preferredTimescale: 1))
        }
    }
    func formatTime(_ seconds: Double) -> String {
        let intSec = Int(seconds)
        let mins = intSec / 60
        let secs = intSec % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    // MARK: - Playback
    func startPlayback() async {
        do {
            let host = viewModel.host.trimmingCharacters(in: .whitespacesAndNewlines)
            let path = "/api/items/\(item.id)/play"
            guard let url = URL(string: host + path) else {
                errorMessage = "Invalid playback URL"; return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(viewModel.apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let jsonBody: [String: Any] = [
                "deviceInfo": ["clientVersion": "0.0.1"],
                "supportedMimeTypes": ["audio/flac", "audio/mpeg", "audio/mp4"]
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)

            let (_, resp) = try await URLSession.shared.data(for: request)
            let http = resp as? HTTPURLResponse
            let mediaURL: URL
            if let location = http?.allHeaderFields["Location"] as? String, let locURL = URL(string: location) {
                mediaURL = locURL
            } else {
                mediaURL = url
            }
            self.player = AVPlayer(url: mediaURL)
            observePlayer()
            player?.play()
            isPlaying = true
        } catch {
            errorMessage = "Playback failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Observers
    enum ObservePlayerKeys {
        static var currentAssetKey: AVAsset? = nil
    }

    func observePlayer() {
        guard let player = player else { return }
        let interval = CMTime(seconds: 0.5, preferredTimescale: 10)
        player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            if !isSeeking {
                self.currentTime = time.seconds
            }
            if let avItem = player.currentItem {
                let asset = avItem.asset
                if ObservePlayerKeys.currentAssetKey !== asset {
                    ObservePlayerKeys.currentAssetKey = asset
                    Task {
                        await self.loadAssetDuration(asset)
                    }
                }
            }
        }
    }

    func loadAssetDuration(_ asset: AVAsset) async {
        do {
            let duration = try await asset.load(.duration)
            let seconds = duration.seconds.isFinite ? duration.seconds : 1
            await MainActor.run { self.duration = seconds }
        } catch {
            await MainActor.run { self.duration = 1 }
        }
    }
    
    func loadCoverAsync() {
        Task {
            if let tuple = await viewModel.loadCover(for: item) {
                self.coverArt = tuple
            }
        }
    }
}
