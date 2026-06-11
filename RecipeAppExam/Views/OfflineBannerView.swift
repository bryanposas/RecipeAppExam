// Views/OfflineBannerView.swift

import SwiftUI

// MARK: - OfflineBannerView

/// Dismissable banner displayed at the top of the screen when the device
/// has no internet connection. Kept as a separate component so it can be
/// dropped onto any screen that needs offline awareness.
struct OfflineBannerView: View {

    @Binding var isDismissed: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(.white)

            Text("No internet connection. Showing cached data.")
                .font(.subheadline)
                .foregroundStyle(.white)

            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.25)) {
                    isDismissed = true
                }
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.white)
                    .padding(4)
            }
            .accessibilityLabel("Dismiss offline banner")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.accentColor)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Preview

#Preview {
    VStack {
        OfflineBannerView(isDismissed: .constant(false))
        Spacer()
    }
}
