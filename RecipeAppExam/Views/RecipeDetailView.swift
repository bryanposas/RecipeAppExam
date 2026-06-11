// Views/RecipeDetailView.swift

import SwiftUI

// MARK: - RecipeDetailView

struct RecipeDetailView: View {

    let recipe: Recipe
    @ObservedObject var viewModel: RecipeListViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Hero image with heart overlay
                heroImageSection

                // Description + dietary badges
                VStack(alignment: .leading, spacing: 16) {
                    Text(recipe.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !recipe.dietaryAttributes.isEmpty {
                        DietaryAttributesWrapView(attributes: recipe.dietaryAttributes)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 24)

                // Stats strip
                metaRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)

                // Collapsible content sections
                VStack(spacing: 16) {
                    CollapsibleSection(title: "Ingredients", icon: "cart") {
                        ingredientsList
                    }
                    CollapsibleSection(title: "Instructions", icon: "list.number") {
                        instructionsList
                    }
                }
                .padding(.bottom, 48)
            }
        }
        .background(Color.appBackgroundColor.ignoresSafeArea())
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var heroImageSection: some View {
        ZStack(alignment: .topTrailing) {
            RecipeImageView(urlString: recipe.imageURL, height: 280)

            Button {
                Task {
                    await viewModel.toggleFavorite(recipe)
                }
            } label: {
                Image(systemName: viewModel.isFavorite(recipe.id) ? "heart.fill" : "heart")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(viewModel.isFavorite(recipe.id) ? .red : .white)
                    .padding(14)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var metaRow: some View {
        HStack(spacing: 0) {
            metaItem(icon: "person.2.fill", value: "\(recipe.servings)", label: "Servings")
            Divider().frame(height: 36)
            metaItem(icon: "list.bullet", value: "\(recipe.ingredients.count)", label: "Ingredients")
            Divider().frame(height: 36)
            metaItem(icon: "text.alignleft", value: "\(recipe.instructions.count)", label: "Steps")
        }
        .padding(.vertical, 16)
        .background(Color.appSurfaceColor, in: RoundedRectangle(cornerRadius: 16))
    }

    private func metaItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).foregroundStyle(Color.accentColor)
            Text(value).font(.headline)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var ingredientsList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(recipe.ingredients, id: \.self) { ingredient in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 7, height: 7)
                        .padding(.top, 7)
                    Text(ingredient)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private var instructionsList: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .center, spacing: 14) {
                    Text("\(index + 1)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.accentColor, in: Circle())

                    Text(step)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

// MARK: - CollapsibleSection

private struct CollapsibleSection<Content: View>: View {

    let title: String
    let icon: String
    @State private var isExpanded = true
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Label(title, systemImage: icon)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.up")
                        .rotationEffect(.degrees(isExpanded ? 0 : -180))
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                        .animation(.easeInOut(duration: 0.25), value: isExpanded)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.appSurfaceColor, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }
}

// MARK: - DietaryAttributesWrapView

private struct DietaryAttributesWrapView: View {

    let attributes: [String]

    var body: some View {
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
        RecipeDetailView(recipe: .previewMultiDietary, viewModel: RecipeListViewModel())
    }
}
