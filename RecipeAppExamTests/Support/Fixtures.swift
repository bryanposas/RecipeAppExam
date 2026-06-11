// Support/Fixtures.swift

import Foundation
@testable import RecipeAppExam

// MARK: - Fixtures

enum Fixtures {
    static let sampleRecipes: [Recipe] = [
        Recipe(
            id: "1",
            title: "Pizza Recipe 1",
            description: "Delicious recipe",
            servings: 4,
            ingredients: ["flour", "tomato", "mozzarella"],
            instructions: ["Step 1", "Step 2"],
            dietaryAttributes: ["vegetarian", "nut-free"],
            imageURL: nil
        ),
        Recipe(
            id: "2",
            title: "Curry Recipe 2",
            description: "Spiced recipe",
            servings: 4,
            ingredients: ["chicken", "tomato", "cream"],
            instructions: ["Step 1", "Step 2"],
            dietaryAttributes: ["gluten-free", "halal", "nut-free"],
            imageURL: nil
        ),
        Recipe(
            id: "3",
            title: "Stir-Fry Recipe 3",
            description: "Quick recipe",
            servings: 2,
            ingredients: ["broccoli", "soy sauce", "ginger"],
            instructions: ["Step 1", "Step 2"],
            dietaryAttributes: ["vegan", "vegetarian", "plant-based", "dairy-free / lactose-free"],
            imageURL: nil
        ),
        Recipe(
            id: "4",
            title: "Salad Recipe 4",
            description: "Fresh recipe",
            servings: 2,
            ingredients: ["lettuce", "tomato", "cucumber"],
            instructions: ["Step 1"],
            dietaryAttributes: ["vegan", "vegetarian", "gluten-free", "dairy-free / lactose-free", "low-carb"],
            imageURL: nil
        ),
        Recipe(
            id: "5",
            title: "Burger Recipe 5",
            description: "Hearty recipe",
            servings: 4,
            ingredients: ["black beans", "breadcrumbs", "onion"],
            instructions: ["Step 1", "Step 2", "Step 3"],
            dietaryAttributes: ["vegan", "plant-based"],
            imageURL: nil
        ),
        Recipe(
            id: "6",
            title: "Salmon Recipe 6",
            description: "Light recipe",
            servings: 2,
            ingredients: ["salmon", "butter", "lemon"],
            instructions: ["Step 1", "Step 2"],
            dietaryAttributes: ["gluten-free", "low-carb", "nut-free"],
            imageURL: nil
        ),
        Recipe(
            id: "7",
            title: "Hummus Recipe 7",
            description: "Smooth dip",
            servings: 6,
            ingredients: ["chickpeas", "tahini", "lemon"],
            instructions: ["Step 1"],
            dietaryAttributes: ["vegan", "vegetarian", "plant-based", "gluten-free", "dairy-free / lactose-free"],
            imageURL: nil
        ),
        Recipe(
            id: "8",
            title: "Pasta Recipe 8",
            description: "Classic pasta",
            servings: 4,
            ingredients: ["spaghetti", "pancetta", "eggs"],
            instructions: ["Step 1", "Step 2"],
            dietaryAttributes: ["nut-free"],
            imageURL: nil
        )
    ]

    /// 20 recipes used for pagination tests (needs more than the default pageSize of 10).
    static let twentyRecipes: [Recipe] = (1...20).map { i in
        Recipe(
            id: "\(100 + i)",
            title: "Paged Recipe \(i)",
            description: "Description \(i)",
            servings: (i % 4) + 1,
            ingredients: ["ingredient \(i) a", "ingredient \(i) b", "tomato"],
            instructions: ["Step 1", "Step 2"],
            dietaryAttributes: i.isMultiple(of: 2) ? ["vegan", "gluten-free"] : ["halal"],
            imageURL: nil
        )
    }
}
