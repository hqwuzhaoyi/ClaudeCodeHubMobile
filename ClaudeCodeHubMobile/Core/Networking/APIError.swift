import Foundation

struct APIError: LocalizedError, Equatable {
    enum Kind: Equatable {
        case invalidBaseURL
        case invalidResponse
        case httpStatus(Int)
        case decoding
        case network
        case missingSession
        case authenticationFailed
        case sessionExpired
    }

    let kind: Kind
    let message: String

    var errorDescription: String? { message }

    static let invalidBaseURL = APIError(kind: .invalidBaseURL, message: "Enter a valid server URL, including http:// or https://.")
    static let invalidResponse = APIError(kind: .invalidResponse, message: "The server returned an invalid response.")
    static let missingSession = APIError(kind: .missingSession, message: "Sign in again to refresh this data.")
    static let authenticationFailed = APIError(kind: .authenticationFailed, message: "Login failed. Check the server URL and access key.")
    static let sessionExpired = APIError(kind: .sessionExpired, message: "Your session expired. Sign in again.")

    var isSessionExpired: Bool {
        if kind == .sessionExpired { return true }
        if case .httpStatus(let statusCode) = kind { return statusCode == 401 || statusCode == 403 }
        return false
    }

    static func httpStatus(_ statusCode: Int, body: Data?) -> APIError {
        _ = body
        if statusCode == 401 || statusCode == 403 {
            return sessionExpired
        }
        return APIError(kind: .httpStatus(statusCode), message: "Request failed with HTTP \(statusCode). Check the server URL, key, and session status.")
    }

    static func decoding(_ underlying: Error) -> APIError {
        _ = underlying
        return APIError(kind: .decoding, message: "The server returned unexpected data. Update the app or contact the server administrator.")
    }

    static func network(_ underlying: Error) -> APIError {
        if let apiError = underlying as? APIError {
            return apiError
        }
        _ = underlying
        return APIError(kind: .network, message: "Could not connect to the server. Check your connection and server URL.")
    }

    static func userMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.message
        }
        return "Something went wrong. Try again."
    }
}
