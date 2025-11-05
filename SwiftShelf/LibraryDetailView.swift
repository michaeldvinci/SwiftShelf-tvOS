//
//  LibraryDetailView.swift
//  SwiftShelf
//
//  Created by michaeldvinci on 8/2/25.
//

import SwiftUI
import AVFoundation
import Combine

// Import ProgressBarColor enum from SettingsView
extension ProgressBarColor {
    // Shared with SettingsView
}

struct LibraryItemDetailPopup: View {
    let item: LibraryItem
    let cover: (Image, UIImage)?
    var body: some View {
        VStack(spacing: 24) {
            if let (img, uiImg) = cover {
                CoverArtView(image: img, uiImage: uiImg, maxWidth: 220, maxHeight: 220)
                    .cornerRadius(14)
            }
            Text(item.title).font(.title.bold())
            if let author = item.authorNameLF ?? item.authorName {
                Text(author).font(.headline)
            }
            if let series = item.seriesName {
                Text(series).font(.subheadline)
            }
            if let duration = item.duration, duration > 0 {
                Text("Duration: \(formatDuration(duration))").font(.footnote)
            }
            if let added = item.addedAt {
                Text("Added: \(Date(timeIntervalSince1970: added).formatted(date: .abbreviated, time: .shortened))").font(.footnote)
            }
            if let updated = item.updatedAt {
                Text("Updated: \(Date(timeIntervalSince1970: updated).formatted(date: .abbreviated, time: .shortened))").font(.footnote)
            }
            Spacer()
        }
        .padding()
        .presentationDetents([.medium, .large])
    }
    private func formatDuration(_ seconds: Double) -> String {
        let intSec = Int(seconds)
        let hrs = intSec / 3600
        let mins = (intSec % 3600) / 60
        let secs = intSec % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        } else {
            return String(format: "%d:%02d", mins, secs)
        }
    }
}

struct LibraryDetailView: View {
    let library: SelectedLibrary

    @EnvironmentObject var vm: ViewModel
    @EnvironmentObject var config: LibraryConfig
    @EnvironmentObject var audioManager: GlobalAudioManager

    @State private var items: [LibraryItem] = []
    @State private var unfinished: [LibraryItem] = []
    @State private var isLoadingItems = false
    @State private var isLoadingUnfinished = false
    @State private var coverImages: [String: (Image, UIImage)] = [:]
    @State private var progressPercent: [String: Double] = [:] // 0.0...1.0
    @State private var hasLoadedOnce = false

    // Binding to parent's selectedMediaItem instead of local selectedItem
    @Binding var selectedMediaItem: LibraryItem?

    private let thumbSize: CGFloat = 225

    // Add initializer to accept the binding
    init(library: SelectedLibrary, selectedMediaItem: Binding<LibraryItem?> = .constant(nil)) {
        self.library = library
        self._selectedMediaItem = selectedMediaItem
    }

    // Unified audio-player UI for all playback sources: selection always sets selectedItem and presents MediaPlayerView fullScreenCover.
    // No system alert or external URL opening for missing audio streams; MediaPlayerView handles audio availability UI.
    // Unified player matches AVPlayerViewController style, showing artwork above system controls.

