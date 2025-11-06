//
//  EPUBParser.swift
//  SwiftShelf
//
//  Created by Claude on 11/6/25.
//

import Foundation
import Compression

class EPUBParser {
    struct EPUBContent {
        let title: String
        let chapters: [Chapter]
        let spineItems: [SpineItem]  // All HTML files in reading order
        let tocChapters: [TOCChapter]  // Actual chapters from TOC

        struct Chapter {
            let title: String?
            let htmlContent: String
        }

        struct SpineItem {
            let htmlContent: String
            let href: String
        }

        struct TOCChapter {
            let title: String
            let href: String  // Which spine item/file this chapter is in
            let fragmentId: String?  // Optional anchor within the file (e.g., #chapter7)
        }
    }

    static func parse(data: Data) throws -> EPUBContent {
        // Create temporary directory for extraction
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Write EPUB data to temp file
        let epubFile = tempDir.appendingPathComponent("book.epub")
        try data.write(to: epubFile)

        // Unzip EPUB using Apple Archive
        try unzipEPUB(epubFile: epubFile, to: tempDir)

        // Parse container.xml to find content.opf location
        let containerPath = tempDir.appendingPathComponent("META-INF/container.xml")
        let contentOpfPath = try parseContainer(at: containerPath, basePath: tempDir)

        // Parse content.opf to get spine order and metadata
        let (title, chapterPaths, ncxPath) = try parseContentOpf(at: contentOpfPath)

        // Read spine content (all HTML files)
        let spineItems = try chapterPaths.map { path -> EPUBContent.SpineItem in
            let fullPath = contentOpfPath.deletingLastPathComponent().appendingPathComponent(path)
            let htmlContent = try String(contentsOf: fullPath, encoding: .utf8)
            return EPUBContent.SpineItem(htmlContent: htmlContent, href: path)
        }

        // Parse TOC from NCX or Nav document
        let tocChapters = try parseTOC(ncxPath: ncxPath, contentOpfPath: contentOpfPath, tempDir: tempDir)

        // For backward compatibility, create chapters from spine items
        let chapters = spineItems.map { EPUBContent.Chapter(title: nil, htmlContent: $0.htmlContent) }

        return EPUBContent(title: title, chapters: chapters, spineItems: spineItems, tocChapters: tocChapters)
    }

