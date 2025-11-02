//
//  ViewModel.swift
//  SwiftShelf
//
//  Created by michaeldvinci on 8/2/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - API Logging Utility
class APILogger {
    static func logRequest(_ request: URLRequest, description: String) {
        print("\n=== [API REQUEST] \(description) ===")
        print("URL: \(request.url?.absoluteString ?? "nil")")
        print("Method: \(request.httpMethod ?? "GET")")
        if let headers = request.allHTTPHeaderFields {
            print("Headers:")
            for (key, value) in headers {
                let maskedValue = key.lowercased().contains("auth") ? "[MASKED]" : value
                print("  \(key): \(maskedValue)")
            }
        }
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("Body: \(bodyString)")
        }
        print("========================\n")
    }
    
    static func logResponse(_ data: Data?, _ response: URLResponse?, description: String) {
        print("\n=== [API RESPONSE] \(description) ===")
        if let httpResponse = response as? HTTPURLResponse {
            print("Status Code: \(httpResponse.statusCode)")
            print("Headers:")
            for (key, value) in httpResponse.allHeaderFields {
                print("  \(key): \(value)")
            }
        }
        if let data = data {
            print("Data Size: \(data.count) bytes")
            if let responseString = String(data: data, encoding: .utf8) {
                let preview = responseString.count > 1000 ? String(responseString.prefix(1000)) + "..." : responseString
                print("Response Body: \(preview)")
            }
        }
        print("========================\n")
    }
    
    static func logError(_ error: Error, description: String) {
        print("\n=== [API ERROR] \(description) ===")
        print("Error: \(error)")
        print("Localized Description: \(error.localizedDescription)")
        if let nsError = error as NSError? {
            print("Domain: \(nsError.domain)")
            print("Code: \(nsError.code)")
            print("User Info: \(nsError.userInfo)")
        }
        print("========================\n")
    }
}

struct LibrarySummary: Identifiable, Codable {
    let id: String
    let name: String
}

class ViewModel: ObservableObject {
    @Published var refreshToken: Int = 0
    @AppStorage("libraryItemLimit") var libraryItemLimit: Int = 10 {
        didSet {
            if oldValue != libraryItemLimit {
                Task { [weak self] in
                    await self?.onLibraryItemLimitChanged()
                }
            }
        }
    }

    // Use @AppStorage to persist credentials
    @AppStorage("host") public var host: String = ""
    @AppStorage("apiKey") public var apiKey: String = ""
    
    @Published var libraries: [LibrarySummary] = []
    @Published var errorMessage: String?
    @Published var isLoadingLibraries = false
    @Published var isLoadingItems = false
    
    // Added computed isLoggedIn property to track login state
    @Published var isLoggedIn: Bool = false
    
    struct LibrariesWrapper: Codable {
        let libraries: [LibraryResponse]
    }
    struct LibraryResponse: Codable {
        let id: String
        let name: String
    }
    
    init() {
        // Initialize isLoggedIn based on current host and apiKey
        updateLoginState()
    }

