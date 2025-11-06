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
    private let pageHeight: CGFloat = 900  // Available height for text
    private let lineHeight: CGFloat = 26   // Font size 18 + line spacing 4 + some padding
    private let charsPerLine: Int = 80     // Approximate characters per line

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
        .task {
            await loadEbook()
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
                                Button {
                                    navigateToSpineItem(index)
                                    showChapterMenu = false
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Section \(index + 1)")
                                                .font(.headline)
                                                .foregroundColor(sepiaText)

                                            let plainText = HTMLParser.htmlToPlainText(chapter.htmlContent)
                                            let preview = plainText.prefix(60).replacingOccurrences(of: "\n", with: " ")
                                            Text(preview + "...")
                                                .font(.caption)
                                                .foregroundColor(sepiaText.opacity(0.6))
                                                .lineLimit(2)
                                        }
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color.clear)
                                }
                                .buttonStyle(.plain)

                                Divider()
                                    .background(sepiaText.opacity(0.1))
                            }
                        } else {
                            // Use actual TOC chapters
                            ForEach(Array(tocChapters.enumerated()), id: \.offset) { index, tocChapter in
                                Button {
                                    navigateToTOCChapter(tocChapter)
                                    showChapterMenu = false
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(tocChapter.title)
                                                .font(.headline)
                                                .foregroundColor(sepiaText)

                                            if let pageNum = spineToPageMap[tocChapter.href] {
                                                Text("Page \(pageNum + 1)")
                                                    .font(.caption)
                                                    .foregroundColor(sepiaText.opacity(0.5))
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color.clear)
                                }
                                .buttonStyle(.plain)

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
                .onTapGesture {
                    showChapterMenu = false
                }

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
                // Page content
                Text(paginatedPages[pageNumber])
                    .font(.system(size: 18))
                    .foregroundColor(sepiaText)
                    .lineSpacing(4)
                    .padding(.horizontal, 30)
                    .padding(.top, 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

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
}
