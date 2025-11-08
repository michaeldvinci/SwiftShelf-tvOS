//
//  EPUBReaderView.swift
//  SwiftShelf
//
//  Created by Claude on 11/6/25.
//

import SwiftUI

struct EPUBReaderView: View {
    let item: LibraryItem
    let ebookFile: LibraryItem.LibraryFile
    @Binding var showChapterMenu: Bool
    @EnvironmentObject var vm: ViewModel

    @AppStorage private var currentPage: Int
    @State private var chapters: [EPUBParser.EPUBContent.Chapter] = []
    @State private var paginatedPages: [String] = []
    @State private var spineToPageMap: [String: Int] = [:]  // Maps spine href to starting page index
    @State private var tocChapters: [EPUBParser.EPUBContent.TOCChapter] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var hasLoadedOnce = false  // Track if we've already loaded this book

    // Audio sync state
    @State private var audioSyncEnabled = false
    @State private var audioSyncTimer: Timer?
    @State private var chapterMapping: [Int: Int] = [:]  // Maps audio chapter index → EPUB TOC chapter index

    init(item: LibraryItem, ebookFile: LibraryItem.LibraryFile, showChapterMenu: Binding<Bool>) {
        self.item = item
        self.ebookFile = ebookFile
        self._showChapterMenu = showChapterMenu
        // Use item ID as the key for storing current page
        self._currentPage = AppStorage(wrappedValue: 0, "epub_page_\(item.id)")
    }

    @FocusState private var leftButtonFocused: Bool
    @FocusState private var rightButtonFocused: Bool
    @FocusState private var chaptersButtonFocused: Bool

    // Sepia color scheme
    private let sepiaBackground = Color(red: 0.95, green: 0.91, blue: 0.82)
    private let sepiaText = Color(red: 0.27, green: 0.22, blue: 0.17)

    // Page dimensions for pagination
    private let pageHeight: CGFloat = 800  // Available height for text (reduced to account for page number)
    private let lineHeight: CGFloat = 30   // Font size 18 + line spacing 4 + extra padding (more conservative)
    private let charsPerLine: Int = 70     // Approximate characters per line (more conservative)