    private func updateLoginState() {
        isLoggedIn = !host.isEmpty && !apiKey.isEmpty
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
        
        APILogger.logRequest(req, description: "Fetch Libraries")
        
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            APILogger.logResponse(data, resp, description: "Fetch Libraries")
            
            if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
                errorMessage = "Libraries API returned status \(http.statusCode)"
                return
            }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let wrapper = try decoder.decode(LibrariesWrapper.self, from: data)
            self.libraries = wrapper.libraries.map { LibrarySummary(id: $0.id, name: $0.name) }
            print("[ViewModel] Successfully loaded \(self.libraries.count) libraries")
        } catch {
            APILogger.logError(error, description: "Fetch Libraries")
            errorMessage = error.localizedDescription
        }
    }
    
    /// Fetch items for a given library.
    /// - Parameters:
    ///   - libraryId: The library identifier.
    ///   - limit: Optional limit on number of items to fetch; if nil, uses user-configured libraryItemLimit.
    ///   - sortBy: Field to sort by.
    ///   - descBy: Field for descending sort.
    /// - Returns: Array of LibraryItem or nil on failure.
    func fetchItems(forLibrary libraryId: String, limit: Int? = nil, sortBy: String, descBy: String) async -> [LibraryItem]? {
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
        
        let limitParam = limit ?? libraryItemLimit
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limitParam)"),
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
        
        APILogger.logRequest(req, description: "Fetch Library Items")
        
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            APILogger.logResponse(data, resp, description: "Fetch Library Items")
            
            if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
                errorMessage = "Items API returned \(http.statusCode)"
                return nil
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            if let wrapper = try? decoder.decode(ResultsWrapper.self, from: data) {
                print("[ViewModel] Successfully loaded \(wrapper.results.count) library items")
                return wrapper.results
            }
            
            errorMessage = "Unexpected JSON structure for library items"
            return nil
        } catch {
            APILogger.logError(error, description: "Fetch Library Items")
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    private var coverCache: [String: (Image, UIImage)] = [:]
    
    @MainActor
    func loadCover(for item: LibraryItem) async -> (Image, UIImage)? {
        if let cached = coverCache[item.id] {
            return cached
        }
        
        guard var components = URLComponents(string: host) else { return nil }
        components.path = "/api/items/\(item.id)/cover"
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
                coverCache[item.id] = (image, ui)
                return (image, ui)
            }
        } catch {
            print("Cover load error:", error)
        }
        return nil
    }
    
    /// Called when the user changes the library item limit in settings.
    /// This triggers a refresh token increment that the UI can observe
    /// to reload views using the updated libraryItemLimit.
    @MainActor
    private func onLibraryItemLimitChanged() async {
        refreshToken += 1
    }

    // MARK: - Experimental streaming endpoint testing (disabled by default)
    // These methods are kept for manual debugging but not called automatically
    // to avoid 404 spam in logs. The working streaming approach is in streamURL(for:in:)

    #if DEBUG
    private func testStreamingEndpoints() async {
        guard !libraries.isEmpty else { return }
        
        print("[ViewModel] Auto-testing streaming endpoints...")
        
        // Get the first library and fetch some items to test with
        let firstLibrary = libraries[0]
        if let testItems = await fetchItems(forLibrary: firstLibrary.id, limit: 1, sortBy: "addedAt", descBy: "1"),
           let firstItem = testItems.first {
            
            // Get detailed item information
            if let detailedItem = await fetchLibraryItemDetails(itemId: firstItem.id) {
                print("[ViewModel] Testing streaming URLs for item: \(detailedItem.title)")
                
                // Test the 6 direct file access patterns
                if let firstAudioFile = detailedItem.audioFiles.first,
                   let filename = firstAudioFile.metadata?.filename {
                    
                    let testPaths = [
                        "/api/items/\(detailedItem.id)/file/\(firstAudioFile.ino)",
                        "/api/items/\(detailedItem.id)/file/\(filename)",
                        "/local-files\(firstAudioFile.metadata?.path ?? "")",
                        "/files\(firstAudioFile.metadata?.relPath ?? "")",
                        "/static/\(detailedItem.id)/\(filename)",
                        "/content/\(detailedItem.id)/\(filename)"
                    ]
                    
                    for (index, path) in testPaths.enumerated() {
                        await testSingleURL(path: path, testName: "Direct Pattern \(index + 1)")
                
                // Also test session-based streaming
                await testSessionBasedStreaming(itemId: detailedItem.id, filename: filename)
                    }
                }
                
                // Also test track-based streaming if tracks exist
                if let firstTrack = detailedItem.tracks.first {
                    if let trackURL = streamURL(for: firstTrack, in: detailedItem) {
                        await testSingleURLDirectly(url: trackURL, testName: "Track-based streaming")
                    }
                }
            }
        }
        
        print("[ViewModel] Completed auto-test of streaming endpoints")
    }
    
    private func testSingleURL(path: String, testName: String) async {
        guard var components = URLComponents(string: host) else { return }
        components.path = path
        
        let cleanToken = apiKey.hasPrefix("Bearer ") ? String(apiKey.dropFirst(7)) : apiKey
        components.queryItems = [URLQueryItem(name: "token", value: cleanToken)]
        
        guard let url = components.url else { return }
        await testSingleURLDirectly(url: url, testName: testName)
    }
    
    // Test session-based streaming approaches
    private func testSessionBasedStreaming(itemId: String, filename: String) async {
        print("[ViewModel] Testing session-based streaming approaches...")
        await logToFile("Testing session-based streaming approaches...")
        
        // Test various session-based endpoints
        let sessionPaths = [
            "/api/items/\(itemId)/play",                    // Standard play endpoint
            "/api/sessions/\(itemId)/stream",               // Session stream endpoint
            "/api/sessions/local/\(itemId)",                // Local session endpoint
            "/s/\(itemId)/stream",                          // Short stream endpoint
            "/stream/\(itemId)",                            // Direct stream endpoint
            "/api/stream/\(itemId)",                        // API stream endpoint
        ]
        
        for (index, path) in sessionPaths.enumerated() {
            await testSingleURL(path: path, testName: "Session Pattern \(index + 1)")
        }
        
        // Test POST to start a playback session
        await testStartPlaybackSession(itemId: itemId)
    }
    
    // Test POST to start playback session
    private func testStartPlaybackSession(itemId: String) async {
        guard var components = URLComponents(string: host) else { return }
        components.path = "/api/session/local"
        
        let cleanToken = apiKey.hasPrefix("Bearer ") ? String(apiKey.dropFirst(7)) : apiKey
        components.queryItems = [URLQueryItem(name: "token", value: cleanToken)]
        
        guard let url = components.url else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create session start payload
        let payload: [String: Any] = [
            "libraryItemId": itemId,
            "mediaPlayer": "html5",
            "deviceInfo": [
                "deviceId": "swiftshelf-tvos",
                "name": "SwiftShelf Apple TV"
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("[ViewModel] Start Session: Status \(httpResponse.statusCode)")
                await logToFile("Start Session: Status \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200,
                   let sessionResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    print("[ViewModel] ✅ Session created successfully!")
                    await logToFile("✅ Session created successfully!")
                    
                    if let sessionId = sessionResponse["id"] as? String {
                        print("[ViewModel] Session ID: \(sessionId)")
                        await logToFile("Session ID: \(sessionId)")
                        
                        // Now test streaming with the session ID
                        await testSessionStreaming(sessionId: sessionId, itemId: itemId)
                    }
                }
            }
        } catch {
            print("[ViewModel] Start session failed: \(error.localizedDescription)")
            await logToFile("Start session failed: \(error.localizedDescription)")
        }
    }
    
    // Test streaming with session ID
    private func testSessionStreaming(sessionId: String, itemId: String) async {
        let sessionStreamPaths = [
            "/api/sessions/\(sessionId)/stream",
            "/s/session/\(sessionId)",
            "/session/\(sessionId)/stream",
            "/api/stream/session/\(sessionId)"
        ]
        
        for (index, path) in sessionStreamPaths.enumerated() {
            await testSingleURL(path: path, testName: "Session Stream \(index + 1)")
        }
    }
    
    private func testSingleURLDirectly(url: URL, testName: String) async {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("[ViewModel] \(testName): Status \(httpResponse.statusCode) - URL: \(url.absoluteString)")
                await logToFile("\(testName): Status \(httpResponse.statusCode) - URL: \(url.absoluteString)")
                
                if httpResponse.statusCode == 200 {
                    print("[ViewModel] ✅ SUCCESS: \(testName) returned 200!")
                    await logToFile("✅ SUCCESS: \(testName) returned 200!")
                }
            }
        } catch {
            print("[ViewModel] \(testName) failed: \(error.localizedDescription)")
            await logToFile("\(testName) failed: \(error.localizedDescription)")
        }
    }
    
    // Log to file for debugging
    private func logToFile(_ message: String) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let logLine = "[\(timestamp)] \(message)\n"
        
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let logFileURL = documentsDirectory.appendingPathComponent("streaming_debug.log")
        
        if let data = logLine.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logFileURL)
            }
        }
    }
    
    /// Public async method to test streaming endpoints for a specific LibraryItem.
    /// This method replicates the batch testing logic but focuses on the provided item only.
    /// 
    /// Usage:
    /// ```
    /// await viewModel.testStreamingEndpoints(for: someLibraryItem)
    /// ```
    ///
    /// It will:
    /// 1. Fetch detailed item info if needed.
    /// 2. Test direct file access endpoints.
    /// 3. Test session-based streaming endpoints.
    /// 4. Test track-based streaming endpoints.
    /// 5. Logs and prints results for UI presentation.
    @MainActor
    public func testStreamingEndpoints(for item: LibraryItem) async {
        print("[ViewModel] Starting streaming endpoint tests for item: \(item.title)")
        await logToFile("Starting streaming endpoint tests for item: \(item.title)")
        
        // Fetch detailed item info, as some tests require audioFiles and tracks
        let detailedItem: LibraryItem
        if item.audioFiles.isEmpty || item.tracks.isEmpty {
            if let fetchedItem = await fetchLibraryItemDetails(itemId: item.id) {
                detailedItem = fetchedItem
            } else {
                print("[ViewModel] Failed to fetch detailed item info for streaming tests.")
                await logToFile("Failed to fetch detailed item info for streaming tests.")
                return
            }
        } else {
            detailedItem = item
        }
        
        // Test direct file endpoints
        if let firstAudioFile = detailedItem.audioFiles.first,
           let filename = firstAudioFile.metadata?.filename {
            
            let testPaths = [
                "/api/items/\(detailedItem.id)/file/\(firstAudioFile.ino)",
                "/api/items/\(detailedItem.id)/file/\(filename)",
                "/local-files\(firstAudioFile.metadata?.path ?? "")",
                "/files\(firstAudioFile.metadata?.relPath ?? "")",
                "/static/\(detailedItem.id)/\(filename)",
                "/content/\(detailedItem.id)/\(filename)"
            ]
            
            for (index, path) in testPaths.enumerated() {
                await testSingleURL(path: path, testName: "Direct Pattern \(index + 1)")
            }
            
            // Also test session-based streaming endpoints for this item
            await testSessionBasedStreaming(itemId: detailedItem.id, filename: filename)
        } else {
            print("[ViewModel] No audio files available to test direct/session streaming endpoints.")
            await logToFile("No audio files available to test direct/session streaming endpoints.")
        }
        
        // Test track-based streaming URLs if tracks exist
        if let firstTrack = detailedItem.tracks.first {
            if let trackURL = streamURL(for: firstTrack, in: detailedItem) {
                await testSingleURLDirectly(url: trackURL, testName: "Track-based streaming")
            } else {
                print("[ViewModel] Failed to generate track stream URL.")
                await logToFile("Failed to generate track stream URL.")
            }
        } else {
            print("[ViewModel] No tracks available to test track-based streaming.")
            await logToFile("No tracks available to test track-based streaming.")
        }
        
        print("[ViewModel] Completed streaming endpoint tests for item: \(item.title)")
        await logToFile("Completed streaming endpoint tests for item: \(item.title)")
    }
    #endif

}


