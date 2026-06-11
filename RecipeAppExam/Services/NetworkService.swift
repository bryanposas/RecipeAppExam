// Services/NetworkService.swift

import Foundation

// MARK: - NetworkError

enum NetworkError: Error, LocalizedError {
    case resourceNotFound(String)
    case decodingFailed(Error)
    case networkUnavailable
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .resourceNotFound(let name):
            return "Local resource '\(name).json' not found in bundle."
        case .decodingFailed(let error):
            return "JSON decoding failed: \(error.localizedDescription)"
        case .networkUnavailable:
            return "No internet connection. Showing cached data."
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

// MARK: - MockNetworkService

/// Simulates a remote API by loading JSON bundles from the app target.
/// The artificial delay keeps timing behaviour realistic and makes loading
/// states observable during UI testing.
final class MockNetworkService: NetworkServiceProtocol {

    private let decoder: JSONDecoder
    private let simulatedLatency: UInt64

    // MARK: - Init

    init(simulatedLatency: UInt64 = 400_000_000) {
        self.simulatedLatency = simulatedLatency
        decoder = JSONDecoder()
    }

    // MARK: - NetworkServiceProtocol

    func fetch<T: Decodable & Sendable>(endpoint: APIEndpoint) async throws -> T {
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
