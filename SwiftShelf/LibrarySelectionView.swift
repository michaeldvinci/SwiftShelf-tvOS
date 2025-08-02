//
//  LibrarySelectionView.swift
//  SwiftShelf
//
//  Created by Michael Vinci on 8/2/25.
//

import SwiftUI

struct LibrarySelectionView: View {
    @EnvironmentObject var vm: ViewModel
    @EnvironmentObject var config: LibraryConfig

    @State private var showDetail = false

    var body: some View {
        NavigationStack {
            VStack {
                Text("Select Libraries")
                    .font(.title2)
                    .padding(.bottom, 8)

                List {
                    ForEach(vm.libraries) { lib in
                        let sel = SelectedLibrary(id: lib.id, name: lib.name)
                        Button {
                            config.toggle(sel)
                        } label: {
                            HStack {
                                Image(systemName: config.contains(sel) ? "checkmark.circle.fill" : "circle")
                                    .resizable()
                                    .frame(width: 28, height: 28)
                                    .foregroundColor(config.contains(sel) ? .green : .gray)
                                VStack(alignment: .leading) {
                                    Text(lib.name).font(.headline)
                                    Text(lib.id).font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)

                HStack {
                    Text("Selected: \(config.selected.map { $0.name }.joined(separator: ", "))")
                        .lineLimit(2)
                        .truncationMode(.tail)
                    Spacer()
                    Button("Next") {
                        showDetail = true
                    }
                    .disabled(config.selected.isEmpty)
                }
                .padding()
            }
            .padding()
            .navigationTitle("Choose Libraries")
            .navigationDestination(isPresented: $showDetail) {
                LibraryDetailView()
                    .environmentObject(vm)
                    .environmentObject(config)
            }
            .onAppear {
                if !config.selected.isEmpty {
                    showDetail = true
                }
            }
        }
    }
}
