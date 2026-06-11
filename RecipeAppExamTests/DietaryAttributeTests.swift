// DietaryAttributeTests.swift

import Foundation
import Testing
@testable import RecipeAppExam

// MARK: - Suite: Dietary Attribute

@Suite("Dietary Attribute")
struct DietaryAttributeTests {

    @Test("All cases have a non-empty displayName")
    func allCasesHaveDisplayName() {
        #expect(DietaryAttribute.allCases.allSatisfy { !$0.displayName.isEmpty })
    }

    @Test("All cases have a non-empty systemImage")
    func allCasesHaveSystemImage() {
        #expect(DietaryAttribute.allCases.allSatisfy { !$0.systemImage.isEmpty })
    }

    @Test("rawValue matches the expected lowercase JSON string")
    func vegetarianRawValue() {
        #expect(DietaryAttribute.vegetarian.rawValue == "vegetarian")
        #expect(DietaryAttribute.dairyFree.rawValue == "dairy-free / lactose-free")
        #expect(DietaryAttribute.glutenFree.rawValue == "gluten-free")
    }

    @Test("String extension resolves known rawValues to the correct case")
    func stringExtensionResolvesKnownValues() {
        #expect("vegetarian".asDietaryAttribute == .vegetarian)
        #expect("gluten-free".asDietaryAttribute == .glutenFree)
        #expect("vegan".asDietaryAttribute == .vegan)
    }

    @Test("String extension returns nil for unknown values")
    func stringExtensionReturnsNilForUnknown() {
        #expect("unknown-attribute".asDietaryAttribute == nil)
        #expect("".asDietaryAttribute == nil)
    }

    @Test(
        "Well-known attributes resolve correctly from raw string",
        arguments: DietaryAttribute.allCases
    )
    func roundTripsFromRawValue(_ attribute: DietaryAttribute) {
        let resolved = attribute.rawValue.asDietaryAttribute
        #expect(resolved == attribute)
    }
}
