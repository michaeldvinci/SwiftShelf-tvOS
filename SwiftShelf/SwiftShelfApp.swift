//
//  SwiftShelfApp.swift
//  SwiftShelf
//
//  Created by michaeldvinci on 8/2/25.
//

import SwiftUI
import Combine

@main
struct SwiftShelfApp: App {
    @StateObject private var vm = ViewModel()
    @StateObject private var config = LibraryConfig()
    @StateObject private var audioManager = GlobalAudioManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
                .environmentObject(config)
                .environmentObject(audioManager)
                .onAppear {
                    print("[SwiftShelfApp] 🚀 App launched!")
                }
        }
    }
}
