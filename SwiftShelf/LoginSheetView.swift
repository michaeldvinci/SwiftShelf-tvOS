// A reusable login sheet view for entering host and API key, updating the values via bindings.
import SwiftUI

struct LoginSheetView: View {
    @Binding var host: String
    @Binding var apiKey: String
    @Environment(\.dismiss) private var dismiss
    @State private var tempHost: String = ""
    @State private var tempApiKey: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Host")) {
                    TextField("Enter host (e.g. https://host)", text: $tempHost)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                Section(header: Text("API Key")) {
                    SecureField("Enter API Key", text: $tempApiKey)
                }
            }
            .navigationTitle("Login")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        host = tempHost.trimmingCharacters(in: .whitespacesAndNewlines)
                        apiKey = tempApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }
                    .disabled(tempHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || tempApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            tempHost = host
            tempApiKey = apiKey
        }
    }
}
