import SwiftUI
import UIKit

struct HaulShareCard: View {
    let title: String
    let savedCents: Int
    let photo: UIImage?
    let badgeText: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [DesignSystem.green, DesignSystem.greenDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 22) {
                HStack {
                    Text("DIBSLY")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("call dibs")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                }

                Spacer(minLength: 0)

                Group {
                    if let photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            Color.white.opacity(0.14)
                            Image(systemName: "shippingbox.fill")
                                .font(.system(size: 84))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
                .frame(width: 420, height: 420)
                .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 2)
                )

                VStack(spacing: 6) {
                    Text("I SAVED")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.8))
                    Text("$\(savedCents / 100)")
                        .font(.system(size: 96, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(title)
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 40)
                }

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.white)
                    Text(badgeText)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("Free, not forgotten.")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(44)
        }
        .frame(width: 540, height: 960)
    }
}

@MainActor
enum ShareCardRenderer {
    static func render(title: String, savedCents: Int, photo: UIImage?, badgeText: String) -> UIImage? {
        let renderer = ImageRenderer(content: HaulShareCard(
            title: title,
            savedCents: savedCents,
            photo: photo,
            badgeText: badgeText
        ))
        renderer.scale = 2.0
        return renderer.uiImage
    }

    static func writeTemporary(_ image: UIImage) -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.92) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Dibsly-Haul-\(UUID().uuidString).jpg")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
