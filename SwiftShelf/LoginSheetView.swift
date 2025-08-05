import SwiftUI

struct LoginSheetView: View {
    @Binding var host: String
    @Binding var apiKey: String
    @Environment(\.dismiss) private var dismiss
    
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
        }
    }
}

#Preview {
    @State var h: String = "demo"
    @State var k: String = "secret"
    return LoginSheetView(host: $h, apiKey: $k)
}
