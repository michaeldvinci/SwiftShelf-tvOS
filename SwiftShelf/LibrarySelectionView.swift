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

    @Binding var isPresented: Bool

    @State private var showDetail = false

    var body: some View {
        NavigationStack {
            VStack {
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
                                }
                                Spacer()
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
            .padding()
            .navigationTitle("Choose Libraries")
            .navigationDestination(isPresented: $showDetail) {
                if let firstSelected = config.selected.first {
                    LibraryDetailView(library: firstSelected)
                        .environmentObject(vm)
                        .environmentObject(config)
                } else {
                    EmptyView()
                }
            }
        }
    }
}

