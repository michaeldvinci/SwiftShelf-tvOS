import SwiftUI
import AVFoundation

struct MediaPlayerView: View {
    let item: LibraryItem
    
    @State private var isPlaying = false
    @State private var player: AVPlayer? = nil
    @State private var playerItemContext = 0
    
    private var streamURL: URL? {
        URL(string: "https://sample.abs.host/api/items/\(item.id)/play")
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Text(item.title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
            if let author = item.authorNameLF ?? item.authorName {
                Text(author).font(.headline)
            }
            if let series = item.seriesName {
                Text(series).font(.subheadline)
            }
            Spacer()
            HStack {
                Button(action: {
                    if isPlaying {
                        player?.pause()
                    } else {
                        player?.play()
                    }
                    isPlaying.toggle()
                }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .resizable()
                        .frame(width: 70, height: 70)
                }
            }
            Spacer()
        }
        .padding()
        .onAppear {
            if let url = streamURL {
                let avItem = AVPlayerItem(url: url)
                let avPlayer = AVPlayer(playerItem: avItem)
                player = avPlayer
            }
        }
        .onDisappear {
            player?.pause()
            isPlaying = false
        }
    }
}
