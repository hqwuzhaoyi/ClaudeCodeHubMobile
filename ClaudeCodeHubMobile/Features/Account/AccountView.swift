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

                Section("Release Readiness") {
                    ReleaseChecklistRow(
                        title: "Credential storage",
                        detail: "Raw keys are discarded after sign-in; restored sessions depend on server cookies.",
                        systemImage: "key.slash"
                    )
                    ReleaseChecklistRow(
                        title: "Signing hygiene",
                        detail: "Keep personal DEVELOPMENT_TEAM values out of commits; configure signing locally in Xcode.",
                        systemImage: "person.badge.shield.checkmark"
                    )
                    ReleaseChecklistRow(
                        title: "Preflight",
                        detail: "Run swift test and a generic iOS Simulator build before archiving or TestFlight.",
                        systemImage: "checklist.checked"
                    )
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

private struct ReleaseChecklistRow: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.blue)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    AccountView(sessionStore: .previewSignedIn)
}