    var body: some View {
        VStack(spacing: 0) {
            // Non-scrolling top separator to clearly delineate nav bar area
            Color.clear.frame(height: 0)

            // Scrollable content only inside this ScrollView
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 40) {
                    Divider()

                    VStack(spacing: 32) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent")
                                .font(.headline)
                                .padding(.horizontal)

                            if isLoadingItems {
                                ProgressView()
                                    .padding(.horizontal)
                            } else if items.isEmpty {
                                Text("No recent items").foregroundColor(.secondary).padding(.horizontal)
                            } else {
                                LibraryCarouselView(
                                    items: items,
                                    coverImages: $coverImages,
                                    progressPercent: $progressPercent,
                                    loadCover: { await vm.loadCover(for: $0) },
                                    thumbSize: thumbSize,
                                    onSelect: { item in
                                        selectedMediaItem = item
                                    }
                                )
                                .environmentObject(vm)
                                .frame(height: 350)
                            }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Continue")
                                .font(.headline)
                                .padding(.horizontal)

                            if isLoadingUnfinished {
                                ProgressView()
                                    .padding(.horizontal)
                            } else if unfinished.isEmpty {
                                Text("No in-progress items")
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                            } else {
                                LibraryCarouselView(
                                    items: unfinished,
                                    coverImages: $coverImages,
                                    progressPercent: $progressPercent,
                                    loadCover: { await vm.loadCover(for: $0) },
                                    thumbSize: thumbSize,
                                    onSelect: { item in
                                        selectedMediaItem = item
                                    }
                                )
                                .environmentObject(vm)
                                .frame(height: 350)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            Spacer(minLength: 0)
        }
        .onAppear {
            if !hasLoadedOnce {
                hasLoadedOnce = true
                Task { await loadItems() }
            }
        }
        .onChange(of: vm.refreshToken) { _, _ in
            Task { await loadItems() }
        }
    }

    private func loadItems() async {
        if isLoadingItems || isLoadingUnfinished { return }
        guard !vm.host.isEmpty, !vm.apiKey.isEmpty else {
            items = []
            unfinished = []
            return
        }
        let lib = library

        isLoadingItems = true
        defer { isLoadingItems = false }
        if let fetched = await vm.fetchItems(forLibrary: lib.id, limit: vm.libraryItemLimit, sortBy: "addedAt", descBy: "1") {
            items = fetched
            await withTaskGroup(of: (String, (Image, UIImage)?).self) { group in
                for item in fetched {
                    group.addTask {
                        let imageTuple = await vm.loadCover(for: item)
                        return (item.id, imageTuple)
                    }
                }
                for await (id, imageTuple) in group {
                    if let imgTup = imageTuple {
                        coverImages[id] = imgTup
                    }
                }
            }
            await withTaskGroup(of: (String, Double?, Double?).self) { group in
                for item in fetched {
                    group.addTask {
                        let last = await vm.loadProgress(for: item)
                        let fallback = item.userMediaProgress?.progress
                        return (item.id, last, fallback)
                    }
                }
                for await (id, last, fallback) in group {
                    if let it = fetched.first(where: { $0.id == id }) {
                        let dur = it.duration
                        // Fallback is already a percentage (0-1), last is seconds
                        let lastSeconds: Double?
                        if let last = last {
                            lastSeconds = last
                        } else if let fallback = fallback, let dur = dur, dur > 0 {
                            // Convert percentage to seconds
                            lastSeconds = fallback * dur
                        } else {
                            lastSeconds = nil
                        }

                        #if DEBUG
                        print("[Progress] Recent: \"\(it.title)\" last=\(String(describing: last)) fallback=\(String(describing: fallback)) dur=\(String(describing: dur))")
                        #endif
                        if let d = dur, d > 0, let ls = lastSeconds {
                            let pct = max(0.0, min(1.0, ls / d))
                            progressPercent[id] = pct
                        } else {
                            progressPercent[id] = 0
                        }
                    }
                }
            }
        } else {
            items = []
        }

        isLoadingUnfinished = true
        if let fetchedUnfinished = await vm.fetchItems(forLibrary: lib.id, limit: vm.libraryItemLimit, sortBy: "updatedAt", descBy: "1") {
            unfinished = fetchedUnfinished
            await withTaskGroup(of: (String, (Image, UIImage)?).self) { group in
                for item in fetchedUnfinished {
                    group.addTask {
                        let imageTuple = await vm.loadCover(for: item)
                        return (item.id, imageTuple)
                    }
                }
                for await (id, imageTuple) in group {
                    if let imgTup = imageTuple {
                        coverImages[id] = imgTup
                    }
                }
            }
            await withTaskGroup(of: (String, Double?, Double?).self) { group in
                for item in fetchedUnfinished {
                    group.addTask {
                        let last = await vm.loadProgress(for: item)
                        let fallback = item.userMediaProgress?.progress
                        return (item.id, last, fallback)
                    }
                }
                for await (id, last, fallback) in group {
                    if let it = fetchedUnfinished.first(where: { $0.id == id }) {
                        let dur = it.duration
                        // Fallback is already a percentage (0-1), last is seconds
                        let lastSeconds: Double?
                        if let last = last {
                            lastSeconds = last
                        } else if let fallback = fallback, let dur = dur, dur > 0 {
                            // Convert percentage to seconds
                            lastSeconds = fallback * dur
                        } else {
                            lastSeconds = nil
                        }

                        #if DEBUG
                        print("[Progress] Continue: \"\(it.title)\" last=\(String(describing: last)) fallback=\(String(describing: fallback)) dur=\(String(describing: dur))")
                        #endif
                        if let d = dur, d > 0, let ls = lastSeconds {
                            let pct = max(0.0, min(1.0, ls / d))
                            progressPercent[id] = pct
                        } else {
                            progressPercent[id] = 0
                        }
                    }
                }
            }
        } else {
            unfinished = []
        }
        isLoadingUnfinished = false
    }

    struct LibraryCarouselView: View {
        @EnvironmentObject var vm: ViewModel
        let items: [LibraryItem]
        @Binding var coverImages: [String: (Image, UIImage)]
        @Binding var progressPercent: [String: Double]
        var loadCover: (LibraryItem) async -> (Image, UIImage)?
        let thumbSize: CGFloat
        let onSelect: (LibraryItem) -> Void

        private let spacing: CGFloat = 95

        var body: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: spacing) {
                    ForEach(items) { item in
                        CarouselItemView(
                            item: item,
                            cover: coverImages[item.id],
                            progress: progressPercent[item.id] ?? 0,
                            loadCover: {
                                if let imageTuple = await loadCover(item) {
                                    coverImages[item.id] = imageTuple
                                }
                            },
                            thumbSize: thumbSize,
                            onSelect: {
                                onSelect(item)
                            }
                        )
                        .frame(width: thumbSize)
                    }
                }
                .padding(.horizontal, 40)
            }
        }
    }

    struct CarouselItemView: View {
        let item: LibraryItem
        var cover: (Image, UIImage)?
        let progress: Double // 0.0...1.0
        let loadCover: () async -> Void
        let thumbSize: CGFloat
        let onSelect: () -> Void

        @State private var isFocused: Bool = false
        @AppStorage("progressBarColor") var progressBarColorString: String = "Yellow"

        var progressBarColor: ProgressBarColor {
            ProgressBarColor(rawValue: progressBarColorString) ?? .yellow
        }

        var body: some View {
            Button {
                onSelect()
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    ZStack {
                        if let (img, uiImg) = cover {
                            CoverArtView(image: img, uiImage: uiImg, maxWidth: thumbSize, maxHeight: thumbSize)
                                .cornerRadius(8)
                                .frame(width: thumbSize, height: thumbSize)
                        } else {
                            Color.gray
                                .frame(width: thumbSize, height: thumbSize)
                                .cornerRadius(8)
                                .task {
                                    await loadCover()
                                }
                        }
                    }
                    .overlay(
                        VStack(spacing: 0) {
                            Spacer()
                            // Progress bar
                            GeometryReader { geo in
                                let width = geo.size.width
                                let barHeight: CGFloat = 6
                                let progressWidth = max(0, min(width * progress, width))

                                ZStack(alignment: .leading) {
                                    // Background
                                    Capsule().fill(Color.white.opacity(0.15)).frame(width: width, height: barHeight)

                                    // Progress fill
                                    if progressBarColor == .rainbow {
                                        LinearGradient(
                                            colors: [.red, .orange, .yellow, .green, .blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                        .frame(width: progressWidth, height: barHeight)
                                        .clipShape(Capsule())
                                    } else {
                                        Capsule()
                                            .fill(progressBarColor.color)
                                            .frame(width: progressWidth, height: barHeight)
                                    }
                                }
                            }
                            .frame(height: 6)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isFocused ? Color.white.opacity(0.8) : Color.clear, lineWidth: 3)
                    )
                    .scaleEffect(isFocused ? 1.08 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: isFocused)

                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                        .frame(maxWidth: thumbSize, alignment: .leading)

                    if let author = item.authorNameLF {
                        Text(author)
                            .lineLimit(1)
                            .foregroundColor(.secondary)
                            .font(.system(size: 14, weight: .regular))
                            .frame(maxWidth: thumbSize, alignment: .leading)
                    }

                    if let dur = item.duration, dur > 0 {
                        Text(formatDuration(dur))
                            .lineLimit(1)
                            .foregroundColor(.gray)
                            .font(.system(size: 14, weight: .regular))
                            .frame(maxWidth: thumbSize, alignment: .leading)
                    }
                }
                .padding(4)
                .background(Color.clear)
            }
            .buttonStyle(.plain)
        }

        private func formatDuration(_ seconds: Double) -> String {
            let intSec = Int(seconds)
            let hrs = intSec / 3600
            let mins = (intSec % 3600) / 60
            let secs = intSec % 60
            if hrs > 0 {
                return String(format: "%d:%02d:%02d", hrs, mins, secs)
            } else {
                return String(format: "%d:%02d", mins, secs)
            }
        }
    }
    
    // MARK: - Full-screen Item Details Overlay (Apple Music-style for tvOS)
    struct ItemDetailsOverlay: View {
        let item: LibraryItem
        @Binding var isPresented: Bool
        @EnvironmentObject var vm: ViewModel
        @EnvironmentObject var audioManager: GlobalAudioManager
        @State private var coverImage: Image? = nil
        @State private var showFullDescription = false
        
        var body: some View {
            HStack(alignment: .top, spacing: 60) {
                // Left: XL cover art
                VStack {
                    if let coverImage {
                        coverImage
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 600, maxHeight: 600)
                            .cornerRadius(20)
                            .focusable()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 600, height: 600)
                            .cornerRadius(20)
                            .task { await loadCover() }
                    }
                    Spacer()
                }
                
                // Right: metadata and actions
                VStack(alignment: .leading, spacing: 20) {
                    // Title (large)
                    Text(item.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                    // Series (smaller than title)
                    if let seriesName = item.seriesName, !seriesName.isEmpty {
                        Text(seriesName)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    // Author (smaller than series)
                    if let author = item.authorNameLF ?? item.authorName {
                        Text(author)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Description with "More" button (2 lines max)
                    if !item.descriptionText.isEmpty {
                        Button {
                            showFullDescription = true
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.descriptionText)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Text("More")
                                    .font(.callout)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .buttonStyle(.plain)
                        .focusable()
                        .sheet(isPresented: $showFullDescription) {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text(item.title)
                                        .font(.title2)
                                        .bold()
                                    Text(item.descriptionText)
                                        .font(.body)
                                }
                                .padding(40)
                            }
                            .background(Color.black.ignoresSafeArea())
                        }
                    }
                    
                    // Play button (prominent)
                    Button {
                        Task {
                            // Load the item into the audio manager
                            await audioManager.loadItem(item, appVM: vm)
                            // Start playback
                            audioManager.play()
                            // Close this overlay
                            isPresented = false
                        }
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .focusable()
                    
                    // Chapter list
                    if !item.chapters.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Chapters")
                                .font(.headline)
                                .padding(.top, 8)
                            
                            List(Array(item.chapters.enumerated()), id: \.offset) { index, chapter in
                                HStack {
                                    Text("\(index + 1).")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                        .frame(width: 30, alignment: .trailing)
                                    
                                    Text(chapter.title)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Text(durationString(max(0, chapter.end - chapter.start)))
                                        .font(.caption)
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    Task {
                                        // Load the item if not already loaded
                                        if audioManager.currentItem?.id != item.id {
                                            await audioManager.loadItem(item, appVM: vm)
                                        }
                                        // Seek to chapter start
                                        audioManager.seek(to: chapter.start)
                                        // Start playback
                                        audioManager.play()
                                        // Close overlay
                                        isPresented = false
                                    }
                                }
                            }
                            .frame(maxHeight: 400)
                        }
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: 800) // limit width on very wide screens
            }
            .padding(50)
            .overlay(alignment: .topTrailing) {
                Button("Close") { 
                    isPresented = false 
                }
                .buttonStyle(.bordered)
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
        }
        
        private func loadCover() async {
            if let tuple = await vm.loadCover(for: item) {
                coverImage = tuple.0
            }
        }
        
        private func durationString(_ seconds: Double) -> String {
            let total = Int(seconds.rounded())
            let h = total / 3600
            let m = (total % 3600) / 60
            let s = total % 60
            if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
            return String(format: "%d:%02d", m, s)
        }
    }
}
