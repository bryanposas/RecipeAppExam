// Views/SearchFilterView.swift

import SwiftUI

// MARK: - SearchFilterView

/// Modal sheet exposing all `RecipeFilter` parameters.
/// Edits a local copy; only applies on "Apply" so the user can cancel
/// without triggering a network fetch.
struct SearchFilterView: View {

    @Binding var filter: RecipeFilter
    @Environment(\.dismiss) private var dismiss

    // Local draft — only committed when the user taps Apply.
    @State private var draft: RecipeFilter

    // Ingredient input helpers.
    @State private var includeText: String = ""
    @State private var excludeText: String = ""

    // MARK: - Init

    init(filter: Binding<RecipeFilter>) {
        _filter = filter
        _draft = State(initialValue: filter.wrappedValue)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Dietary Attributes
                Section {
                    dietaryAttributesGrid
                } header: {
                    Text("Dietary Attributes")
                } footer: {
                    Text("Recipe must match ALL selected attributes.")
                        .font(.caption)
                }

                // MARK: Servings
                Section("Servings") {
                    servingsPicker
                }

                // MARK: Include Ingredients
                Section {
                    ingredientInputRow(
                        label: "Add ingredient to include",
                        text: $includeText
                    ) {
                        let trimmed = includeText.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        draft.includeIngredients.append(trimmed)
                        includeText = ""
                    }
                    ForEach(draft.includeIngredients, id: \.self) { item in
                        Text(item).foregroundStyle(.primary)
                    }
                    .onDelete { draft.includeIngredients.remove(atOffsets: $0) }
                } header: {
                    Text("Must Include Ingredients")
                }

                // MARK: Exclude Ingredients
                Section {
                    ingredientInputRow(
                        label: "Add ingredient to exclude",
                        text: $excludeText
                    ) {
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

                // MARK: Reset
                Section {
                    Button("Reset All Filters", role: .destructive) {
                        draft = RecipeFilter()
                        includeText = ""
                        excludeText = ""
                    }
                }
            }
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

    // MARK: - Subviews

    /// Adaptive two-column grid of toggle rows, one per dietary attribute.
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
                value: Binding(
                    get: { servings },
                    set: { draft.servings = $0 }
                ),
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
            TextField(label, text: text)
                .onSubmit(onAdd)
            Button("Add", action: onAdd)
                .disabled(text.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // MARK: - Helpers

    private func toggleAttribute(_ attribute: DietaryAttribute) {
        if let index = draft.dietaryAttributes.firstIndex(of: attribute.rawValue) {
            draft.dietaryAttributes.remove(at: index)
        } else {
            draft.dietaryAttributes.append(attribute.rawValue)
        }
    }
}

// MARK: - Preview

#Preview {
    SearchFilterView(filter: .constant(RecipeFilter()))
}
