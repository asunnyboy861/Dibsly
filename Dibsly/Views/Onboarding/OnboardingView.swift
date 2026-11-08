import SwiftUI

struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var showDetails = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [DesignSystem.green, DesignSystem.greenDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 18) {
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(28)
                        .background(Circle().fill(.white.opacity(0.16)))

                    Text("Call dibs on\nfree stuff")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Neighbors give away furniture, electronics, baby gear and more. See what is free near you and claim it before someone else does.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                Spacer()

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "location.fill")
                            .foregroundStyle(DesignSystem.green)
                        Text("We only save a coarse neighborhood grid. Exact addresses stay private.")
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.95)))

                    Button {
                        env.location.requestPermission()
                        env.markOnboarded()
                    } label: {
                        Text("Enable location and start")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(DesignSystem.greenDeep)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(Capsule().fill(.white))
                    }
                    .accessibilityLabel("Enable location and start")

                    Button {
                        env.location.applyFallbackCity()
                        env.markOnboarded()
                    } label: {
                        Text("Not now, browse a sample city")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .accessibilityLabel("Continue without location")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
                .frame(maxWidth: 560)
            }
        }
        .animation(.easeInOut, value: env.hasOnboarded)
    }
}
