// Views/WelcomeView.swift

import SwiftUI

// MARK: - WelcomeView

struct WelcomeView: View {

    @State private var splashVisible = true
    @State private var logoScale: CGFloat = 0.7
    @State private var contentOpacity: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            RecipeListView()

            if splashVisible {
                splash
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear(perform: runSplash)
    }

    // MARK: - Splash overlay

    private var splash: some View {
        ZStack {
            Color.accentColor.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 96, weight: .ultraLight))
                    .foregroundStyle(.white)
                    .scaleEffect(logoScale)
                    .padding(.bottom, 24)

                Text("RecipeApp")
                    .font(.system(size: 34, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .padding(.bottom, 8)

                Text("Discover & Cook")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))

                Spacer()
                Spacer()
            }
            .opacity(contentOpacity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("RecipeApp — Discover & Cook")
        .accessibilityAddTraits(.isStaticText)
    }

    // MARK: - Animation

    private func runSplash() {
        if reduceMotion {
            logoScale = 1
            contentOpacity = 1
        } else {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
                logoScale = 1
            }
            withAnimation(.easeOut(duration: 0.45)) {
                contentOpacity = 1
            }
        }

        Task {
            try? await Task.sleep(for: .seconds(2.2))
            await MainActor.run {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.45)) {
                    splashVisible = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    WelcomeView()
}
