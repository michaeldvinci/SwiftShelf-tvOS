//
//  ViewModel.swift
//  SwiftShelf
//
//  Created by Michael Vinci on 8/2/25.
//

import Foundation
import SwiftUI
import Combine

struct LibrarySummary: Identifiable, Codable {
    let id: String
    let name: String
}

class ViewModel: ObservableObject {
    @Published var host: String = "https://sample.abs.host"
    @Published var apiKey: String = "your-real-api-key"
    @Published var libraries: [LibrarySummary] = []
    @Published var errorMessage: String?
    @Published var isLoadingLibraries = false
    @Published var isLoadingItems = false
    
    struct LibrariesWrapper: Codable {
        let libraries: [LibraryResponse]
    }
    struct LibraryResponse: Codable {
        let id: String
        let name: String
    }
    
    func connect() async {
        guard !host.isEmpty, !apiKey.isEmpty else {
            errorMessage = "Host and API key required"
            return
        }
        isLoadingLibraries = true
        errorMessage = nil
        defer { isLoadingLibraries = false }
        
        guard var components = URLComponents(string: host) else {
            errorMessage = "Invalid host URL"
            return
        }
        components.path = "/api/libraries"
        guard let url = components.url else {
            errorMessage = "Failed to construct URL"
            return
        }
        
        var req = URLRequest(url: url)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
                errorMessage = "Libraries API returned status \(http.statusCode)"
                return
            }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let wrapper = try decoder.decode(LibrariesWrapper.self, from: data)
            self.libraries = wrapper.libraries.map { LibrarySummary(id: $0.id, name: $0.name) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func fetchItems(forLibrary libraryId: String, limit: Int = 10, sortBy: String, descBy: String) async -> [LibraryItem]? {
        guard !host.isEmpty, !apiKey.isEmpty else {
            errorMessage = "Host/API key missing"
            return nil
        }
        isLoadingItems = true
        errorMessage = nil
        defer { isLoadingItems = false }
        
        guard var components = URLComponents(string: host) else {
            errorMessage = "Invalid host URL"
            return nil
        }
        components.path = "/api/libraries/\(libraryId)/items"
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "sort", value: sortBy),
            URLQueryItem(name: "desc", value: descBy)
        ]
        guard let url = components.url else {
            errorMessage = "Bad items URL"
            return nil
        }
        
        var req = URLRequest(url: url)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
                errorMessage = "Items API returned \(http.statusCode)"
                if let raw = String(data: data, encoding: .utf8) {
                    print("Item fetch raw (non-200):", raw)
                }
                return nil
            }
            
            if let raw = String(data: data, encoding: .utf8) {
                print("Raw items response:", raw)
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            if let wrapper = try? decoder.decode(ResultsWrapper.self, from: data) {
                return wrapper.results
            }
            
            errorMessage = "Unexpected JSON structure for library items"
            return nil
        } catch {
            errorMessage = error.localizedDescription
            print("Decode error:", error)
            return nil
        }
    }
    
    private var coverCache: [String: Image] = [:]
    
    @MainActor
    func loadCover(for item: LibraryItem) async -> Image? {
        if let cached = coverCache[item.id] {
            return cached
        }
        
        guard var components = URLComponents(string: host) else { return nil }
        components.path = "/audiobookshelf/api/items/\(item.id)/cover"
        guard let url = components.url else { return nil }
        
        var req = URLRequest(url: url)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
                print("Cover fetch failed status:", http.statusCode)
                return nil
            }
            
            if let ui = UIImage(data: data) {
                let image = Image(uiImage: ui)
                coverCache[item.id] = image
                return image
            }
        } catch {
            print("Cover load error:", error)
        }
        return nil
    }
}

