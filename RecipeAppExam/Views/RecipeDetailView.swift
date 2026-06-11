// Views/RecipeDetailView.swift

import SwiftUI

// MARK: - RecipeDetailView

/// Full-detail view for a single recipe. Presents every data field in a
/// scannable, section-based layout. Kept read-only — no editing in v1.
struct RecipeDetailView: View {

    let recipe: Recipe

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: Hero image
                RecipeImageView(urlString: recipe.imageURL, height: 260)

                // MARK: Hero section
                heroSection

                Divider().padding(.vertical, 8)

                // MARK: Meta row
                metaRow
                    .padding(.horizontal, 16)

                Divider().padding(.vertical, 8)

                // MARK: Ingredients
                SectionHeaderView(title: "Ingredients", systemImage: "cart")
                ingredientsList

                Divider().padding(.vertical, 8)

                // MARK: Instructions
                SectionHeaderView(title: "Instructions", systemImage: "list.number")
                instructionsList
                    .padding(.bottom, 24)
            }
        }
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recipe.description)
                .font(.body)
                .foregroundStyle(.secondary)

            if !recipe.dietaryAttributes.isEmpty {
                DietaryAttributesWrapView(attributes: recipe.dietaryAttributes)
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private var metaRow: some View {
        HStack(spacing: 24) {
            MetaItemView(
                icon: "person.2.fill",
                value: "\(recipe.servings)",
                label: "Servings"
            )
            MetaItemView(
                icon: "list.bullet",
                value: "\(recipe.ingredients.count)",
                label: "Ingredients"
            )
            MetaItemView(
                icon: "text.alignleft",
                value: "\(recipe.instructions.count)",
                label: "Steps"
            )
            Spacer()
        }
    }

    @ViewBuilder
    private var ingredientsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(recipe.ingredients, id: \.self) { ingredient in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                    Text(ingredient)
                        .font(.body)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var instructionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Color.accentColor, in: Circle())

                    Text(step)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - SectionHeaderView

private struct SectionHeaderView: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
    }
}

// MARK: - MetaItemView

private struct MetaItemView: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .foregroundStyle(.primary)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - DietaryAttributesWrapView

/// Wrapping flow layout that shows every dietary attribute chip for a recipe.
/// Uses a lazy grid so it naturally fills available width and wraps to new rows.
private struct DietaryAttributesWrapView: View {

    let attributes: [String]

    var body: some View {
        // LazyVGrid with adaptive columns provides the wrapping behaviour.
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 90), spacing: 6)],
            alignment: .leading,
            spacing: 6
        ) {
            ForEach(attributes, id: \.self) { raw in
                DietaryBadgeView(rawValue: raw)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RecipeDetailView(recipe: .previewMultiDietary)
    }
}