    var body: some View {
        ZStack {
            sepiaBackground.ignoresSafeArea()

            if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(2)
                        .tint(sepiaText)
                    Text("Loading ebook...")
                        .font(.title3)
                        .foregroundColor(sepiaText)
                }
            } else if let error = errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.red.opacity(0.7))
                    Text("Error Loading Ebook")
                        .font(.title)
                        .foregroundColor(sepiaText)
                    Text(error)
                        .font(.body)
                        .foregroundColor(sepiaText.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 100)
                }
            } else {
                ZStack(alignment: .bottom) {
                    // Reader content with navigation buttons
                    readerView

                    // Chapter menu overlay (aligned to bottom, above the controls)
                    if showChapterMenu {
                        chapterMenuView
                            .padding(.bottom, 90) // Position above the button bar
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .epubReaderSyncRequest)) { notification in
            guard let id = notification.object as? String, id == String(describing: item.id) else { return }
            syncWithAudioPosition()
        }
        .task {
            await loadEbook()
        }
        .onDisappear {
            stopAudioSync()
        }
        .onExitCommand {
            // Handle back button - close chapter menu if open
            if showChapterMenu {
                showChapterMenu = false
            }
        }
    }

    private var readerView: some View {
        VStack(spacing: 0) {
            // Two-panel layout
            HStack(spacing: 0) {
                // Left page (even page numbers)
                pagePanel(pageNumber: currentPage - 1)
                    .frame(maxWidth: .infinity)

                // Divider
                Rectangle()
                    .fill(sepiaText.opacity(0.2))
                    .frame(width: 2)

                // Right page (odd page numbers)
                pagePanel(pageNumber: currentPage)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 40)
            .padding(.top, 20)

            // Navigation buttons at bottom
            HStack(spacing: 0) {
                // Left arrow button
                Button {
                    previousPage()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 30))
                        .foregroundColor(leftButtonFocused ? sepiaBackground : sepiaText.opacity(0.5))
                        .frame(width: 60, height: 60)
                        .background(leftButtonFocused ? sepiaText : Color.clear)
                }
                .buttonStyle(.plain)
                .focused($leftButtonFocused)
                .disabled(currentPage <= 1)
                .opacity(currentPage <= 1 ? 0.3 : 1.0)

                Spacer()

                // Audio sync toggle button
                Button {
                    audioSyncEnabled.toggle()
                    if audioSyncEnabled {
                        startAudioSync()
                    } else {
                        stopAudioSync()
                    }
                } label: {
                    Image(systemName: audioSyncEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 20))
                        .foregroundColor(audioSyncEnabled ? .green : sepiaText.opacity(0.5))
                        .frame(width: 50, height: 50)
                }
                .buttonStyle(.plain)

                Spacer()

                // Chapters button (centered)
                Button {
                    showChapterMenu = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet")
                        Text("Chapters")
                    }
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(chaptersButtonFocused ? sepiaBackground : sepiaText.opacity(0.7))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(chaptersButtonFocused ? sepiaText : sepiaText.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .focused($chaptersButtonFocused)

                Spacer()

                // Right arrow button
                Button {
                    nextPage()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 30))
                        .foregroundColor(rightButtonFocused ? sepiaBackground : sepiaText.opacity(0.5))
                        .frame(width: 60, height: 60)
                        .background(rightButtonFocused ? sepiaText : Color.clear)
                }
                .buttonStyle(.plain)
                .focused($rightButtonFocused)
                .disabled(currentPage >= totalPages - 1)
                .opacity(currentPage >= totalPages - 1 ? 0.3 : 1.0)
            }
            .padding(.vertical, 15)
            .padding(.horizontal, 40)
        }
    }

    private var chapterMenuView: some View {
        let menuContent = VStack(alignment: .leading, spacing: 0) {
                // Menu header
                HStack {
                    Text("Chapters")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(sepiaText)

                    Spacer()

                    Button {
                        showChapterMenu = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(sepiaText)
                            .padding(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(sepiaBackground.opacity(0.95))

                Divider()
                    .background(sepiaText.opacity(0.3))

                // Chapter list from TOC
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if tocChapters.isEmpty {
                            // Fallback to sections if no TOC
                            ForEach(Array(chapters.enumerated()), id: \.offset) { index, chapter in
                                ChapterRow(
                                    title: "Section \(index + 1)",
                                    subtitle: {
                                        let plainText = HTMLParser.htmlToPlainText(chapter.htmlContent)
                                        let preview = plainText.prefix(60).replacingOccurrences(of: "\n", with: " ")
                                        return preview + "..."
                                    }(),
                                    sepiaText: sepiaText,
                                    onTap: {
                                        navigateToSpineItem(index)
                                        showChapterMenu = false
                                    }
                                )

                                Divider()
                                    .background(sepiaText.opacity(0.1))
                            }
                        } else {
                            // Use actual TOC chapters
                            ForEach(Array(tocChapters.enumerated()), id: \.offset) { index, tocChapter in
                                ChapterRow(
                                    title: tocChapter.title,
                                    subtitle: spineToPageMap[tocChapter.href].map { "Page \($0 + 1)" },
                                    sepiaText: sepiaText,
                                    onTap: {
                                        navigateToTOCChapter(tocChapter)
                                        showChapterMenu = false
                                    }
                                )

                                Divider()
                                    .background(sepiaText.opacity(0.1))
                            }
                        }
                    }
                }
        }
        .frame(width: 600)
        .frame(maxHeight: 600)
        .background(sepiaBackground.opacity(0.98))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.3), radius: 20)

        return ZStack {
            // Darkened background overlay
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)

            // Centered menu
            menuContent
        }
    }

    @ViewBuilder
    private func pagePanel(pageNumber: Int) -> some View {
        if pageNumber < 0 {
            // Cover/title page
            VStack(spacing: 20) {
                Spacer()
                Text(item.title)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(sepiaText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                if let author = item.authorName {
                    Text(author)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(sepiaText.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                Spacer()
            }
        } else if pageNumber < totalPages {
            VStack(spacing: 0) {
                // Page content with fixed height to prevent overflow
                Text(paginatedPages[pageNumber])
                    .font(.system(size: 18))
                    .foregroundColor(sepiaText)
                    .lineSpacing(4)
                    .padding(.horizontal, 30)
                    .padding(.top, 20)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .frame(height: pageHeight)  // Fixed height matching pagination calculation
                    .clipped()  // Clip any overflow

                // Page number at bottom
                Text("\(pageNumber + 1)")
                    .font(.caption)
                    .foregroundColor(sepiaText.opacity(0.5))
                    .padding(.bottom, 20)
            }
        } else {
            // Empty page beyond content
            Color.clear
        }
    }

    private var totalPages: Int {
        return paginatedPages.count
    }

    private func paginateContent(spineItems: [EPUBParser.EPUBContent.SpineItem]) {
        var pages: [String] = []
        var spineMap: [String: Int] = [:]
        let linesPerPage = Int(pageHeight / lineHeight)

        var currentPageLines: [String] = []
        var currentLineCount = 0

        for (spineIndex, spineItem) in spineItems.enumerated() {
            // If there's content from previous spine item, finish that page first
            if !currentPageLines.isEmpty {
                pages.append(currentPageLines.joined(separator: "\n"))
                currentPageLines = []
                currentLineCount = 0
            }

            // Mark the start page of this spine item
            spineMap[spineItem.href] = pages.count
            print("📄 Spine item \(spineIndex): \(spineItem.href) starts at page \(pages.count)")

            let plainText = HTMLParser.htmlToPlainText(spineItem.htmlContent)
            let paragraphs = plainText.components(separatedBy: "\n\n")

            for paragraph in paragraphs {
                if paragraph.isEmpty { continue }

                // Split paragraph into lines based on character width
                let words = paragraph.components(separatedBy: " ")
                var currentLine = ""

                for word in words {
                    let testLine = currentLine.isEmpty ? word : "\(currentLine) \(word)"

                    if testLine.count > charsPerLine {
                        // Line would be too long, commit current line
                        if !currentLine.isEmpty {
                            currentPageLines.append(currentLine)
                            currentLineCount += 1

                            // Check if page is full
                            if currentLineCount >= linesPerPage {
                                pages.append(currentPageLines.joined(separator: "\n"))
                                currentPageLines = []
                                currentLineCount = 0
                            }
                        }
                        currentLine = word
                    } else {
                        currentLine = testLine
                    }
                }

                // Add remaining line from paragraph
                if !currentLine.isEmpty {
                    currentPageLines.append(currentLine)
                    currentLineCount += 1

                    if currentLineCount >= linesPerPage {
                        pages.append(currentPageLines.joined(separator: "\n"))
                        currentPageLines = []
                        currentLineCount = 0
                    }
                }

                // Add paragraph break (blank line)
                currentPageLines.append("")
                currentLineCount += 1

                if currentLineCount >= linesPerPage {
                    pages.append(currentPageLines.joined(separator: "\n"))
                    currentPageLines = []
                    currentLineCount = 0
                }
            }
        }

        // Add any remaining content as final page
        if !currentPageLines.isEmpty {
            pages.append(currentPageLines.joined(separator: "\n"))
        }

        paginatedPages = pages
        spineToPageMap = spineMap

        print("📚 Pagination complete: \(pages.count) pages from \(spineItems.count) spine items")
    }

    private func navigateToTOCChapter(_ tocChapter: EPUBParser.EPUBContent.TOCChapter) {
        guard let startPage = spineToPageMap[tocChapter.href] else {
            print("⚠️ Could not find page for chapter: \(tocChapter.title) (\(tocChapter.href))")
            return
        }

        // Navigate to the start of the chapter
        // For 2-panel view: currentPage represents right panel, currentPage-1 is left panel
        // So we want startPage to appear on left panel (currentPage-1), thus currentPage = startPage+1
        currentPage = startPage + 1

        print("📖 Navigating to chapter \"\(tocChapter.title)\"")
        print("   Href: \(tocChapter.href)")
        print("   Page: \(startPage + 1)")
    }

    private func navigateToSpineItem(_ spineIndex: Int) {
        guard spineIndex >= 0 && spineIndex < chapters.count else {
            print("⚠️ Invalid spine index: \(spineIndex)")
            return
        }

        // Find the first page that corresponds to this spine item
        // Since we don't have href for old chapters array, just estimate
        let pagesPerSpine = paginatedPages.count / chapters.count
        let startPage = spineIndex * pagesPerSpine

        currentPage = startPage + 1
        print("📖 Navigating to spine item \(spineIndex + 1), estimated page: \(startPage + 1)")
    }

    private func loadEbook() async {
        do {
            // Construct ebook download URL
            let ebookUrl = "\(vm.host)/api/items/\(item.id)/ebook/\(ebookFile.ino)"
            guard let url = URL(string: ebookUrl) else {
                errorMessage = "Invalid ebook URL"
                isLoading = false
                return
            }

            // Download ebook
            var request = URLRequest(url: url)
            request.setValue("Bearer \(vm.apiKey)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                errorMessage = "Failed to download ebook (status: \((response as? HTTPURLResponse)?.statusCode ?? 0))"
                isLoading = false
                return
            }

            // Parse EPUB
            let epubContent = try EPUBParser.parse(data: data)
            chapters = epubContent.chapters
            tocChapters = epubContent.tocChapters

            print("📚 Found \(tocChapters.count) TOC chapters")

            // Paginate content to fit screen height
            paginateContent(spineItems: epubContent.spineItems)

            // Only reset to page 0 if this is the first time loading this book
            if !hasLoadedOnce && currentPage == 0 {
                currentPage = 0
            }
            hasLoadedOnce = true

            print("📖 Restored to page \(currentPage)")

            // Build chapter mapping for audio sync
            buildChapterMapping()

            isLoading = false

        } catch {
            errorMessage = "Error loading ebook: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func previousPage() {
        guard currentPage > 1 else { return }
        currentPage -= 2  // Move back 2 pages (one spread)
    }

    private func nextPage() {
        guard currentPage < totalPages - 1 else { return }
        currentPage += 2  // Move forward 2 pages (one spread)
    }

    // MARK: - Audio Sync

    /// Build mapping between audio chapters and EPUB chapters by matching titles
    private func buildChapterMapping() {
        guard !item.chapters.isEmpty, !tocChapters.isEmpty else {
            print("[EPUBReader] ⚠️ Cannot build chapter mapping: audio chapters=\(item.chapters.count), EPUB chapters=\(tocChapters.count)")
            return
        }

        var mapping: [Int: Int] = [:]

        for (audioIdx, audioChapter) in item.chapters.enumerated() {
            // Try to find matching EPUB chapter by title similarity
            let audioTitle = audioChapter.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            if let epubIdx = tocChapters.firstIndex(where: { tocChapter in
                let epubTitle = tocChapter.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                return epubTitle == audioTitle || epubTitle.contains(audioTitle) || audioTitle.contains(epubTitle)
            }) {
                mapping[audioIdx] = epubIdx
                print("[EPUBReader] 📖 Mapped audio chapter \(audioIdx) '\(audioChapter.title)' → EPUB chapter \(epubIdx) '\(tocChapters[epubIdx].title)'")
            }
        }

        chapterMapping = mapping
        print("[EPUBReader] ✅ Built chapter mapping: \(mapping.count)/\(item.chapters.count) chapters matched")
    }

    /// Calculate EPUB page based on current audio playback position
    private func calculatePageFromAudioPosition(audioPosition: Double, audioDuration: Double) -> Int? {
        guard !item.chapters.isEmpty else { return nil }

        // Find which audio chapter we're in
        guard let currentAudioChapter = item.chapters.first(where: { chapter in
            audioPosition >= chapter.start && audioPosition < chapter.end
        }) else {
            return nil
        }

        guard let audioChapterIndex = item.chapters.firstIndex(where: { $0.id == currentAudioChapter.id }) else {
            return nil
        }

        // Get mapped EPUB chapter
        guard let epubChapterIndex = chapterMapping[audioChapterIndex] else {
            print("[EPUBReader] ⚠️ No EPUB chapter mapped for audio chapter \(audioChapterIndex)")
            return nil
        }

        guard epubChapterIndex < tocChapters.count else { return nil }

        let epubChapter = tocChapters[epubChapterIndex]

        // Get start page of this EPUB chapter
        guard let chapterStartPage = spineToPageMap[epubChapter.href] else {
            print("[EPUBReader] ⚠️ No page found for EPUB chapter \(epubChapterIndex) href=\(epubChapter.href)")
            return nil
        }

        // Calculate progress within current audio chapter (0.0 to 1.0)
        let chapterDuration = currentAudioChapter.end - currentAudioChapter.start
        let positionInChapter = audioPosition - currentAudioChapter.start
        let chapterProgress = chapterDuration > 0 ? positionInChapter / chapterDuration : 0.0

        // Estimate pages in this EPUB chapter (distance to next chapter or end of book)
        let chapterEndPage: Int
        if epubChapterIndex + 1 < tocChapters.count, let nextChapterPage = spineToPageMap[tocChapters[epubChapterIndex + 1].href] {
            chapterEndPage = nextChapterPage
        } else {
            chapterEndPage = totalPages
        }

        let pagesInChapter = max(1, chapterEndPage - chapterStartPage)

        // Calculate target page based on progress
        let estimatedPage = chapterStartPage + Int(Double(pagesInChapter) * chapterProgress)
        let clampedPage = max(0, min(estimatedPage, totalPages - 1))

        print("[EPUBReader] 🎯 Audio: \(Int(audioPosition))s in '\(currentAudioChapter.title)' (\(Int(chapterProgress * 100))%) → EPUB page \(clampedPage)")

        return clampedPage
    }

    /// Start audio sync timer
    private func startAudioSync() {
        stopAudioSync()

        // Schedule on main run loop; avoid capturing `self` (a struct) weakly
        audioSyncTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            EPUBReaderView.performAudioSync(forItemID: String(describing: item.id))
        }
        RunLoop.main.add(audioSyncTimer!, forMode: .common)

        print("[EPUBReader] 🎵 Audio sync started")
    }

    /// Static helper to perform audio sync without capturing `self` in a Timer closure
    private static func performAudioSync(forItemID itemID: String) {
        let audioManager = GlobalAudioManager.shared
        // Only proceed if playing the same item
        guard audioManager.isPlaying, String(describing: audioManager.currentItem?.id ?? "") == itemID else { return }

        NotificationCenter.default.post(name: .epubReaderSyncRequest, object: itemID)
    }

    /// Stop audio sync timer
    private func stopAudioSync() {
        audioSyncTimer?.invalidate()
        audioSyncTimer = nil
    }

    /// Sync EPUB position with current audio position
    private func syncWithAudioPosition() {
        // Get current audio position from GlobalAudioManager
        let audioManager = GlobalAudioManager.shared

        guard audioManager.isPlaying else { return }
        guard audioManager.currentItem?.id == item.id else { return }  // Only sync if same item

        let audioPosition = audioManager.currentTime
        let audioDuration = audioManager.duration
        let playbackRate = audioManager.rate  // Current playback speed (1.0, 1.5, 2.0, etc.)

        guard audioDuration > 0 else { return }

        // Note: audioPosition is already the actual position in the file
        // Playback rate doesn't affect the position value itself, only how fast it advances
        // So we don't need to adjust audioPosition here - it's already correct

        if let targetPage = calculatePageFromAudioPosition(audioPosition: audioPosition, audioDuration: audioDuration) {
            // Only update if we're not already near this page (avoid jitter)
            let currentDisplayPage = currentPage
            if abs(targetPage - currentDisplayPage) > 2 {  // Allow 2-page tolerance
                currentPage = targetPage
                print("[EPUBReader] 🔄 Page auto-advanced to \(targetPage) (playback rate: \(playbackRate)x)")
            }
        }
    }
}

// MARK: - Chapter Row Component
private struct ChapterRow: View {
    let title: String
    let subtitle: String?
    let sepiaText: Color
    let onTap: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isFocused ? .white : sepiaText)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(isFocused ? .white.opacity(0.7) : sepiaText.opacity(0.5))
                            .lineLimit(2)
                    }
                }
                Spacer()
            }
            .padding()
            .background(isFocused ? sepiaText : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .focused($isFocused)
    }
}

// MARK: - Notifications
private extension Notification.Name {
    static let epubReaderSyncRequest = Notification.Name("EPUBReaderSyncRequest")
}
