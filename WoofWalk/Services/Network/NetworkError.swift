import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case encodingError(Error)
    case noData
    case serverError(message: String)
    case timeout
    case noConnection
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .noData:
            return "No data received"
        case .serverError(let message):
            return "Server error: \(message)"
        case .timeout:
            return "Request timeout"
        case .noConnection:
            return "No internet connection"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}
