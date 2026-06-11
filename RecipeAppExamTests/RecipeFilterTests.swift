// RecipeFilterTests.swift

import Foundation
import Testing
@testable import RecipeAppExam

// MARK: - Suite: Recipe Filter

@Suite("Recipe Filter")
struct RecipeFilterTests {

    @Test("Default filter with no criteria set is not active")
    func defaultIsNotActive() {
        #expect(!RecipeFilter().isActive)
    }

    @Test(
        "Filter becomes active when any single criterion is set",
        arguments: ["searchQuery", "dietaryAttributes", "servings", "includeIngredients", "excludeIngredients"]
    )
    func isActive(criterion: String) {
        var filter = RecipeFilter()
        switch criterion {
        case "searchQuery":         filter.searchQuery = "pasta"
        case "dietaryAttributes":   filter.dietaryAttributes = ["vegan"]
        case "servings":            filter.servings = 2
        case "includeIngredients":  filter.includeIngredients = ["tomato"]
        default:                    filter.excludeIngredients = ["garlic"]
        }
        #expect(filter.isActive)
    }

    @Test("Resetting all criteria makes the filter inactive again")
    func resetBecomesInactive() {
        var filter = RecipeFilter()
        filter.searchQuery = "pasta"
        filter.dietaryAttributes = ["vegan"]

        filter = RecipeFilter()

        #expect(!filter.isActive)
    }

    @Test("Adding multiple dietary attributes are all reflected in isActive")
    func multipleDietaryAttributesActive() {
        var filter = RecipeFilter()
        filter.dietaryAttributes = ["vegan", "gluten-free", "halal"]
        #expect(filter.isActive)
        #expect(filter.dietaryAttributes.count == 3)
    }

    // MARK: activeFilterCount

    @Test("Default filter has activeFilterCount of zero")
    func activeFilterCountDefaultIsZero() {
        #expect(RecipeFilter().activeFilterCount == 0)
    }

    @Test("Search query alone does not increment activeFilterCount")
    func searchQueryDoesNotIncrementActiveFilterCount() {
        var filter = RecipeFilter()
        filter.searchQuery = "pasta"
        #expect(filter.activeFilterCount == 0)
    }

    @Test("Each dietary attribute increments activeFilterCount by one")
    func dietaryAttributeIncrementsCount() {
        var filter = RecipeFilter()
        filter.dietaryAttributes = ["vegan", "halal"]
        #expect(filter.activeFilterCount == 2)
    }

    @Test("Servings filter increments activeFilterCount by one")
    func servingsIncrementsCount() {
        var filter = RecipeFilter()
        filter.servings = 4
        #expect(filter.activeFilterCount == 1)
    }

    @Test("Include and exclude ingredients both contribute to activeFilterCount")
    func ingredientsIncrementCount() {
        var filter = RecipeFilter()
        filter.includeIngredients = ["garlic", "onion"]
        filter.excludeIngredients = ["nuts"]
        #expect(filter.activeFilterCount == 3)
    }

    @Test("activeFilterCount sums all filter-sheet criteria correctly")
    func activeFilterCountSumsAllCriteria() {
        var filter = RecipeFilter()
        filter.searchQuery = "pasta"          // not counted
        filter.dietaryAttributes = ["vegan"]  // +1
        filter.servings = 2                   // +1
        filter.includeIngredients = ["flour"] // +1
        filter.excludeIngredients = ["nuts"]  // +1
        #expect(filter.activeFilterCount == 4)
    }
}
