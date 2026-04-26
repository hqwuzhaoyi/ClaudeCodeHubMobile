import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var viewModel = LoginViewModel()
    @FocusState private var focusedField: Field?

    private enum Field {
        case server
        case key
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://hub.example.com", text: $viewModel.baseURLString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .focused($focusedField, equals: .server)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .key }

                    SecureField("Access key", text: $viewModel.accessKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .key)
                        .submitLabel(.go)
                        .onSubmit { Task { await viewModel.signIn(using: sessionStore) } }
                } header: {
                    Text("Server")
                } footer: {
                    Text("The access key is sent only to your server for login. The app stores cookies and the server URL, not the raw key.")
                }

                if let message = viewModel.errorMessage ?? sessionStore.sessionErrorMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await viewModel.signIn(using: sessionStore) }
                    } label: {
                        HStack {
                            Text("Sign In")
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(!viewModel.canSubmit)
                }
            }
            .navigationTitle("Claude Code Hub")
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(SessionStore.previewSignedOut)
}
