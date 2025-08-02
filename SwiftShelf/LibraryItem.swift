//
//  LibraryItem.swift
//  SwiftShelf
//
//  Created by Michael Vinci on 8/2/25.
//

import Foundation

struct LibraryItem: Identifiable, Codable {
    let id: String
    let media: Media?

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

    struct Media: Codable {
        let duration: Double?
        let coverPath: String?
        let metadata: Metadata

        struct Metadata: Codable {
            let title: String?
            let authors: [Author]?
            let series: [Series]?
            let authorNameLF: String?
            let authorName: String?
            let seriesName: String?

            struct Author: Codable {
                let name: String
            }
            struct Series: Codable {
                let name: String
            }
        }
    }
}

struct ResultsWrapper: Codable {
    let results: [LibraryItem]
}

