//
//  SwiftShelfApp.swift
//  SwiftShelf
//
//  Created by Michael Vinci on 8/2/25.
//

import SwiftUI
import Combine

@main
struct SwiftShelfApp: App {
    @StateObject private var vm = ViewModel()
    @StateObject private var config = LibraryConfig()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
                .environmentObject(config)
        }
    }
}
