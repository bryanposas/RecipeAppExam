// Views/SearchFilterView.swift

import SwiftUI

// MARK: - SearchFilterView

/// Modal sheet exposing all `RecipeFilter` parameters.
/// Edits a local draft; only commits on "Apply" to avoid mid-edit fetches.
struct SearchFilterView: View {

    @Binding var filter: RecipeFilter
    var availableIngredients: [String] = []
    @Environment(\.dismiss) private var dismiss

    @State private var draft: RecipeFilter
    @State private var excludeText: String = ""
    @State private var ingredientSearch: String = ""

    // MARK: - Init

    init(filter: Binding<RecipeFilter>, availableIngredients: [String] = []) {
        _filter = filter
        _draft = State(initialValue: filter.wrappedValue)
        self.availableIngredients = availableIngredients
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // Dietary attributes
                Section {
                    dietaryAttributesGrid
                } header: {
                    Text("Dietary Attributes")
                } footer: {
                    Text("Recipe must match ALL selected attributes.")
                        .font(.caption)
                }

                // Servings
                Section("Servings") {
                    servingsPicker
                }

                // Include ingredients — chip picker
                Section {
                    ingredientPickerSection
                } header: {
                    Text("Must Include Ingredients")
                } footer: {
                    if !draft.includeIngredients.isEmpty {
                        Text("filter_include_footer \(draft.includeIngredients.count)")
                            .font(.caption)
                    }
                }

                // Exclude ingredients — text input
                Section {
                    ingredientInputRow(label: "Add ingredient to exclude", text: $excludeText) {
                        let trimmed = excludeText.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        draft.excludeIngredients.append(trimmed)
                        excludeText = ""
                    }
                    ForEach(draft.excludeIngredients, id: \.self) { item in
                        Text(item).foregroundStyle(.primary)
                    }
                    .onDelete { draft.excludeIngredients.remove(atOffsets: $0) }
                } header: {
                    Text("Must Exclude Ingredients")
                }

                // Reset
                Section {
                    Button("Reset All Filters", role: .destructive) {
                        draft = RecipeFilter()
                        excludeText = ""
                        ingredientSearch = ""
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackgroundColor)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        filter = draft
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }

    // MARK: - Ingredient Chip Picker

    @ViewBuilder
    private var ingredientPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Search within available ingredients
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search ingredients", text: $ingredientSearch)
                    .autocorrectionDisabled()
                if !ingredientSearch.isEmpty {
                    Button {
                        ingredientSearch = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.appSurfaceColor, in: RoundedRectangle(cornerRadius: 10))

            // Selected chips
            if !draft.includeIngredients.isEmpty {
                Text("Selected")
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)

                ingredientChipGrid(items: draft.includeIngredients, isSelected: true)
            }

            // Suggestion chips
            let suggestions = filteredSuggestions
            if !suggestions.isEmpty {
                Text(draft.includeIngredients.isEmpty ? "Ingredients" : "Add more")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                ingredientChipGrid(items: suggestions, isSelected: false)
            } else if !ingredientSearch.isEmpty {
                Text("No matching ingredients found.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if availableIngredients.isEmpty {
                Text("Ingredient suggestions load as recipes are fetched.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 12, trailing: 16))
    }

    private var filteredSuggestions: [String] {
        let unselected = availableIngredients.filter { !draft.includeIngredients.contains($0) }
        guard !ingredientSearch.isEmpty else { return Array(unselected.prefix(40)) }
        return Array(
            unselected
                .filter { $0.localizedCaseInsensitiveContains(ingredientSearch) }
                .prefix(40)
        )
    }

    private func ingredientChipGrid(items: [String], isSelected: Bool) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 80, maximum: 160), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(items, id: \.self) { item in
                IngredientChip(name: item, isSelected: isSelected) {
                    if isSelected {
                        draft.includeIngredients.removeAll { $0 == item }
                    } else {
                        draft.includeIngredients.append(item)
                    }
                }
            }
        }
    }

    // MARK: - Dietary & Servings

    @ViewBuilder
    private var dietaryAttributesGrid: some View {
        ForEach(DietaryAttribute.allCases) { attribute in
            let isSelected = draft.dietaryAttributes.contains(attribute.rawValue)

            Button {
                toggleAttribute(attribute)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: attribute.systemImage)
                        .foregroundStyle(isSelected ? .white : attribute.color)
                        .frame(width: 20)

                    Text(attribute.displayName)
                        .foregroundStyle(isSelected ? .white : .primary)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.white)
                            .font(.caption.bold())
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    isSelected ? attribute.color : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8)
                )
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
            .accessibilityLabel("\(attribute.displayName), \(isSelected ? "selected" : "not selected")")
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        }
    }

    @ViewBuilder
    private var servingsPicker: some View {
        Toggle("Filter by servings", isOn: Binding(
            get: { draft.servings != nil },
            set: { draft.servings = $0 ? 2 : nil }
        ))

        if let servings = draft.servings {
            Stepper(
                "Servings: \(servings)",
                value: Binding(get: { servings }, set: { draft.servings = $0 }),
                in: 1...20
            )
        }
    }

    @ViewBuilder
    private func ingredientInputRow(
        label: String,
        text: Binding<String>,
        onAdd: @escaping () -> Void
    ) -> some View {
        HStack {
            TextField(label, text: text).onSubmit(onAdd)
            Button("Add", action: onAdd)
                .disabled(text.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func toggleAttribute(_ attribute: DietaryAttribute) {
        if let index = draft.dietaryAttributes.firstIndex(of: attribute.rawValue) {
            draft.dietaryAttributes.remove(at: index)
        } else {
            draft.dietaryAttributes.append(attribute.rawValue)
        }
    }
}

// MARK: - IngredientChip

private struct IngredientChip: View {

    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "xmark").font(.caption2.bold())
                }
                Text(name).font(.caption.bold()).lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(
                isSelected ? Color.accentColor : Color.appSurfaceColor,
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    SearchFilterView(
        filter: .constant(RecipeFilter()),
        availableIngredients: [
            "Chicken", "Onion", "Garlic", "Tomatoes", "Pasta", "Olive Oil",
            "Cheese", "Eggs", "Flour", "Butter", "Rice", "Spinach",
            "Mushrooms", "Bell Pepper", "Cumin", "Ginger", "Coconut Milk",
            "Lemon", "Basil", "Parmesan"
        ]
    )
}
