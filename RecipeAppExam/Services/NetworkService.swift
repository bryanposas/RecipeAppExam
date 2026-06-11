// Services/NetworkService.swift

import Foundation

// MARK: - NetworkError

enum NetworkError: Error, LocalizedError {
    case resourceNotFound(String)
    case decodingFailed(Error)
    case networkUnavailable
    case serverError(statusCode: Int)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .resourceNotFound(let name):
            return "Resource '\(name)' not found."
        case .decodingFailed(let error):
            return "JSON decoding failed: \(error.localizedDescription)"
        case .networkUnavailable:
            return "No internet connection. Showing cached data."
        case .serverError(let code):
            return "Server returned an error (HTTP \(code))."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - APIEndpoint

/// Enumerates all endpoints the app can call.
/// Adding a new endpoint only requires extending this enum and adding a
/// matching resource file — no changes to callers.
enum APIEndpoint {
    case recipes
    case searchRecipes

    /// URL path appended to `baseURL` in live mode.
    var path: String {
        switch self {
        case .recipes, .searchRecipes:
            return "/recipes"
        }
    }

    /// Bundle resource name used in bundle mode when no `baseURL` is configured.
    var resourceName: String {
        switch self {
        case .recipes, .searchRecipes:
            return "recipes"
        }
    }
}

// MARK: - NetworkServiceProtocol

protocol NetworkServiceProtocol: Sendable {
    /// Generic fetch that decodes the response directly into `T`.
    func fetch<T: Decodable & Sendable>(endpoint: APIEndpoint) async throws -> T
}

// MARK: - NetworkService

/// Unified network layer that operates in two modes:
///
/// - **Bundle mode** (default, `baseURL == nil`): loads JSON from the app bundle with a
///   simulated latency so loading states are exercisable during development.
/// - **Live mode** (`baseURL` supplied): makes real `URLSession` HTTP requests.
///   To point the app at a real API, pass the base URL at the call site:
///   `RecipeService(networkService: NetworkService(baseURL: URL(string: "https://api.example.com")!))`
///   No other changes are required.
final class NetworkService: NetworkServiceProtocol {

    private let baseURL: URL?
    private let session: URLSession
    private let decoder: JSONDecoder
    private let simulatedLatency: UInt64

    // MARK: - Init

    init(
        baseURL: URL? = nil,
        session: URLSession = .shared,
        simulatedLatency: UInt64 = 400_000_000
    ) {
        self.baseURL = baseURL
        self.session = session
        self.simulatedLatency = simulatedLatency
        decoder = JSONDecoder()
    }

    // MARK: - NetworkServiceProtocol

    func fetch<T: Decodable & Sendable>(endpoint: APIEndpoint) async throws -> T {
        if let baseURL {
            return try await fetchLive(endpoint: endpoint, baseURL: baseURL)
        } else {
            return try await fetchBundle(endpoint: endpoint)
        }
    }

    // MARK: - Private

    private func fetchLive<T: Decodable & Sendable>(endpoint: APIEndpoint, baseURL: URL) async throws -> T {
        let url = baseURL.appending(path: endpoint.path)
        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw NetworkError.serverError(statusCode: http.statusCode)
            }
            return try decoder.decode(T.self, from: data)
        } catch let error as NetworkError {
            throw error
        } catch let decodingError as DecodingError {
            throw NetworkError.decodingFailed(decodingError)
        } catch let urlError as URLError
            where urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
            throw NetworkError.networkUnavailable
        } catch {
            throw NetworkError.unknown(error)
        }
    }

    private func fetchBundle<T: Decodable & Sendable>(endpoint: APIEndpoint) async throws -> T {
        try await Task.sleep(nanoseconds: simulatedLatency)
        guard let url = Bundle.main.url(forResource: endpoint.resourceName, withExtension: "json") else {
            throw NetworkError.resourceNotFound(endpoint.resourceName)
        }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(T.self, from: data)
        } catch let decodingError as DecodingError {
            throw NetworkError.decodingFailed(decodingError)
        } catch {
            throw NetworkError.unknown(error)
        }
    }
}
