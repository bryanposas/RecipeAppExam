// Models/DietaryAttribute.swift

import SwiftUI

// MARK: - DietaryAttribute

/// Canonical set of dietary labels that can appear in a recipe's
/// `dietaryAttributes` array.
///
/// The raw value is the exact lowercase string used in JSON and persisted to
/// CoreData, so the app stays consistent end-to-end without any extra mapping.
///
/// Adding a new attribute only requires:
///   1. A new case here
///   2. Adding the string to the JSON dataset
enum DietaryAttribute: String, CaseIterable, Identifiable {

    case glutenFree     = "gluten-free"
    case dairyFree      = "dairy-free / lactose-free"
    case nutFree        = "nut-free"
    case lowFODMAP      = "low-fodmap"
    case sugarFree      = "sugar-free"
    case lowSodium      = "sodium-free / low-sodium"
    case lowFat         = "fat-free / low-fat"
    case lowCarb        = "low-carb"
    case vegetarian     = "vegetarian"
    case vegan          = "vegan"
    case plantBased     = "plant-based"
    case paleo          = "paleo"
    case halal          = "halal"
    case kosher         = "kosher"

    var id: String { rawValue }

    // MARK: - Display

    var displayName: String {
        switch self {
        case .glutenFree:  return "Gluten-Free"
        case .dairyFree:   return "Dairy-Free"
        case .nutFree:     return "Nut-Free"
        case .lowFODMAP:   return "Low-FODMAP"
        case .sugarFree:   return "Sugar-Free"
        case .lowSodium:   return "Low-Sodium"
        case .lowFat:      return "Low-Fat"
        case .lowCarb:     return "Low-Carb"
        case .vegetarian:  return "Vegetarian"
        case .vegan:       return "Vegan"
        case .plantBased:  return "Plant-Based"
        case .paleo:       return "Paleo"
        case .halal:       return "Halal"
        case .kosher:      return "Kosher"
        }
    }

    var systemImage: String {
        switch self {
        case .vegetarian, .vegan, .plantBased, .paleo:
            return "leaf.fill"
        case .glutenFree:
            return "g.circle.fill"
        case .dairyFree:
            return "drop.triangle.fill"
        case .nutFree:
            return "exclamationmark.shield.fill"
        case .lowCarb, .lowFat, .lowFODMAP:
            return "arrow.down.heart.fill"
        case .sugarFree, .lowSodium:
            return "minus.circle.fill"
        case .halal:
            return "staroflife.fill"
        case .kosher:
            return "star.fill"
        }
    }

    var color: Color {
        switch self {
        case .vegetarian, .vegan, .plantBased, .paleo:
            return .green
        case .glutenFree:
            return .orange
        case .dairyFree:
            return .indigo
        case .nutFree:
            return .brown
        case .lowCarb, .lowFat, .lowFODMAP:
            return .teal
        case .sugarFree, .lowSodium:
            return .mint
        case .halal, .kosher:
            return .purple
        }
    }
}
