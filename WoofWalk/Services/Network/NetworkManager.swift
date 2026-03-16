import Foundation

class NetworkManager {
    static let shared = NetworkManager()

    private let session: URLSession
    private let cache = URLCache(
        memoryCapacity: 20 * 1024 * 1024,
        diskCapacity: 100 * 1024 * 1024
    )

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        config.urlCache = cache
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.httpMaximumConnectionsPerHost = 5
        config.waitsForConnectivity = true
        config.httpAdditionalHeaders = [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]

        self.session = URLSession(configuration: config)
    }

    func request<T: Decodable>(
        url: URL,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        body: Encodable? = nil,
        cachePolicy: URLRequest.CachePolicy = .returnCacheDataElseLoad,
        retryCount: Int = 2
    ) async throws -> T {
        var request = URLRequest(url: url, cachePolicy: cachePolicy)
        request.httpMethod = method.rawValue

        if let parameters = parameters, method == .get {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
            if let urlWithParams = components?.url {
                request.url = urlWithParams
            }
        }

        if let body = body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                throw NetworkError.encodingError(error)
            }
        }

        return try await performRequest(request: request, retryCount: retryCount)
    }

    private func performRequest<T: Decodable>(
        request: URLRequest,
        retryCount: Int
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0...retryCount {
            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    throw NetworkError.httpError(statusCode: httpResponse.statusCode)
                }

                do {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    return try decoder.decode(T.self, from: data)
                } catch {
                    throw NetworkError.decodingError(error)
                }
            } catch let error as URLError {
                lastError = error
                if error.code == .timedOut {
                    lastError = NetworkError.timeout
                } else if error.code == .notConnectedToInternet {
                    lastError = NetworkError.noConnection
                } else {
                    lastError = NetworkError.unknown(error)
                }

                if attempt < retryCount {
                    let delay = UInt64(pow(2.0, Double(attempt)) * 1_000_000_000)
                    try await Task.sleep(nanoseconds: delay)
                    continue
                }
            } catch {
                lastError = error
                if attempt < retryCount {
                    let delay = UInt64(pow(2.0, Double(attempt)) * 1_000_000_000)
                    try await Task.sleep(nanoseconds: delay)
                    continue
                }
            }
        }

        throw lastError ?? NetworkError.unknown(NSError(domain: "", code: -1))
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}