    private static func unzipEPUB(epubFile: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        let data = try Data(contentsOf: epubFile)

        // Simple ZIP parser - EPUB files use DEFLATE compression
        // ZIP file format: [local file headers][file data]...[central directory]
        var offset = 0
        let bytes = [UInt8](data)

        while offset < bytes.count - 30 {
            // Check for local file header signature (PK\x03\x04 = 0x04034b50 in little endian)
            guard bytes[offset] == 0x50,
                  bytes[offset + 1] == 0x4B,
                  bytes[offset + 2] == 0x03,
                  bytes[offset + 3] == 0x04 else {
                // Try to find central directory signature instead
                if bytes[offset] == 0x50 && bytes[offset + 1] == 0x4B &&
                   bytes[offset + 2] == 0x01 && bytes[offset + 3] == 0x02 {
                    // Reached central directory, stop
                    break
                }
                offset += 1
                continue
            }

            // Read compression method (offset 8-9)
            let compressionMethod = UInt16(bytes[offset + 8]) | (UInt16(bytes[offset + 9]) << 8)

            // Read compressed size (offset 18-21)
            let compressedSize = UInt32(bytes[offset + 18]) |
                                (UInt32(bytes[offset + 19]) << 8) |
                                (UInt32(bytes[offset + 20]) << 16) |
                                (UInt32(bytes[offset + 21]) << 24)

            // Read uncompressed size (offset 22-25)
            let uncompressedSize = UInt32(bytes[offset + 22]) |
                                  (UInt32(bytes[offset + 23]) << 8) |
                                  (UInt32(bytes[offset + 24]) << 16) |
                                  (UInt32(bytes[offset + 25]) << 24)

            // Read filename length (offset 26-27)
            let filenameLength = UInt16(bytes[offset + 26]) | (UInt16(bytes[offset + 27]) << 8)

            // Read extra field length (offset 28-29)
            let extraFieldLength = UInt16(bytes[offset + 28]) | (UInt16(bytes[offset + 29]) << 8)

            // Extract filename
            let filenameStart = offset + 30
            let filenameEnd = filenameStart + Int(filenameLength)
            guard filenameEnd <= bytes.count else { break }

            let filenameBytes = Array(bytes[filenameStart..<filenameEnd])
            guard let filename = String(bytes: filenameBytes, encoding: .utf8) else {
                offset += 30 + Int(filenameLength) + Int(extraFieldLength) + Int(compressedSize)
                continue
            }

            // Extract file data
            let fileDataStart = filenameEnd + Int(extraFieldLength)
            let fileDataEnd = fileDataStart + Int(compressedSize)
            guard fileDataEnd <= bytes.count else { break }

            let compressedData = Data(bytes[fileDataStart..<fileDataEnd])

            // Create file path
            let fileURL = destination.appendingPathComponent(filename)

            // Skip directories
            if !filename.hasSuffix("/") {
                // Create parent directory
                let dirURL = fileURL.deletingLastPathComponent()
                try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)

                // Decompress and write file
                if compressionMethod == 0 {
                    // Stored (no compression)
                    try compressedData.write(to: fileURL)
                } else if compressionMethod == 8 {
                    // DEFLATE compression
                    let decompressed = try decompressData(compressedData, uncompressedSize: Int(uncompressedSize))
                    try decompressed.write(to: fileURL)
                }
            }

            offset = fileDataEnd
        }
    }

    private static func decompressData(_ data: Data, uncompressedSize: Int) throws -> Data {
        var decompressed = Data(count: uncompressedSize)
        let result = decompressed.withUnsafeMutableBytes { destBuffer in
            data.withUnsafeBytes { sourceBuffer in
                compression_decode_buffer(
                    destBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    uncompressedSize,
                    sourceBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        guard result > 0 else {
            throw NSError(domain: "EPUBParser", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to decompress data"])
        }

        return decompressed
    }

    private static func parseContainer(at url: URL, basePath: URL) throws -> URL {
        let xmlString = try String(contentsOf: url, encoding: .utf8)

        // Simple XML parsing to extract rootfile path
        if let range = xmlString.range(of: "full-path=\"([^\"]+)\"", options: .regularExpression) {
            let fullPath = String(xmlString[range])
                .replacingOccurrences(of: "full-path=\"", with: "")
                .replacingOccurrences(of: "\"", with: "")
            return basePath.appendingPathComponent(fullPath)
        }

        throw NSError(domain: "EPUBParser", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not find content.opf path in container.xml"])
    }

    private static func parseContentOpf(at url: URL) throws -> (String, [String], String?) {
        let xmlString = try String(contentsOf: url, encoding: .utf8)

        // Extract title
        var title = "Unknown"
        if let titleRange = xmlString.range(of: "<dc:title[^>]*>([^<]+)</dc:title>", options: .regularExpression) {
            let titleMatch = String(xmlString[titleRange])
            if let contentRange = titleMatch.range(of: ">([^<]+)<", options: .regularExpression) {
                title = String(titleMatch[contentRange])
                    .replacingOccurrences(of: ">", with: "")
                    .replacingOccurrences(of: "<", with: "")
            }
        }

        // Extract manifest (id -> href mapping)
        var manifest: [String: String] = [:]
        var ncxPath: String?
        let manifestPattern = "<item[^>]+id=\"([^\"]+)\"[^>]+href=\"([^\"]+)\"[^>]*(?:media-type=\"([^\"]+)\")?"
        let manifestRegex = try NSRegularExpression(pattern: manifestPattern)
        let manifestMatches = manifestRegex.matches(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString))

        for match in manifestMatches {
            if match.numberOfRanges >= 3,
               let idRange = Range(match.range(at: 1), in: xmlString),
               let hrefRange = Range(match.range(at: 2), in: xmlString) {
                let id = String(xmlString[idRange])
                let href = String(xmlString[hrefRange])
                manifest[id] = href

                // Look for NCX file (EPUB 2) or Nav document (EPUB 3)
                if let tagRange = Range(match.range, in: xmlString) {
                    let itemTag = String(xmlString[tagRange])
                    if itemTag.contains("application/x-dtbncx+xml") || (itemTag.contains("media-type=\"application/xhtml+xml\"") && itemTag.contains("properties=\"nav\"")) {
                        ncxPath = href
                    }
                }
            }
        }

        // Extract spine order
        var chapterPaths: [String] = []
        let spinePattern = "<itemref[^>]+idref=\"([^\"]+)\""
        let spineRegex = try NSRegularExpression(pattern: spinePattern)
        let spineMatches = spineRegex.matches(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString))

        for match in spineMatches {
            if match.numberOfRanges == 2,
               let idrefRange = Range(match.range(at: 1), in: xmlString) {
                let idref = String(xmlString[idrefRange])
                if let href = manifest[idref] {
                    chapterPaths.append(href)
                }
            }
        }

        return (title, chapterPaths, ncxPath)
    }

    private static func parseTOC(ncxPath: String?, contentOpfPath: URL, tempDir: URL) throws -> [EPUBContent.TOCChapter] {
        guard let ncxPath = ncxPath else {
            print("⚠️ No NCX/Nav file found in EPUB")
            return []
        }

        let ncxFullPath = contentOpfPath.deletingLastPathComponent().appendingPathComponent(ncxPath)
        guard FileManager.default.fileExists(atPath: ncxFullPath.path) else {
            print("⚠️ NCX/Nav file not found at: \(ncxFullPath.path)")
            return []
        }

        let xmlString = try String(contentsOf: ncxFullPath, encoding: .utf8)

        // Try EPUB 2 NCX format first
        if xmlString.contains("<ncx") {
            return try parseNCX(xmlString)
        }
        // Try EPUB 3 Nav format
        else if xmlString.contains("<nav") {
            return try parseNav(xmlString)
        }

        print("⚠️ Unknown TOC format")
        return []
    }

    private static func parseNCX(_ xmlString: String) throws -> [EPUBContent.TOCChapter] {
        var chapters: [EPUBContent.TOCChapter] = []

        // Parse navPoint elements
        let navPointPattern = "<navPoint[^>]*>.*?<text>([^<]+)</text>.*?<content src=\"([^\"]+)\".*?</navPoint>"
        let regex = try NSRegularExpression(pattern: navPointPattern, options: .dotMatchesLineSeparators)
        let matches = regex.matches(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString))

        for match in matches {
            if match.numberOfRanges == 3,
               let titleRange = Range(match.range(at: 1), in: xmlString),
               let srcRange = Range(match.range(at: 2), in: xmlString) {
                let title = String(xmlString[titleRange])
                let src = String(xmlString[srcRange])

                // Split href and fragment (e.g., "chapter1.xhtml#section2")
                let components = src.split(separator: "#", maxSplits: 1)
                let href = String(components[0])
                let fragmentId = components.count > 1 ? String(components[1]) : nil

                chapters.append(EPUBContent.TOCChapter(title: title, href: href, fragmentId: fragmentId))
                print("📚 Found chapter: \"\(title)\" -> \(href)")
            }
        }

        return chapters
    }

    private static func parseNav(_ xmlString: String) throws -> [EPUBContent.TOCChapter] {
        var chapters: [EPUBContent.TOCChapter] = []

        // Parse <a> elements in nav document
        let linkPattern = "<a[^>]+href=\"([^\"]+)\"[^>]*>([^<]+)</a>"
        let regex = try NSRegularExpression(pattern: linkPattern, options: [])
        let matches = regex.matches(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString))

        for match in matches {
            if match.numberOfRanges == 3,
               let hrefRange = Range(match.range(at: 1), in: xmlString),
               let titleRange = Range(match.range(at: 2), in: xmlString) {
                let src = String(xmlString[hrefRange])
                let title = String(xmlString[titleRange])

                // Split href and fragment
                let components = src.split(separator: "#", maxSplits: 1)
                let href = String(components[0])
                let fragmentId = components.count > 1 ? String(components[1]) : nil

                chapters.append(EPUBContent.TOCChapter(title: title, href: href, fragmentId: fragmentId))
                print("📚 Found chapter: \"\(title)\" -> \(href)")
            }
        }

        return chapters
    }
}
