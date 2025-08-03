//
//  LibraryDetailView.swift
//  SwiftShelf
//
//  Created by Michael Vinci on 8/2/25.
//

import SwiftUI
import AVFoundation
import Combine

struct LibraryItemDetailPopup: View {
    let item: LibraryItem
    let cover: Image?
    var body: some View {
        VStack(spacing: 24) {
            if let cover = cover {
                cover
                    .resizable()
                    .scaledToFit()
                    .frame(height: 220)
                    .cornerRadius(14)
            }
            Text(item.title).font(.title.bold())
            if let author = item.authorNameLF ?? item.authorName {
                Text(author).font(.headline)
            }
            if let series = item.seriesName {
                Text(series).font(.subheadline)
            }
            if let duration = item.duration {
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

    @State private var items: [LibraryItem] = []
    @State private var unfinished: [LibraryItem] = []
    @State private var isLoadingItems = false
    @State private var isLoadingUnfinished = false
    @State private var coverImages: [String: Image] = [:]

    @State private var selectedItem: LibraryItem? = nil
    @State private var showItemPopup = false

    var onRefresh: Int = 0

    private let thumbSize: CGFloat = 225

    private var selectedCover: Image? { selectedItem.flatMap { coverImages[$0.id] } }

    var body: some View {
        VStack(spacing: 40) {

            Divider()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 32) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Items")
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
                                loadCover: { await vm.loadCover(for: $0) },
                                thumbSize: thumbSize,
                                onSelect: { item in
                                    selectedItem = item
                                    showItemPopup = true
                                }
                            )
                            .environmentObject(vm)
                            .frame(height: 350)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Continue Listening")
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
                                loadCover: { await vm.loadCover(for: $0) },
                                thumbSize: thumbSize,
                                onSelect: { item in
                                    selectedItem = item
                                    showItemPopup = true
                                }
                            )
                            .environmentObject(vm)
                            .frame(height: 350)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Spacer()
        }
        .navigationTitle("")
        .sheet(isPresented: $showItemPopup) {
            if let selectedItem = selectedItem {
                MediaPlayerView(item: selectedItem)
            }
        }
        .onAppear {
            Task { await loadItems() }
        }
        .onChange(of: onRefresh) { _, _ in
            Task { await loadItems() }
        }
    }

    private func loadItems() async {
        if isLoadingItems || isLoadingUnfinished { return }

        let lib = library

        isLoadingItems = true
        defer { isLoadingItems = false }
        if let fetched = await vm.fetchItems(forLibrary: lib.id, limit: 10, sortBy: "addedAt", descBy: "1") {
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

        isLoadingUnfinished = true
        if let fetchedUnfinished = await vm.fetchItems(forLibrary: lib.id, limit: 10, sortBy: "updatedAt", descBy: "1") {
            unfinished = fetchedUnfinished
            await withTaskGroup(of: (String, Image?).self) { group in
                for item in fetchedUnfinished {
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
            unfinished = []
        }
        isLoadingUnfinished = false
    }

    struct LibraryCarouselView: View {
        @EnvironmentObject var vm: ViewModel
        let items: [LibraryItem]
        @Binding var coverImages: [String: Image]
        var loadCover: (LibraryItem) async -> Image?
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
                            loadCover: {
                                if let image = await loadCover(item) {
                                    coverImages[item.id] = image
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
        var cover: Image?
        let loadCover: () async -> Void
        let thumbSize: CGFloat
        let onSelect: () -> Void

        @State private var isFocused: Bool = false

        var body: some View {
            Button {
                onSelect()
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

                    if let dur = item.duration {
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
}

