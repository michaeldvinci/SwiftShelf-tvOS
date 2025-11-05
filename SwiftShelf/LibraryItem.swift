//
//  LibraryItem.swift
//  SwiftShelf
//
//  Created by michaeldvinci on 8/2/25.
//

import Foundation

struct LibraryItem: Identifiable, Codable {
    let id: String
    let media: Media?
    let userMediaProgress: UserMediaProgress?

    var title: String {
        media?.metadata.title ?? "Untitled"
    }
    var authorNameLF: String? {
        media?.metadata.authorNameLF
    }
    var authorName: String? {
        media?.metadata.authorName
    }
    var seriesName: String? {
        media?.metadata.seriesName
    }
    var duration: Double? {
        media?.duration
    }
    var audioFiles: [AudioFile] {
        media?.audioFiles ?? []
    }
    var chapters: [Chapter] {
        media?.chapters ?? []
    }
    var tracks: [Track] {
        media?.tracks ?? []
    }
    
    let addedAt: Double?
    let updatedAt: Double?

    struct Media: Codable {
        let duration: Double?
        let coverPath: String?
        let metadata: Metadata
        let audioFiles: [AudioFile]?
        let chapters: [Chapter]?
        let tracks: [Track]?

        struct Metadata: Codable {
            let title: String?
            let authors: [Author]?
            let series: [Series]?
            let authorNameLF: String?
            let authorName: String?
            let seriesName: String?
            let description: String?

            struct Author: Codable {
                let name: String
            }
            struct Series: Codable {
                let name: String
            }
        }
    }
    
    struct AudioFile: Identifiable, Codable {
        let index: Int
        let ino: String
        let filename: String?
        let format: String?
        let duration: Double?
        let bitRate: Int?
        let language: String?
        let codec: String?
        let timeBase: String?
        let channels: Int?
        let channelLayout: String?
        let addedAt: Double?
        let updatedAt: Double?
        let trackNumFromMeta: Int?
        let discNumFromMeta: Int?
        let trackNumFromFilename: Int?
        let discNumFromFilename: Int?
        let manuallyVerified: Bool?
        let invalid: Bool?
        let exclude: Bool?
        let error: String?
        let mimeType: String
        let metadata: AudioFileMetadata?
        
        var id: String { ino }
        
        struct AudioFileMetadata: Codable {
            let filename: String?
            let ext: String?
            let path: String?
            let relPath: String?
            let size: Int64?
            let mtimeMs: Int64?
            let ctimeMs: Int64?
            let birthtimeMs: Int64?
        }
    }
    
    struct Chapter: Identifiable, Codable, Equatable {
        let id: Int
        let start: Double
        let end: Double
        let title: String
    }
    
    struct Track: Identifiable, Codable {
        let index: Int
        let startOffset: Double?
        let duration: Double?
        let title: String?
        let contentUrl: String
        let mimeType: String?
        let metadata: TrackMetadata?
        
        var id: Int { index }
        
        struct TrackMetadata: Codable {
            let filename: String?
            let ext: String?
            let path: String?
            let relPath: String?
            let size: Int64?
        }
    }
}

struct ResultsWrapper: Codable {
    let results: [LibraryItem]
}

struct UserMediaProgress: Codable {
    let id: String?
    let libraryItemId: String?
    let episodeId: String?
    let duration: Double?
    let progress: Double?
    let currentTime: Double?
    let isFinished: Bool?
    let hideFromContinueListening: Bool?
    let lastUpdate: Double?
    let startedAt: Double?
    let finishedAt: Double?
}

// Extension to expose description text for UI use
extension LibraryItem {
    var descriptionText: String {
        // Access description from media metadata if available
        if let description = self.media?.metadata.description, !description.isEmpty {
            return description
        }
        return ""
    }
}
