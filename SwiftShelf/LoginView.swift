import SwiftUI

struct LoginView: View {
    @State private var host = ""
    @State private var apiKey = ""

    var body: some View {
        VStack {
            TextField("Host", text: $host)
                .padding()
            SecureField("API Key", text: $apiKey)
                .padding()
            Button("Login") {
                // Handle login action
            }
            .padding()
        }
    }
}
