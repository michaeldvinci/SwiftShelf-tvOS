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
        #if DEBUG
        print("\n=== [API REQUEST] \(description) ===")
        if let url = request.url?.absoluteString {
            // Redact token from URL
            let redacted = url.replacingOccurrences(of: #"token=[^&]+"#, with: "token=[REDACTED]", options: .regularExpression)
            print("URL: \(redacted)")
        }
        print("Method: \(request.httpMethod ?? "GET")")
        if let headers = request.allHTTPHeaderFields {
            print("Headers:")
            for (key, value) in headers {
                let maskedValue = key.lowercased().contains("auth") ? "[REDACTED]" : value
                print("  \(key): \(maskedValue)")
            }
        }
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("Body: \(bodyString)")
        }
        print("========================\n")
        #endif
    }

    static func logResponse(_ data: Data?, _ response: URLResponse?, description: String) {
        #if DEBUG
        print("\n=== [API RESPONSE] \(description) ===")
        if let httpResponse = response as? HTTPURLResponse {
            print("Status Code: \(httpResponse.statusCode)")
        }
        if let data = data {
            print("Data Size: \(data.count) bytes")
            if let bodyString = String(data: data, encoding: .utf8) {
                print("Response Body: \(bodyString)")
            }
        }
        print("========================\n")
        #endif
    }

    static func logError(_ error: Error, description: String) {
        #if DEBUG
        print("\n=== [API ERROR] \(description) ===")
        print("Error: \(error.localizedDescription)")
        print("========================\n")
        #endif
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

    // Credentials stored in Keychain (in-memory cache)
    @Published public var host: String = ""
    @Published public var apiKey: String = ""

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
        // Migrate from UserDefaults to Keychain if needed
        migrateCredentialsToKeychain()
        // Load credentials from Keychain
        loadCredentialsFromKeychain()
        // Initialize isLoggedIn based on current host and apiKey
        updateLoginState()
    }

    private func migrateCredentialsToKeychain() {
        let defaults = UserDefaults.standard

        // Migrate host if it exists in UserDefaults
        if let hostValue = defaults.string(forKey: "host"), !hostValue.isEmpty {
            do {
                try KeychainService.set(hostValue, forKey: "host")
                defaults.removeObject(forKey: "host")
                #if DEBUG
                print("[ViewModel] Migrated host to Keychain")
                #endif
            } catch {
                #if DEBUG
                print("[ViewModel] Failed to migrate host: \(error)")
                #endif
            }
        }

        // Migrate apiKey if it exists in UserDefaults
        if let apiKeyValue = defaults.string(forKey: "apiKey"), !apiKeyValue.isEmpty {
            do {
                try KeychainService.set(apiKeyValue, forKey: "apiKey")
                defaults.removeObject(forKey: "apiKey")
                #if DEBUG
                print("[ViewModel] Migrated apiKey to Keychain")
                #endif
            } catch {
                #if DEBUG
                print("[ViewModel] Failed to migrate apiKey: \(error)")
                #endif
            }
        }
    }

    private func loadCredentialsFromKeychain() {
        // Load host
        if let hostValue = try? KeychainService.get(forKey: "host") {
            self.host = hostValue
        }

        // Load apiKey
        if let apiKeyValue = try? KeychainService.get(forKey: "apiKey") {
            self.apiKey = apiKeyValue
        }
    }

    func saveCredentialsToKeychain(host: String, apiKey: String) {
        do {
            try KeychainService.set(host, forKey: "host")
            try KeychainService.set(apiKey, forKey: "apiKey")
            self.host = host
            self.apiKey = apiKey
            updateLoginState()
            #if DEBUG
            print("[ViewModel] Credentials saved to Keychain")
            #endif
        } catch {
            #if DEBUG
            print("[ViewModel] Failed to save credentials: \(error)")
            #endif
            errorMessage = "Failed to save credentials securely"
        }
    }

    func logout() {
        do {
            try KeychainService.delete(forKey: "host")
            try KeychainService.delete(forKey: "apiKey")
            self.host = ""
            self.apiKey = ""
            self.libraries = []
            updateLoginState()
            #if DEBUG
            print("[ViewModel] Logged out and cleared credentials")
            #endif
        } catch {
            #if DEBUG
            print("[ViewModel] Failed to clear credentials: \(error)")
            #endif
        }
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
            URLQueryItem(name: "desc", value: descBy),
            URLQueryItem(name: "expanded", value: "1")
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
                #if DEBUG
                if let firstItem = wrapper.results.first {
                    print("[ViewModel] First item chapters count: \(firstItem.chapters.count)")
                    if !firstItem.chapters.isEmpty {
                        print("[ViewModel] First chapter: \(firstItem.chapters[0].title)")
                    }
                }
                #endif
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
                return nil
            }

            if let ui = UIImage(data: data) {
                let image = Image(uiImage: ui)
                coverCache[item.id] = (image, ui)
                return (image, ui)
            }
        } catch {
            #if DEBUG
            print("[ViewModel] Cover load error: \(error.localizedDescription)")
            #endif
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

            if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
                errorMessage = "Item details API returned \(http.statusCode)"
                return nil
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let item = try decoder.decode(LibraryItem.self, from: data)

            #if DEBUG
            print("[ViewModel] Fetched item details - title: \(item.title)")
            print("[ViewModel] Author info - authorNameLF: \(String(describing: item.authorNameLF)), authorName: \(String(describing: item.authorName))")
            print("[ViewModel] Chapters count: \(item.chapters.count)")
            #endif

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
        return components.url
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
        return components.url
    }

    // Build direct file access URL based on actual audiobook file paths
    func streamURL(for item: LibraryItem) -> URL? {
        guard let audioFile = item.audioFiles.first else {
            return nil
        }

        guard var components = URLComponents(string: host) else { return nil }
        components.path = "/api/items/\(item.id)/file/\(audioFile.ino)"
        let cleanToken = apiKey.hasPrefix("Bearer ") ? String(apiKey.dropFirst(7)) : apiKey
        components.queryItems = [
            URLQueryItem(name: "token", value: cleanToken)
        ]
        return components.url
    }
    
    /// Save progress for a library item to the server
    /// - Parameters:
    ///   - item: The library item
    ///   - seconds: Current playback position in seconds
    ///   - duration: Total duration (optional, falls back to item.duration)
    ///   - timeListened: Total time listened (optional)
    ///   - startedAt: Timestamp when playback started in milliseconds (optional)
    func saveProgress(for item: LibraryItem, seconds: Double, duration: Double? = nil, timeListened: Double? = nil, startedAt: Int? = nil) async {
        guard !host.isEmpty, !apiKey.isEmpty else {
            print("[ViewModel] Cannot save progress: missing host or API key")
            return
        }

        // Use provided duration, or fall back to item.duration
        let actualDuration = duration ?? item.duration
        guard let actualDuration = actualDuration else {
            print("[ViewModel] Cannot save progress: missing duration for item \(item.id)")
            return
        }

        guard var components = URLComponents(string: host) else {
            print("[ViewModel] Invalid host URL: \(host)")
            return
        }

        components.path = "/api/me/progress/\(item.id)"

        guard let url = components.url else {
            print("[ViewModel] Failed to construct progress URL")
            return
        }

        let progress = min(1.0, max(0.0, seconds / actualDuration))
        let now = Int(Date().timeIntervalSince1970 * 1000) // milliseconds

        var payload: [String: Any] = [
            "duration": actualDuration,
            "progress": progress,
            "currentTime": seconds,
            "isFinished": progress >= 0.99,
            "lastUpdate": now
        ]

        // Add optional fields if provided
        if let timeListened = timeListened {
            payload["timeListened"] = timeListened
        }
        if let startedAt = startedAt {
            payload["startedAt"] = startedAt
        }

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
                #if DEBUG
                if httpResponse.statusCode == 200 {
                    print("[ViewModel] Progress saved: \(Int(seconds))s")
                } else {
                    print("[ViewModel] Save progress failed: \(httpResponse.statusCode)")
                }
                #endif
            }
        } catch {
            APILogger.logError(error, description: "Save Progress")
        }
    }

    // MARK: - Session Management

    /// Start/open a playback session
    /// - Parameters:
    ///   - item: The library item
    ///   - deviceInfo: Optional device information
    /// - Returns: Session ID if successful
    func startSession(for item: LibraryItem, deviceInfo: [String: Any]? = nil) async -> String? {
        guard !host.isEmpty, !apiKey.isEmpty else {
            print("[ViewModel] Cannot start session: missing host or API key")
            return nil
        }

        guard var components = URLComponents(string: host) else {
            print("[ViewModel] Invalid host URL: \(host)")
            return nil
        }

        components.path = "/api/session/local"

        guard let url = components.url else {
            print("[ViewModel] Failed to construct session URL")
            return nil
        }

        let payload: [String: Any] = [
            "libraryItemId": item.id,
            "deviceInfo": deviceInfo ?? [
                "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
                "clientName": "SwiftShelf",
                "deviceName": UIDevice.current.name
            ],
            "startedAt": Int(Date().timeIntervalSince1970 * 1000)
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            APILogger.logRequest(request, description: "Start Session")

            let (data, response) = try await URLSession.shared.data(for: request)
            APILogger.logResponse(data, response, description: "Start Session")

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                // Try to parse JSON response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let sessionId = json["id"] as? String {
                        print("[ViewModel] Session started with ID from JSON: \(sessionId)")
                        return sessionId
                    }
                    print("[ViewModel] Session JSON response: \(json)")
                }

                // If response is just "OK", try to get session ID from response body as string
                if let bodyString = String(data: data, encoding: .utf8) {
                    print("[ViewModel] Session response body: \(bodyString)")
                    // Check if it's a plain session ID
                    if bodyString != "OK" && !bodyString.isEmpty {
                        print("[ViewModel] Using response body as session ID: \(bodyString)")
                        return bodyString
                    }
                }

                print("[ViewModel] ⚠️ Session started but no session ID in response")
            }
        } catch {
            APILogger.logError(error, description: "Start Session")
        }

        return nil
    }

    /// Sync/update an open session
    /// - Parameters:
    ///   - sessionId: The session ID
    ///   - currentTime: Current playback position
    ///   - duration: Total duration
    ///   - timeListened: Actual time listened (optional, defaults to currentTime)
    func syncSession(sessionId: String, currentTime: Double, duration: Double, timeListened: Double? = nil) async {
        guard !host.isEmpty, !apiKey.isEmpty else { return }

        guard var components = URLComponents(string: host) else { return }
        components.path = "/api/session/\(sessionId)/sync"

        guard let url = components.url else { return }

        let payload: [String: Any] = [
            "currentTime": currentTime,
            "duration": duration,
            "timeListened": timeListened ?? currentTime
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)

            APILogger.logRequest(request, description: "Sync Session")

            let (data, response) = try await URLSession.shared.data(for: request)

            APILogger.logResponse(data, response, description: "Sync Session")

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("[ViewModel] Session synced: \(sessionId)")
            } else if let httpResponse = response as? HTTPURLResponse {
                print("[ViewModel] Session sync failed: \(httpResponse.statusCode)")
            }
        } catch {
            print("[ViewModel] Session sync failed: \(error)")
        }
    }

    /// Close a playback session
    /// - Parameter sessionId: The session ID
    func closeSession(sessionId: String) async {
        guard !host.isEmpty, !apiKey.isEmpty else { return }

        guard var components = URLComponents(string: host) else { return }
        components.path = "/api/session/local/\(sessionId)"

        guard let url = components.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("[ViewModel] Session closed: \(sessionId)")
            }
        } catch {
            print("[ViewModel] Close session failed: \(error)")
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
                    #if DEBUG
                    print("[ViewModel] Progress loaded: \(Int(currentTime))s")
                    #endif
                    return currentTime
                } else if httpResponse.statusCode == 404 {
                    return nil
                } else {
                    return nil
                }
            }
        } catch {
            APILogger.logError(error, description: "Load Progress")
        }

        return nil
    }
}

