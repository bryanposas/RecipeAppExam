// NetworkServiceTests.swift

import Foundation
import Testing
@testable import RecipeAppExam

// MARK: - Suite: Network Error

@Suite("Network Error")
struct NetworkErrorTests {

    @Test("resourceNotFound errorDescription contains the resource name")
    func resourceNotFoundDescription() {
        let error = NetworkError.resourceNotFound("recipes")
        #expect(error.errorDescription?.contains("recipes") == true)
    }

    @Test("decodingFailed errorDescription is non-nil")
    func decodingFailedDescription() {
        let inner = NSError(domain: "test", code: 0, userInfo: [NSLocalizedDescriptionKey: "bad json"])
        let error = NetworkError.decodingFailed(inner)
        #expect(error.errorDescription != nil)
    }

    @Test("networkUnavailable errorDescription is non-nil")
    func networkUnavailableDescription() {
        #expect(NetworkError.networkUnavailable.errorDescription != nil)
    }

    @Test("unknown errorDescription forwards the underlying error message")
    func unknownDescription() {
        let inner = NSError(domain: "test", code: 99, userInfo: [NSLocalizedDescriptionKey: "connection reset"])
        let error = NetworkError.unknown(inner)
        #expect(error.errorDescription?.contains("connection reset") == true)
    }

    @Test("serverError errorDescription contains the HTTP status code")
    func serverErrorDescription() {
        let error = NetworkError.serverError(statusCode: 404)
        #expect(error.errorDescription?.contains("404") == true)
    }

    @Test("Every NetworkError case produces a non-nil errorDescription")
    func allCasesHaveNonNilDescription() {
        let errors: [NetworkError] = [
            .resourceNotFound("x"),
            .decodingFailed(NSError(domain: "x", code: 0)),
            .networkUnavailable,
            .serverError(statusCode: 500),
            .unknown(NSError(domain: "x", code: 0))
        ]
        #expect(errors.allSatisfy { $0.errorDescription != nil })
    }
}

// MARK: - Suite: API Endpoint

@Suite("API Endpoint")
struct APIEndpointTests {

    @Test("recipes endpoint maps to the 'recipes' JSON resource")
    func recipesResourceName() {
        #expect(APIEndpoint.recipes.resourceName == "recipes")
    }

    @Test("searchRecipes endpoint maps to the same 'recipes' JSON resource")
    func searchRecipesResourceName() {
        #expect(APIEndpoint.searchRecipes.resourceName == "recipes")
    }

    @Test("recipes endpoint path starts with a forward slash")
    func recipesPathFormat() {
        #expect(APIEndpoint.recipes.path.hasPrefix("/"))
    }

    @Test("searchRecipes endpoint path starts with a forward slash")
    func searchRecipesPathFormat() {
        #expect(APIEndpoint.searchRecipes.path.hasPrefix("/"))
    }
}
