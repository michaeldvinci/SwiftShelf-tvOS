//
//  BookDetailsPopupView.swift
//  SwiftShelf
//
//  Created by michaeldvinci on 11/1/25.
//

import SwiftUI

struct BookDetailsPopupView: View {
    let item: LibraryItem
    @EnvironmentObject var viewModel: ViewModel
    @EnvironmentObject var audioManager: GlobalAudioManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var coverArt: (Image, UIImage)?
    
    var body: some View {
        ZStack {
            // Full-screen backdrop stays at the root
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            // Centered card container (tune size here)
            HStack(alignment: .center, spacing: 60) {
                // Cover art - fixed size
                if let artwork = coverArt?.0 {
                    artwork
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 440, height: 440)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 280, height: 280)
                        .cornerRadius(16)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.6))
                        )
                }

                // Title and details section
                VStack(alignment: .leading, spacing: 24) {
                    // Title
                    Text(item.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Series
                    if let series = item.seriesName {
                        Text(series)
                            .font(.title2)
                            .foregroundColor(Color.secondary)
                    }

                    // Author
                    if let author = item.authorNameLF ?? item.authorName {
                        Text("by \(author)")
                            .font(.title3)
                            .foregroundColor(Color.secondary)
                    }

                    // Duration - single horizontal line
                    if let duration = item.duration {
                        HStack(spacing: 20) {
                            Text("DURATION")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(Color.secondary)
                                .fixedSize()
                            Text(formatDuration(duration))
                                .font(.title3)
                                .foregroundColor(Color.primary)
                        }
                    }

                    // Play Button
                    Button(action: {
                        Task {
                            print("[BookDetailsPopup] ▶️ Play button tapped for: \(item.title)")
                            await audioManager.loadItem(item, appVM: viewModel)

                            if let lastPosition = await viewModel.loadProgress(for: item) {
                                print("[BookDetailsPopup] ⏭️ Restoring progress to: \(lastPosition)s")
                                audioManager.seek(to: lastPosition)
                            }

                            audioManager.play()
                            dismiss()
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 18, weight: .bold))
                            Text("Play")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 50)
                        .padding(.vertical, 18)
                    }
                    .buttonStyle(.plain)
                    .padding(Edge.Set.top, 16)
                }
                .frame(maxWidth: 650)
            }
            .padding(40)
            .frame(width: 1400, height: 900, alignment: .center) // tune card size here
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 15)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .task {
            // Load cover art
            if let coverTuple = await viewModel.loadCover(for: item) {
                coverArt = coverTuple
            }
        }
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if hours > 0 {
            return String(format: "%d hr %d min", hours, minutes)
        } else {
            return String(format: "%d min", minutes)
        }
    }
}

#Preview {
    BookDetailsPopupView(item: LibraryItem(
        id: "sample",
        media: LibraryItem.Media(
            duration: 43440.0,
            coverPath: nil,
            metadata: LibraryItem.Media.Metadata(
                title: "New Dreams Ultimate Level 1 #4",
                authors: nil,
                series: nil,
                authorNameLF: nil,
                authorName: "Shawn Wilson",
                seriesName: "Ultimate Level 1"
            ),
            audioFiles: nil,
            chapters: nil,
            tracks: nil
        ),
        userMediaProgress: nil,
        addedAt: nil,
        updatedAt: nil
    ))
    .environmentObject(ViewModel())
    .environmentObject(GlobalAudioManager.shared)
}

