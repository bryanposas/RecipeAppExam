// Models/Recipe.swift

import Foundation

// MARK: - Recipe

/// Domain model representing a single recipe entry.
/// Structured as a value type for safe sharing across threads.
struct Recipe: Identifiable, Codable, Hashable {

    let id: String
    let title: String
    let description: String
    let servings: Int
    let ingredients: [String]
    let instructions: [String]
    /// Lowercase dietary labels sourced from `DietaryAttribute.rawValue`.
    /// An empty array means no dietary information is available.
    let dietaryAttributes: [String]
    let imageURL: String?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case servings
        case ingredients
        case instructions
        case dietaryAttributes = "dietary_attributes"
        case imageURL = "image_url"
    }
}
