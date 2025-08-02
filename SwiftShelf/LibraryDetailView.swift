//
//  LibraryDetailView.swift
//  SwiftShelf
//
//  Created by Michael Vinci on 8/2/25.
//

import SwiftUI

struct LibraryDetailView: View {
    @EnvironmentObject var vm: ViewModel
    @EnvironmentObject var config: LibraryConfig

    @State private var currentIndex: Int = 0
    @State private var items: [LibraryItem] = []
    @State private var isLoadingItems = false
    @State private var coverImages: [String: Image] = [:]
    @FocusState private var focusedItem: String?

    var selectedLibraries: [SelectedLibrary] {
        config.selected
    }

    var body: some View {
        VStack(spacing: 16) {
            if !selectedLibraries.isEmpty {HStack {
                Button {
                    currentIndex = (currentIndex - 1 + selectedLibraries.count) % selectedLibraries.count
                    Task { await loadItems() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2.weight(.bold))
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(Color(red: 0.25, green: 0.25, blue: 0.28).opacity(0.6))
                        )
                }
                .buttonStyle(.plain)
                .focusable(true)

                Spacer()

                Text(selectedLibraries[currentIndex].name)
                    .font(.title2)
                    .bold()
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 400)

                Spacer()

                Button {
                    currentIndex = (currentIndex + 1) % selectedLibraries.count
                    Task { await loadItems() }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2.weight(.bold))
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(Color(red: 0.25, green: 0.25, blue: 0.28).opacity(0.6))
                        )
                }
                .buttonStyle(.plain)
                .focusable(true)
            }
            .padding(.horizontal)
            }

            Divider()
            
            let thumbSize: CGFloat = 90

            if isLoadingItems {
                ProgressView("Loading items...")
            } else {
                LibraryCarouselView(items: items,
                                    coverImages: $coverImages,
                                    loadCover: { await vm.loadCover(for: $0) })
                    .environmentObject(vm)
                    .frame(height: 400)
            }

            Spacer()
        }
        .navigationTitle("Audiobookshelf")
        .onAppear {
            Task { await loadItems() }
        }
    }
    
    func makeCoverURL(from coverPath: String) -> URL? {
        guard let base = URL(string: vm.host) else { return nil }
        let trimmed = coverPath.hasPrefix("/") ? String(coverPath.dropFirst()) : coverPath
        return base.appendingPathComponent(trimmed)
    }

    func formatDuration(_ seconds: Double) -> String {
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
    
    private func loadItems() async {
        guard !selectedLibraries.isEmpty else { return }
        isLoadingItems = true
        let lib = selectedLibraries[currentIndex]
        if let fetched = await vm.fetchRecentItems(forLibrary: lib.id, limit: 10) {
            items = fetched
            await withTaskGroup(of: (String, Image?).self) { group in
                for item in fetched {
                    group.addTask {
                        let image = await vm.loadCover(for: item)
                        return (item.id, image)
                    }
                }
                for await (id, image) in group {
                    if let img = image {
                        coverImages[id] = img
                    }
                }
            }
        } else {
            items = []
        }
        isLoadingItems = false
    }
    
    struct LibraryCarouselView: View {
        @EnvironmentObject var vm: ViewModel
        let items: [LibraryItem]
        @Binding var coverImages: [String: Image]
        var loadCover: (LibraryItem) async -> Image?

        private let thumbSize: CGFloat = 225
        private let spacing: CGFloat = 24

        var body: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    ForEach(items) { item in
                        CarouselItemView(
                            item: item,
                            cover: coverImages[item.id],
                            loadCover: {
                                if let image = await loadCover(item) {
                                    coverImages[item.id] = image
                                }
                            },
                            thumbSize: thumbSize,
                            onSelect: { selected in
                                print("Selected item:", selected.title)
                            }
                        )
                        .frame(width: thumbSize + 75)
                    }
                }
                .padding(.horizontal, 40)
            }      }
    }

    struct CarouselItemView: View {
        let item: LibraryItem
        var cover: Image?
        let loadCover: () async -> Void
        let thumbSize: CGFloat
        let onSelect: (LibraryItem) -> Void

        @State private var isFocused: Bool = false

        var body: some View {
            Button {
                onSelect(item)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    ZStack {
                        if let img = cover {
                            img
                                .resizable()
                                .scaledToFill()
                                .frame(width: thumbSize, height: thumbSize)
                                .clipped()
                                .cornerRadius(8)
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
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isFocused ? Color.white.opacity(0.8) : Color.clear, lineWidth: 3)
                    )
                    .scaleEffect(isFocused ? 1.08 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: isFocused)

                    Text(item.title)
                        .font(.system(size: 20, weight: .semibold))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                        .frame(maxWidth: thumbSize, alignment: .leading)
                    if let author = item.authorNameLF {
                        Text(author)
                            .lineLimit(1)
                            .foregroundColor(.secondary)
                            .font(.system(size: 20, weight: .semibold))
                            .frame(maxWidth: thumbSize, alignment: .leading)
                    }
                    if let dur = item.duration {
                        Text("\(formatDuration(dur))")
                            .lineLimit(1)
                            .foregroundColor(.gray)
                            .font(.system(size: 20, weight: .semibold))
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
}
