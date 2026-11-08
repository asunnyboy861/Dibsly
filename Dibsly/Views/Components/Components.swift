import SwiftUI
import UIKit

enum TimeFormat {
    static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ConfettiView: View {
    var isActive: Bool
    @State private var fall: Bool = false

    private let colors: [Color] = [
        DesignSystem.green, DesignSystem.orange, .yellow, .blue, .purple, .white
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<42, id: \.self) { index in
                let x = geo.size.width * CGFloat(Double((index * 71) % 100) / 100)
                let finalY = geo.size.height * CGFloat(0.25 + Double((index * 37) % 70) / 100)
                RoundedRectangle(cornerRadius: 2)
                    .fill(colors[index % colors.count])
                    .frame(width: CGFloat(6 + index % 5), height: CGFloat(10 + index % 7))
                    .rotationEffect(.degrees(fall ? Double(index * 61) : 0))
                    .position(x: x, y: fall ? finalY : -40)
                    .opacity(fall ? 0.9 : 0)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, active in
            guard active else { return }
            fall = false
            withAnimation(.easeOut(duration: 1.6)) { fall = true }
        }
        .onAppear {
            guard isActive else { return }
            withAnimation(.easeOut(duration: 1.6)) { fall = true }
        }
    }
}

struct TrustBadgeView: View {
    let score: Int
    var compact: Bool = false

    private var badge: TrustBadge { TrustBadge.from(score: score) }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: badge.symbol)
                .font(.caption2)
            Text(compact ? badge.title : "\(badge.title) · \(score)")
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(badge.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(badge.color.opacity(0.14))
        )
        .accessibilityLabel("Trust badge \(badge.title), score \(score)")
    }
}

struct CategoryChip: View {
    let category: ItemCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: category.symbol)
                    .font(.caption)
                Text(category.title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(isSelected ? DesignSystem.green : DesignSystem.surface)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.title)
    }
}

struct AllCategoryChip: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.caption)
                Text("All")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(isSelected ? DesignSystem.green : DesignSystem.surface)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("All categories")
    }
}

struct ItemThumbnail: View {
    let item: Item
    var size: CGFloat = 56
    var corner: CGFloat = 12

    var body: some View {
        Group {
            if let name = item.photoFileNames.first, let image = ImageStore.shared.load(name) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    DesignSystem.surface
                    Image(systemName: item.categorySymbol)
                        .font(.system(size: size * 0.34, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(DesignSystem.separator.opacity(0.6), lineWidth: 0.5)
        )
    }
}

struct ValueRibbon: View {
    let dollars: Int
    var body: some View {
        HStack(spacing: 4) {
            Text("$0")
                .font(.system(.caption2, design: .rounded, weight: .black))
                .foregroundStyle(DesignSystem.green)
            Text("worth ~$\(dollars)")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(DesignSystem.card))
    }
}

struct CountdownBar: View {
    let remaining: TimeInterval
    let total: TimeInterval

    private var progress: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(max(0, min(1, remaining / total)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Dibs window")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(Int(remaining / 60)):\(String(format: "%02d", Int(remaining) % 60))")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(DesignSystem.surface)
                    Capsule()
                        .fill(LinearGradient(colors: [DesignSystem.orange, DesignSystem.orange.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(4, geo.size.width * progress))
                }
            }
            .frame(height: 6)
        }
        .accessibilityLabel("Dibs window remaining \(Int(remaining)) seconds")
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(DesignSystem.green)
            Text(title)
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(DibsPrimaryButtonStyle())
                    .padding(.top, 6)
                    .padding(.horizontal, 30)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .dibsCard()
    }
}

struct DibsButton: View {
    let title: String
    let subtitle: String?
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(.title2, design: .rounded, weight: .black))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2.weight(.medium))
                        .opacity(0.9)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                Capsule().fill(isEnabled ? DesignSystem.orange : Color.gray.opacity(0.5))
            )
            .shadow(color: isEnabled ? DesignSystem.orange.opacity(0.35) : .clear, radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .sensoryFeedback(.impact(weight: .heavy), trigger: isEnabled)
        .accessibilityLabel(title)
    }
}
