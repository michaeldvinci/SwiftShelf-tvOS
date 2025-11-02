//
//  CompactPlayerView.swift
//  SwiftShelf
//
//  Created by michaeldvinci on 10/21/25.
//

import SwiftUI
import Combine

struct CompactPlayerView: View {
    @EnvironmentObject var audioManager: GlobalAudioManager
    @EnvironmentObject var viewModel: ViewModel
    @State private var localRate: Float = 1.0
    @State private var cancellable: AnyCancellable?
    
    var body: some View {
        if let currentItem = audioManager.currentItem {
            VStack(spacing: 0) {
                // Player controls
                HStack(spacing: 12) {
                    // Artwork
                    if let artwork = audioManager.coverArt?.0 {
                        artwork
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                    }
                    
                    // Title and info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentItem.title)
                            .font(.headline)
                            .lineLimit(1)
                        
                        if let author = currentItem.authorNameLF ?? currentItem.authorName {
                            Text(author)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        // Show play status
                        if !audioManager.hasAudioStream {
                            Text("Loading...")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        } else if audioManager.isPlaying {
                            Text("Playing")
                                .font(.caption2)
                                .foregroundColor(.green)
                        } else {
                            Text("Paused")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Show transport controls instead of opening full player
                    if audioManager.hasAudioStream {
                        // Time display
                        VStack(spacing: 2) {
                            Text(formatTime(audioManager.currentTime))
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                            Text(formatTime(audioManager.duration))
                                .font(.caption2)
                                .monospacedDigit()
//                                .foregroundColor(.tertiary)
                        }
                    } else {
                        // Show loading indicator while preparing
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // Progress bar
                GeometryReader { geometry in
                    let progress = audioManager.duration > 0 ? audioManager.currentTime / audioManager.duration : 0

                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(height: 3)

                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: geometry.size.width * CGFloat(progress), height: 3)
                    }
                }
                .frame(height: 3)

                // Transport controls
                HStack(spacing: 16) {
                    // Previous Chapter
                    Button(action: { audioManager.previousChapter() }) {
                        Image(systemName: "backward.end.fill")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())

                    // Rewind 15 seconds
                    Button(action: { audioManager.skip(-15) }) {
                        Image(systemName: "gobackward.15")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())

                    // Play/Pause
                    Button(action: { audioManager.togglePlayPause() }) {
                        Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())

                    // Forward 15 seconds
                    Button(action: { audioManager.skip(15) }) {
                        Image(systemName: "goforward.15")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())

                    // Next Chapter
                    Button(action: { audioManager.nextChapter() }) {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    
                    Spacer(minLength: 8)

                    // Speed controls: label and +/- buttons stepping by 0.1, clamped 1.0–2.5
                    HStack(spacing: 8) {
                        Button(action: {
                            let newRate = max(1.0, audioManager.rate - 0.1)
                            audioManager.setRate(Float((Double(newRate) * 10).rounded() / 10))
                            localRate = audioManager.rate
                        }) {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.plain)

                        Text(String(format: "%.1fx", audioManager.rate))
                            .font(.caption).monospacedDigit()
                            .frame(minWidth: 44, alignment: .center)

                        Button(action: {
                            let newRate = min(2.5, audioManager.rate + 0.1)
                            audioManager.setRate(Float((Double(newRate) * 10).rounded() / 10))
                            localRate = audioManager.rate
                        }) {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color.black.opacity(0.3))
            .onAppear {
                localRate = audioManager.rate
            }
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

#Preview {
    CompactPlayerView()
        .environmentObject(GlobalAudioManager.shared)
}
