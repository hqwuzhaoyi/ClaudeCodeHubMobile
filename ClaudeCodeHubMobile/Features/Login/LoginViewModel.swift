import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var baseURLString = ""
    @Published var accessKey = ""
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    var canSubmit: Bool {
        !baseURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !accessKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isLoading
    }

    func signIn(using sessionStore: SessionStore) async {
        guard canSubmit else { return }
        isLoading = true
        errorMessage = nil
        sessionStore.clearSessionMessage()
        defer { isLoading = false }

        do {
            try await sessionStore.signIn(baseURLString: baseURLString, accessKey: accessKey)
            accessKey = ""
        } catch {
            errorMessage = APIError.userMessage(for: error)
        }
    }
}
