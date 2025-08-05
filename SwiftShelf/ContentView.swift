//
//  ContentView.swift
//  SwiftShelf
//
//  Created by Michael Vinci on 8/2/25.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("recentSearches") private var recentSearchesRaw: String = "[]"
    @AppStorage("host") private var persistedHost: String = ""
    @AppStorage("apiKey") private var persistedApiKey: String = "abc123"

    private var recentSearches: [String] {
        (try? JSONDecoder().decode([String].self, from: Data(recentSearchesRaw.utf8))) ?? []
    }
    private func setRecentSearches(_ newValue: [String]) {
        if let data = try? JSONEncoder().encode(newValue), let str = String(data: data, encoding: .utf8) {
            recentSearchesRaw = str
        }
    }

    @EnvironmentObject var vm: ViewModel
    @EnvironmentObject var config: LibraryConfig
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTabIndex = 0
    @State private var showSelection = false
    @State private var dummyRefreshTrigger = 0

    @State private var searchText = ""
    @State private var searchSections: [(title: String, items: [SearchDisplayItem])] = []
    @State private var isSearching = false

    @State private var selectedSearchItemID: String? = nil
    @State private var coverCache: [String: Image] = [:]

    @FocusState private var searchFieldIsFocused: Bool
    @FocusState private var focusedResultID: String?
    
    @State private var selectedMediaItem: LibraryItem? = nil

    var body: some View {
        Group {
            if config.selected.isEmpty {
                connectionSelectionPane
            } else {
                TabView(selection: $selectedTabIndex) {
                    searchTabView
                        .onAppear {
                            searchFieldIsFocused = true
                        }
                        .tabItem {
                            Image(systemName: "magnifyingglass")
                        }
                        .tag(-1)

                    ForEach(Array(config.selected.enumerated()), id: \.element.id) { idx, lib in
                        LibraryDetailView(library: lib)
                            .environmentObject(vm)
                            .environmentObject(config)
                            .tabItem {
                                Text(lib.name)
                            }
                            .tag(idx)
                    }

                    SettingsView()
                        .environmentObject(vm)
                        .environmentObject(config)
                        .tabItem {
                            Image(systemName: "gear")
                        }
                        .tag(config.selected.count)
                }
            }
        }
        .sheet(isPresented: $showSelection) {
            LibrarySelectionView(isPresented: $showSelection)
                .environmentObject(vm)
                .environmentObject(config)
        }
        .sheet(item: $selectedMediaItem) { item in
            MediaPlayerView(item: item)
                .environmentObject(vm)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                Task {
                    await vm.connect()
                    if !searchText.isEmpty {
                        await searchBooks()
                    }
                }
            }
        }
    }

    private var searchTabView: some View {
        VStack(spacing: 16) {
            TextField("Search", text: $searchText, onCommit: {
                Task {
                    await searchBooks()
                    addRecentSearch(searchText)
                }
            })
            .focused($searchFieldIsFocused)
            .onSubmit {
                if let firstSection = searchSections.first,
                   let firstItem = firstSection.items.first {
                    selectedSearchItemID = firstItem.id
                    focusedResultID = firstItem.id
                }
                addRecentSearch(searchText)
            }
            .submitLabel(.search)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.init(red: 0.15, green: 0.15, blue: 0.18, alpha: 1)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.6), lineWidth: 2)
            )
            .padding()

            if !recentSearches.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recentSearches, id: \.self) { term in
                            Button(term) {
                                searchText = term
                                addRecentSearch(term)
                                Task { await searchBooks() }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }

            if isSearching {
                ProgressView()
                    .padding()
            } else {
                if searchSections.isEmpty {
                    VStack {
                        Text("No results")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(searchSections, id: \.title) { section in
                            Section(header: Text(section.title)) {
                                ForEach(section.items) { item in
                                    if section.title == "Books", let libItem = item.libraryItem {
                                        Button {
                                            selectedMediaItem = libItem
                                        } label: {
                                            HStack(spacing: 12) {
                                                if let cachedImage = coverCache[item.id] {
                                                    cachedImage
                                                        .resizable()
                                                        .frame(width: 48, height: 48)
                                                        .cornerRadius(6)
                                                } else {
                                                    Rectangle()
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(width: 48, height: 48)
                                                        .cornerRadius(6)
                                                        .task {
                                                            await loadCover(for: libItem)
                                                        }
                                                }
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(item.title)
                                                        .font(.headline)
                                                    if let subtitle = item.subtitle {
                                                        Text(subtitle)
                                                            .font(.subheadline)
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                                Spacer()
                                            }
                                            .padding(.vertical, 4)
                                            .contentShape(Rectangle())
                                            .background(selectedSearchItemID == item.id ? Color.accentColor.opacity(0.2) : Color.clear)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .focused($focusedResultID, equals: item.id)
                                        .onAppear {
                                            if selectedSearchItemID == nil && focusedResultID == nil {
                                                selectedSearchItemID = item.id
                                            }
                                        }
                                        .accessibilityRespondsToUserInteraction(true)
                                    } else {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.title)
                                                .font(.headline)
                                            if let subtitle = item.subtitle {
                                                Text(subtitle)
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                        .contentShape(Rectangle())
                                        .background(selectedSearchItemID == item.id ? Color.accentColor.opacity(0.2) : Color.clear)
                                        .focused($focusedResultID, equals: item.id)
                                        .onAppear {
                                            if selectedSearchItemID == nil && focusedResultID == nil {
                                                selectedSearchItemID = item.id
                                            }
                                        }
                                        .onTapGesture {
                                            selectedSearchItemID = item.id
                                            focusedResultID = item.id
                                        }
                                        .onSubmit {
                                        }
                                        .submitLabel(.done)
                                        .accessibilityRespondsToUserInteraction(true)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.grouped)
                }
            }
        }
    }

    private var connectionSelectionPane: some View {
        VStack(spacing: 16) {
            Text("SwiftShelf").font(.title2)
            VStack(spacing: 8) {
                TextField("Host", text: Binding(
                    get: { persistedHost },
                    set: { value in
                        persistedHost = value
                        vm.host = value
                    }
                ))
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.init(red: 0.15, green: 0.15, blue: 0.18, alpha: 1)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.6), lineWidth: 2)
                )
                .autocapitalization(.none)
                .disableAutocorrection(true)

                SecureField("API Key", text: Binding(
                    get: { persistedApiKey },
                    set: { value in
                        persistedApiKey = value
                        vm.apiKey = value
                    }
                ))
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.init(red: 0.15, green: 0.15, blue: 0.18, alpha: 1)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.6), lineWidth: 2)
                )
            }
            .onAppear {
                if vm.host != persistedHost { vm.host = persistedHost }
                if vm.apiKey != persistedApiKey { vm.apiKey = persistedApiKey }
            }

            Button {
                Task {
                    await vm.connect()
                }
            } label: {
                if vm.isLoadingLibraries {
                    ProgressView()
                } else {
                    Text("Connect").bold()
                }
            }
            .disabled(vm.host.isEmpty || vm.apiKey.isEmpty)

            Button("Select Libraries") {
                showSelection = true
            }
            .disabled(vm.libraries.isEmpty)

            if let err = vm.errorMessage {
                Text(err)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            List(vm.libraries) { lib in
                HStack {
                    Text(lib.name)
                    Spacer()
                    Text(lib.id)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
        }
    }

    private func searchBooks() async {
        guard !config.selected.isEmpty else { return }
        guard let firstLibrary = config.selected.first else { return }
        guard !searchText.isEmpty else {
            searchSections = []
            return
        }

        isSearching = true
        vm.errorMessage = nil

        do {
            let host = vm.host.trimmingCharacters(in: .whitespacesAndNewlines)
            let libraryID = firstLibrary.id
            let query = searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let urlString = "\(host)/audiobookshelf/api/libraries/\(libraryID)/search?q=\(query)&limit=5"

            guard let url = URL(string: urlString) else {
                vm.errorMessage = "Invalid search URL."
                searchSections = []
                isSearching = false
                return
            }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(vm.apiKey)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                vm.errorMessage = "Invalid response."
                searchSections = []
                isSearching = false
                return
            }

            guard httpResponse.statusCode == 200 else {
                vm.errorMessage = "Search request failed."
                searchSections = []
                isSearching = false
                return
            }

            let decoder = JSONDecoder()
            let results = try decoder.decode(SearchResponse.self, from: data)

            var sections: [(title: String, items: [SearchDisplayItem])] = []

            if let books = results.book, !books.isEmpty {
                let bookItems = books.compactMap { bookResult -> SearchDisplayItem? in
                    let item = bookResult.libraryItem
                    return SearchDisplayItem(id: item.id, title: item.title, subtitle: item.authorNameLF ?? item.authorName, libraryItem: item)
                }
                if !bookItems.isEmpty {
                    sections.append((title: "Books", items: bookItems))
                }
            }

            if let narrators = results.narrators, !narrators.isEmpty {
                let narratorItems = narrators.map { narrator -> SearchDisplayItem in
                    let subtitle = narrator.numBooks != nil ? "\(narrator.numBooks!) books" : nil
                    return SearchDisplayItem(id: narrator.name, title: narrator.name, subtitle: subtitle, libraryItem: nil)
                }
                if !narratorItems.isEmpty {
                    sections.append((title: "Narrators", items: narratorItems))
                }
            }

            if let seriesArr = results.series, !seriesArr.isEmpty {
                let seriesItems = seriesArr.map { seriesResult in
                    SearchDisplayItem(id: seriesResult.series.id, title: seriesResult.series.name, subtitle: nil, libraryItem: nil)
                }
                if !seriesItems.isEmpty {
                    sections.append((title: "Series", items: seriesItems))
                }
            }

            searchSections = sections

        } catch {
            vm.errorMessage = "Error searching: \(error.localizedDescription)"
            searchSections = []
        }

        isSearching = false
    }

    private func loadCover(for item: LibraryItem) async {
        if coverCache[item.id] != nil { return }
        if let imageTuple = await vm.loadCover(for: item) {
            coverCache[item.id] = imageTuple.0
        }
    }

    private func addRecentSearch(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var recents = recentSearches.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        recents.insert(trimmed, at: 0)
        setRecentSearches(Array(recents.prefix(8)))
    }

    // MARK: - Models for search response and display

    struct SearchResponse: Decodable {
        let book: [BookResult]?
        let narrators: [NarratorResult]?
        let tags: [TagResult]?
        let genres: [GenreResult]?
        let series: [SeriesResult]?
    }

    struct BookResult: Decodable {
        let libraryItem: LibraryItem
    }

    struct NarratorResult: Decodable {
        let name: String
        let numBooks: Int?
    }

    struct SeriesResult: Decodable {
        let series: Series
        struct Series: Decodable {
            let id: String
            let name: String
        }
    }

    struct TagResult: Decodable {
        let id: String
        let name: String
    }

    struct GenreResult: Decodable {
        let id: String
        let name: String
    }

    struct SearchDisplayItem: Identifiable {
        let id: String
        let title: String
        let subtitle: String?
        let libraryItem: LibraryItem?
    }
}

