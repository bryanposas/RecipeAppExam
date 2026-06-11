// Models/RecipeFilter.swift

import Foundation

// MARK: - RecipeFilter

/// Value type that carries all search / filter parameters.
/// Keeping this as a struct means the ViewModel can diff old vs. new values
/// cheaply and re-trigger fetches only when something actually changed.
struct RecipeFilter: Equatable {

    var searchQuery: String = ""

    /// Recipe must possess ALL of the selected dietary attributes (AND logic).
    /// An empty set means "no dietary filter applied".
    var dietaryAttributes: [String] = []

    /// `nil` means "don't filter by servings count".
    var servings: Int? = nil

    /// Recipe must contain ALL of these ingredient substrings.
    var includeIngredients: [String] = []

    /// Recipe must contain NONE of these ingredient substrings.
    var excludeIngredients: [String] = []

    // MARK: - Computed

    /// Returns `true` when at least one filter criterion is active.
    var isActive: Bool {
        !searchQuery.isEmpty
            || !dietaryAttributes.isEmpty
            || servings != nil
            || !includeIngredients.isEmpty
            || !excludeIngredients.isEmpty
    }

    /// Count of filter-sheet criteria only (excludes search query).
    /// Used to badge the filter button so the user knows filters are active.
    var activeFilterCount: Int {
        dietaryAttributes.count
        + (servings != nil ? 1 : 0)
        + includeIngredients.count
        + excludeIngredients.count
    }
}
