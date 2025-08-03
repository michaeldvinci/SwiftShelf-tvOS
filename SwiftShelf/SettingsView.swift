import SwiftUI
import Combine

struct SettingsView: View {
    @EnvironmentObject var vm: ViewModel
    @AppStorage("libraryItemLimit") var libraryItemLimit: Int = 10
    @State private var draftLimit: Int

    init() {
        _draftLimit = State(initialValue: UserDefaults.standard.integer(forKey: "libraryItemLimit") == 0 ? 10 : UserDefaults.standard.integer(forKey: "libraryItemLimit"))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Libraries will automatically refresh when settings are saved.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
                
                Section(header: Text("Library Settings")) {
                    VStack(alignment: .leading) {
                        HStack {
                            Button(action: { if draftLimit > 5 { draftLimit -= 1 } }) {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Text("Max Items per Library Query: \(draftLimit)")
                                .frame(minWidth: 180, alignment: .center)
                                .padding(.horizontal, 8)

                            Button(action: { if draftLimit < 50 { draftLimit += 1 } }) {
                                Image(systemName: "plus.circle")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        Button("Save") {
                            libraryItemLimit = draftLimit
                            vm.objectWillChange.send()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 6)
                        
                        Text("This setting controls the maximum number of items fetched per query from the library to optimize performance and data usage.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                }
                
                Section(header: Text("Danger Zone")) {
                    Button(role: .destructive) {
                        // TODO: Implement remove action
                    } label: {
                        Text("Remove")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(ViewModel())
    }
}