// MARK: - ViewModel Extensions for Progress & Streaming
extension ViewModel {
    /// Fetch full library item details including audioFiles and chapters
    func fetchLibraryItemDetails(itemId: String) async -> LibraryItem? {
        guard !host.isEmpty, !apiKey.isEmpty else {
            errorMessage = "Host/API key missing"
            return nil
        }
        
        guard var components = URLComponents(string: host) else {
            errorMessage = "Invalid host URL"
            return nil
        }
        components.path = "/api/items/\(itemId)"
        
        guard let url = components.url else {
            errorMessage = "Bad item details URL"
            return nil
        }
        
        var req = URLRequest(url: url)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        APILogger.logRequest(req, description: "Fetch Library Item Details")
        
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            APILogger.logResponse(data, resp, description: "Fetch Library Item Details")
            
            // Additional detailed logging for streaming endpoints
            if let rawResponse = String(data: data, encoding: .utf8) {
                print("[ViewModel] Looking for streaming paths in API response...")
                
                // Search for potential streaming URLs or paths
                if let tracksRange = rawResponse.range(of: "\"tracks\":") {
                    let tracksSection = String(rawResponse[tracksRange.lowerBound...])
                    if let endBracket = tracksSection.range(of: "]")?.upperBound {
                        let tracksData = String(tracksSection[..<endBracket])
                        print("[ViewModel] TRACKS SECTION: \(tracksData)")
                    }
                }
                
                if let audioFilesRange = rawResponse.range(of: "\"audioFiles\":") {
                    let audioSection = String(rawResponse[audioFilesRange.lowerBound...])
                    if let endBracket = audioSection.range(of: "]")?.upperBound {
                        let audioData = String(audioSection[..<endBracket])
                        print("[ViewModel] AUDIO FILES SECTION: \(audioData)")
                    }
                }
            }
            
            if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
                errorMessage = "Item details API returned \(http.statusCode)"
                return nil
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let item = try decoder.decode(LibraryItem.self, from: data)
            print("[ViewModel] Successfully loaded item details: \(item.tracks.count) tracks, \(item.audioFiles.count) audio files")
            return item
        } catch {
            APILogger.logError(error, description: "Fetch Library Item Details")
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    // Build stream URL for a specific track within an item
    func streamURL(for track: LibraryItem.Track, in item: LibraryItem) -> URL? {
        guard var components = URLComponents(string: host) else { return nil }
        
        // ContentUrl from API is a relative path, so we use it directly
        let contentPath = track.contentUrl.hasPrefix("/") ? track.contentUrl : "/\(track.contentUrl)"
        components.path = contentPath
        
        let cleanToken = apiKey.hasPrefix("Bearer ") ? String(apiKey.dropFirst(7)) : apiKey
        components.queryItems = [
            URLQueryItem(name: "token", value: cleanToken)
        ]
        let url = components.url
        print("[ViewModel] Generated track stream URL: \(url?.absoluteString ?? "nil")")
        print("[ViewModel] Track content URL: \(track.contentUrl)")
        print("[ViewModel] Track mime type: \(track.mimeType ?? "unknown")")
        print("[ViewModel] Host: \(host)")
        return url
    }
    
    // Legacy method for backward compatibility (kept for audioFiles fallback)
    func streamURL(for audioFile: LibraryItem.AudioFile, in item: LibraryItem) -> URL? {
        guard var components = URLComponents(string: host) else { return nil }
        // Construct streaming path using filename
        let filename = audioFile.metadata?.filename ?? audioFile.filename ?? "audio_\(audioFile.index)"
        components.path = "/s/item/\(item.id)/\(filename)"
        let cleanToken = apiKey.hasPrefix("Bearer ") ? String(apiKey.dropFirst(7)) : apiKey
        components.queryItems = [
            URLQueryItem(name: "token", value: cleanToken)
        ]
        let url = components.url
        print("[ViewModel] Generated audio file stream URL: \(url?.absoluteString ?? "nil")")
        return url
    }
    
    // Build direct file access URL based on actual audiobook file paths
    func streamURL(for item: LibraryItem) -> URL? {
        // Get the first audio file from the item
        guard let audioFile = item.audioFiles.first,
              let filename = audioFile.metadata?.filename else {
            print("[ViewModel] No audio files found for direct streaming")
            return nil
        }
        
        // Try direct file access patterns based on AudioBookshelf file serving
        let possiblePaths = [
            "/api/items/\(item.id)/file/\(audioFile.ino)",                    // File by ino (most likely)
            "/api/items/\(item.id)/file/\(filename)",                         // File by filename
            "/local-files\(audioFile.metadata?.path ?? "")",                 // Direct file path access
            "/files\(audioFile.metadata?.relPath ?? "")",                    // Relative path access
            "/static/\(item.id)/\(filename)",                                // Static file serving
            "/content/\(item.id)/\(filename)",                               // Content serving
        ]
        
        for path in possiblePaths {
            guard var components = URLComponents(string: host) else { continue }
            components.path = path
            let cleanToken = apiKey.hasPrefix("Bearer ") ? String(apiKey.dropFirst(7)) : apiKey
            components.queryItems = [
                URLQueryItem(name: "token", value: cleanToken)
            ]
            
            if let url = components.url {
                print("[ViewModel] Trying direct file endpoint: \(url.absoluteString)")
                return url
            }
        }
        
        return nil
    }
    
    /// Save progress for a library item to the server
    /// - Parameters:
    ///   - item: The library item
    ///   - seconds: Current playback position in seconds
    func saveProgress(for item: LibraryItem, seconds: Double) async {
        guard !host.isEmpty, !apiKey.isEmpty else {
            print("[ViewModel] Cannot save progress: missing host or API key")
            return
        }

        guard let duration = item.duration else {
            print("[ViewModel] Cannot save progress: missing duration for item \(item.id)")
            return
        }

        guard var components = URLComponents(string: host) else {
            print("[ViewModel] Invalid host URL: \(host)")
            return
        }

        components.path = "/api/me/progress"

        guard let url = components.url else {
            print("[ViewModel] Failed to construct progress URL")
            return
        }

        let progress = min(1.0, max(0.0, seconds / duration))

        let payload: [String: Any] = [
            "libraryItemId": item.id,
            "duration": duration,
            "progress": progress,
            "currentTime": seconds,
            "isFinished": progress >= 0.99
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)

            APILogger.logRequest(request, description: "Save Progress")

            let (data, response) = try await URLSession.shared.data(for: request)

            APILogger.logResponse(data, response, description: "Save Progress")

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("[ViewModel] ✅ Progress saved: \(seconds)s / \(duration)s (\(Int(progress * 100))%)")
                } else {
                    print("[ViewModel] ❌ Save progress failed with status \(httpResponse.statusCode)")
                }
            }
        } catch {
            APILogger.logError(error, description: "Save Progress")
            print("[ViewModel] Error saving progress: \(error.localizedDescription)")
        }
    }

    /// Load progress for a library item from the server
    /// - Parameter item: The library item
    /// - Returns: Current playback position in seconds, or nil if not found
    func loadProgress(for item: LibraryItem) async -> Double? {
        guard !host.isEmpty, !apiKey.isEmpty else {
            print("[ViewModel] Cannot load progress: missing host or API key")
            return nil
        }

        guard var components = URLComponents(string: host) else {
            print("[ViewModel] Invalid host URL: \(host)")
            return nil
        }

        components.path = "/api/me/progress/\(item.id)"

        guard let url = components.url else {
            print("[ViewModel] Failed to construct progress URL")
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            APILogger.logRequest(request, description: "Load Progress")

            let (data, response) = try await URLSession.shared.data(for: request)

            APILogger.logResponse(data, response, description: "Load Progress")

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    let decoder = JSONDecoder()
                    let progressData = try decoder.decode(UserMediaProgress.self, from: data)

                    let currentTime = progressData.currentTime ?? 0
                    print("[ViewModel] ✅ Progress loaded for \(item.title): \(currentTime)s (progress: \(progressData.progress ?? 0))")
                    return currentTime
                } else if httpResponse.statusCode == 404 {
                    print("[ViewModel] No progress found for item \(item.id)")
                    return nil
                } else {
                    print("[ViewModel] ❌ Load progress failed with status \(httpResponse.statusCode)")
                    return nil
                }
            }
        } catch {
            APILogger.logError(error, description: "Load Progress")
            print("[ViewModel] Error loading progress: \(error.localizedDescription)")
        }

        return nil
    }
}

