//
//  LibraryConfig.swift
//  SwiftShelf
//
//  Created by Michael Vinci on 8/2/25.
//

import Foundation
import Combine

struct SelectedLibrary: Codable, Identifiable, Equatable {
    let id: String
    let name: String
}

class LibraryConfig: ObservableObject {
    @Published var selected: [SelectedLibrary] = [] {
        didSet { save() }
    }

    private let storageKey = "SelectedLibraries"

    init() {
        load()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([SelectedLibrary].self, from: data) {
            selected = decoded
        }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(selected) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    func toggle(_ lib: SelectedLibrary) {
        if let idx = selected.firstIndex(of: lib) {
            selected.remove(at: idx)
        } else {
            selected.append(lib)
        }
    }

    func contains(_ lib: SelectedLibrary) -> Bool {
        selected.contains(lib)
    }
}
