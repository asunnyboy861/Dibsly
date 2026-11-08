import SwiftUI

enum DesignSystem {
    static let green = Color(red: 0.086, green: 0.780, blue: 0.518)
    static let greenDeep = Color(red: 0.043, green: 0.580, blue: 0.392)
    static let orange = Color(red: 1.0, green: 0.420, blue: 0.208)
    static let ink = Color(red: 0.063, green: 0.078, blue: 0.094)
    static let fog = Color(red: 0.957, green: 0.965, blue: 0.973)

    static var surface: Color { Color(.secondarySystemBackground) }
    static var groupedSurface: Color { Color(.systemGroupedBackground) }
    static var card: Color { Color(.systemBackground) }
    static var separator: Color { Color(.separator) }

    static let cardRadius: CGFloat = 18
    static let sectionSpacing: CGFloat = 20
}

struct DibsPrimaryButtonStyle: ButtonStyle {
    var tint: Color = DesignSystem.green
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isEnabled ? tint : Color.gray.opacity(0.45))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct DibsSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(DesignSystem.green)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DesignSystem.green.opacity(0.12))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

extension View {
    func dibsCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.cardRadius, style: .continuous)
                    .fill(DesignSystem.card)
            )
    }

    func dibsShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 6)
    }
}
