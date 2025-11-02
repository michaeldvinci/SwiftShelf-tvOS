//
//  LibrarySelectionView.swift
//  SwiftShelf
//
//  Created by michaeldvinci on 8/2/25.
//

// View that allows users to select libraries from a list and update the selected libraries configuration.

import SwiftUI

// This view presents a list of available libraries for the user to select or deselect.
struct LibrarySelectionView: View {
    // ViewModel providing the list of available libraries and related data.
    @EnvironmentObject var vm: ViewModel
    // Configuration object tracking the currently selected libraries.
    @EnvironmentObject var config: LibraryConfig

    // Binding to control the presentation state of this view (used for dismissing).
    @Binding var isPresented: Bool

    // State variable controlling navigation to the detail view.
    @State private var showDetail = false

    var body: some View {
        // Wrap the view content in a navigation stack to enable navigation presentations.
        NavigationStack {
            VStack {
                List {
                    // Iterate over all available libraries to display them.
                    ForEach(vm.libraries) { lib in
                        // Create a selection wrapper for the current library.
                        let sel = SelectedLibrary(id: lib.id, name: lib.name)
                        // Button that toggles the selection state of the library when tapped.
                        Button {
                            config.toggle(sel)
                        } label: {
                            // Layout each library item row with icon and name.
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
            // Navigation destination used for showing the detail view when triggered.
            .navigationDestination(isPresented: $showDetail) {
                // Show the detail view for the first selected library if available.
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
