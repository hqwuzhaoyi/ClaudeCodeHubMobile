import SwiftUI

struct AccountView: View {
    @ObservedObject var sessionStore: SessionStore
    @State private var isConfirmingSignOut = false

    var body: some View {
        NavigationStack {
            List {
                Section("Current Server") {
                    LabeledContent("Base URL", value: sessionStore.serverDisplayName)
                    LabeledContent("Session", value: sessionStore.isAuthenticated ? "Signed in" : "Signed out")
                }

                if let user = sessionStore.lastLoginResponse?.user {
                    Section("User") {
                        LabeledContent("Name", value: user.displayName)
                        if let email = user.email {
                            LabeledContent("Email", value: email)
                        }
                        if let keyName = user.keyName {
                            LabeledContent("Key", value: keyName)
                        }
                    }
                }

                Section {
                    Label("Authentication is cookie-backed after login. The raw access key is not stored by the app.", systemImage: "lock.shield")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button(role: .destructive) {
                        isConfirmingSignOut = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Account")
            .confirmationDialog("Sign out of this Claude Code Hub server?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    sessionStore.signOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This clears the stored server URL and cookies for the current server.")
            }
        }
    }
}

#Preview {
    AccountView(sessionStore: .previewSignedIn)
}
