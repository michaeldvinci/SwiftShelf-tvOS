//
//  ContentView.swift
//  SwiftShelf
//
//  Created by Michael Vinci on 8/2/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: ViewModel
    @EnvironmentObject var config: LibraryConfig
    @State private var showSelection = false

    var body: some View {
        NavigationStack {
            Group {
                if !config.selected.isEmpty {
                    LibraryDetailView()
                        .environmentObject(vm)
                        .environmentObject(config)
                } else {
                    connectionSelectionPane
                }
            }
            .padding()
            .navigationTitle("Libraries")
            .navigationDestination(isPresented: $showSelection) {
                LibrarySelectionView()
                    .environmentObject(vm)
                    .environmentObject(config)
            }
        }
    }

    private var connectionSelectionPane: some View {
        VStack(spacing: 16) {
            Text("Audiobookshelf Libraries").font(.title2)
            VStack(spacing: 8) {
                TextField("Host", text: Binding(
                    get: { vm.host },
                    set: { vm.host = $0 }
                ))
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.init(red: 0.15, green: 0.15, blue: 0.18, alpha: 1)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.6), lineWidth: 2)
                )
                .autocapitalization(.none)
                .disableAutocorrection(true)

                SecureField("API Key", text: Binding(
                    get: { vm.apiKey },
                    set: { vm.apiKey = $0 }
                ))
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.init(red: 0.15, green: 0.15, blue: 0.18, alpha: 1)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.6), lineWidth: 2)
                )
            }

            Button {
                Task {
                    await vm.connect()
                }
            } label: {
                if vm.isLoadingLibraries {
                    ProgressView()
                } else {
                    Text("Connect").bold()
                }
            }
            .disabled(vm.host.isEmpty || vm.apiKey.isEmpty)

            Button("Select Libraries") {
                showSelection = true
            }
            .disabled(vm.libraries.isEmpty)

            if let err = vm.errorMessage {
                Text(err)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            List(vm.libraries) { lib in
                HStack {
                    Text(lib.name)
                    Spacer()
                    Text(lib.id)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
        }
    }
}
