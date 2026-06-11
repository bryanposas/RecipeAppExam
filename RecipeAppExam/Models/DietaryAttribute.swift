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
        case .glutenFree:  return String(localized: "dietary.glutenFree")
        case .dairyFree:   return String(localized: "dietary.dairyFree")
        case .nutFree:     return String(localized: "dietary.nutFree")
        case .lowFODMAP:   return String(localized: "dietary.lowFODMAP")
        case .sugarFree:   return String(localized: "dietary.sugarFree")
        case .lowSodium:   return String(localized: "dietary.lowSodium")
        case .lowFat:      return String(localized: "dietary.lowFat")
        case .lowCarb:     return String(localized: "dietary.lowCarb")
        case .vegetarian:  return String(localized: "dietary.vegetarian")
        case .vegan:       return String(localized: "dietary.vegan")
        case .plantBased:  return String(localized: "dietary.plantBased")
        case .paleo:       return String(localized: "dietary.paleo")
        case .halal:       return String(localized: "dietary.halal")
        case .kosher:      return String(localized: "dietary.kosher")
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
