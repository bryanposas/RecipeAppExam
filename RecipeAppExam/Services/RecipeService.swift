// Services/RecipeService.swift

import Foundation

// MARK: - RecipeServiceProtocol

protocol RecipeServiceProtocol: Sendable {
    func fetchRecipes(page: Int, pageSize: Int) async throws -> PaginatedResponse<Recipe>
    func searchRecipes(filter: RecipeFilter, page: Int, pageSize: Int) async throws -> PaginatedResponse<Recipe>
}

// MARK: - RecipeService

/// Sits between the network layer and the ViewModel.
/// Responsibilities:
///   - Loads the full dataset via the network service (mock or real)
///   - Applies in-memory filtering for search queries
///   - Slices results into pages so the ViewModel and UI stay simple
final class RecipeService: RecipeServiceProtocol {

    private let networkService: NetworkServiceProtocol

    // MARK: - Init

    init(networkService: NetworkServiceProtocol = NetworkService()) {
        self.networkService = networkService
    }

    // MARK: - RecipeServiceProtocol

    func fetchRecipes(page: Int, pageSize: Int) async throws -> PaginatedResponse<Recipe> {
        let all: [Recipe] = try await networkService.fetch(endpoint: .recipes)
        return paginate(all, page: page, pageSize: pageSize)
    }

    func searchRecipes(
        filter: RecipeFilter,
        page: Int,
        pageSize: Int
    ) async throws -> PaginatedResponse<Recipe> {
        let all: [Recipe] = try await networkService.fetch(endpoint: .searchRecipes)
        let filtered = apply(filter: filter, to: all)
        return paginate(filtered, page: page, pageSize: pageSize)
    }

    // MARK: - Private helpers

    /// Applies every active filter criterion in order.
    private func apply(filter: RecipeFilter, to recipes: [Recipe]) -> [Recipe] {
        recipes.filter { recipe in
            matchesQuery(filter.searchQuery, recipe: recipe)
                && matchesDietaryAttributes(filter.dietaryAttributes, recipe: recipe)
                && matchesServings(filter.servings, recipe: recipe)
                && matchesInclude(filter.includeIngredients, recipe: recipe)
                && matchesExclude(filter.excludeIngredients, recipe: recipe)
        }
    }

    private func matchesQuery(_ query: String, recipe: Recipe) -> Bool {
        guard !query.isEmpty else { return true }
        return recipe.title.localizedCaseInsensitiveContains(query)
            || recipe.description.localizedCaseInsensitiveContains(query)
            || recipe.instructions.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    /// Recipe must contain ALL selected dietary attributes (AND semantics).
    private func matchesDietaryAttributes(_ required: [String], recipe: Recipe) -> Bool {
        guard !required.isEmpty else { return true }
        return required.allSatisfy { required in
            recipe.dietaryAttributes.contains { $0.lowercased() == required.lowercased() }
        }
    }

    private func matchesServings(_ count: Int?, recipe: Recipe) -> Bool {
        guard let count else { return true }
        return recipe.servings == count
    }

    private func matchesInclude(_ terms: [String], recipe: Recipe) -> Bool {
        guard !terms.isEmpty else { return true }
        return terms.allSatisfy { term in
            recipe.ingredients.contains { $0.localizedCaseInsensitiveContains(term) }
        }
    }

    private func matchesExclude(_ terms: [String], recipe: Recipe) -> Bool {
        guard !terms.isEmpty else { return true }
        return !terms.contains { term in
            recipe.ingredients.contains { $0.localizedCaseInsensitiveContains(term) }
        }
    }

    /// Slices `recipes` into the requested page window.
    private func paginate(_ recipes: [Recipe], page: Int, pageSize: Int) -> PaginatedResponse<Recipe> {
        let totalCount = recipes.count
        let totalPages = totalCount == 0 ? 1 : Int(ceil(Double(totalCount) / Double(pageSize)))
        let startIndex = (page - 1) * pageSize
        let endIndex = min(startIndex + pageSize, totalCount)
        let pageData = startIndex < totalCount ? Array(recipes[startIndex..<endIndex]) : []

        return PaginatedResponse(
            data: pageData,
            page: page,
            pageSize: pageSize,
            totalCount: totalCount,
            totalPages: totalPages
        )
    }
}

// MARK: - Static Ingredient Helpers

extension RecipeService {

    // Regex patterns are extracted as named constants so each can be understood
    // and tested in isolation, and to keep function lines within lint limits.

    /// Matches a leading numeric quantity plus an optional measurement unit.
    /// \s+ after the number is mandatory — using \s* would consume the only space
    /// and leave the optional unit group with nothing to match for bare counts like "3 onions".
    private static let quantityAndUnitPattern: String = #"""
        ^\s*\d+(?:[\/\.]\d+)?\s+
        (?:(?:cups?|tbsps?|tablespoons?|tsps?|teaspoons?|lbs?|oz|g|kg|ml|l\b|
        cloves?|slices?|cans?|bunches?|sprigs?|stalks?|heads?|pieces?|
        packets?|strips?|sheets?|dashes?|pinch(?:es)?|handfuls?|pounds?)\s+)?
        """#
        .components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .joined()

    /// Matches a leading size or prep adjective (e.g. "large", "finely", "frozen").
    private static let adjectivePattern: String =
        #"^\s*(?:large|medium|small|extra-large|fresh|dried|frozen|cooked|"# +
        #"warm|cold|thin|thick|ripe|raw|boneless|peeled|skin-on|bone-in|"# +
        #"day-old|finely|coarsely|roughly|thinly|lightly)\s+"#

    /// Strips quantity, unit, and prep-note fragments from a raw ingredient string,
    /// returning just the food name (e.g. "2 large onions, finely diced" → "Onions").
    static func extractIngredientName(from raw: String) -> String {
        var name = raw.components(separatedBy: ",").first ?? raw

        // Remove parenthetical size/weight notes like "(14 oz)"
        name = name.replacingOccurrences(
            of: #"\([^)]*\)"#, with: "", options: .regularExpression
        )

        name = name.replacingOccurrences(
            of: quantityAndUnitPattern,
            with: "", options: [.regularExpression, .caseInsensitive]
        )

        name = name.replacingOccurrences(
            of: adjectivePattern,
            with: "", options: [.regularExpression, .caseInsensitive]
        )

        return name.trimmingCharacters(in: .whitespaces).capitalized
    }

    /// Extracts, deduplicates, and sorts all ingredient names from a recipe collection.
    static func allIngredientNames(from recipes: [Recipe]) -> [String] {
        let names = recipes
            .flatMap { $0.ingredients }
            .map { extractIngredientName(from: $0) }
            .filter { $0.count >= 3 }
        return Array(Set(names)).sorted()
    }
}
