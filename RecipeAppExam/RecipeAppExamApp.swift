// RecipeAppExamApp.swift

import SwiftUI

// MARK: - RecipeAppExamApp

@main
struct RecipeAppExamApp: App {

    private let favorites = FavoritesService.shared

    var body: some Scene {
        WindowGroup {
            RecipeListView()
                .environmentObject(favorites)
        }
    }
}
