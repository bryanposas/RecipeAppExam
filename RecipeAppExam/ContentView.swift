// ContentView.swift

import SwiftUI

// MARK: - ContentView

/// Thin shell kept for Xcode project compatibility.
/// All UI logic lives in RecipeListView and its sub-views.
struct ContentView: View {
    var body: some View {
        RecipeListView()
    }
}

#Preview {
    ContentView()
}
