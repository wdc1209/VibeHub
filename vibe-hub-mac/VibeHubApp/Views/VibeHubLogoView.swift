import AppKit
import SwiftUI

struct VibeHubLogoView: View {
    private let imageName = "vibe-hub-logo.png"

    var body: some View {
        Group {
            if let nsImage = Bundle.main.image(forResource: imageName) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                fallbackMark
            }
        }
        .frame(width: 34, height: 34)
    }

    private var fallbackMark: some View {
        Image(systemName: "square.rounded.fill")
            .font(.system(size: 28, weight: .regular))
            .foregroundStyle(.gray.opacity(0.18))
    }
}
