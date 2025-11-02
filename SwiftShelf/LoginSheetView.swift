import SwiftUI

struct LoginSheetView: View {
    @EnvironmentObject var viewModel: ViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var host: String = ""
    @State private var apiKey: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Login Credentials")) {
                    TextField("Host", text: $host)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    SecureField("API Key", text: $apiKey)
                }
                Section {
                    Button("Done") {
                        viewModel.saveCredentialsToKeychain(host: host, apiKey: apiKey)
                        dismiss()
                    }
                    .disabled(host.isEmpty || apiKey.isEmpty)
                }
            }
            .navigationTitle("Login")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Pre-fill with current values
                host = viewModel.host
                apiKey = viewModel.apiKey
            }
        }
    }
}

#Preview {
    LoginSheetView()
        .environmentObject(ViewModel())
}
