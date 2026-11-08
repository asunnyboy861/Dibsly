import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = SettingsViewModel()
    @AppStorage("dibsly.notifications") private var notificationsEnabled: Bool = true
    @AppStorage("dibsly.alerts.radius") private var alertRadius: Double = 20

    @State private var showAIConfig = false
    @State private var showPaywall = false
    @State private var showSafetyGuide = false

    private let policyBase = "https://asunnyboy861.github.io/Dibsly"

    var body: some View {
        NavigationStack {
            Form {
                subscriptionSection
                aiSection
                alertsSection
                privacySection
                supportSection
                legalSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showAIConfig) {
                AIConfigView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showSafetyGuide) {
                SafetyGuideView()
            }
        }
    }

    private var subscriptionSection: some View {
        Section {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(DesignSystem.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.isPro ? "Dibsly Pro active" : "Dibsly Pro")
                        .font(.subheadline.weight(.semibold))
                    Text(vm.isPro
                         ? "Unlimited alerts, posting and on-device AI."
                         : "\(vm.price(for: PurchaseManager.monthlyID)) / month or \(vm.price(for: PurchaseManager.lifetimeID)) once")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !vm.isPro {
                    Button("See plans") { showPaywall = true }
                        .font(.caption.weight(.bold))
                }
            }

            LabeledContent("AI credits", value: "\(vm.credits)")

            Button("Restore purchases") {
                Task { await vm.restore() }
            }

            Link("Manage subscription", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
        } header: {
            Text("Subscription")
        } footer: {
            Text("Subscriptions renew automatically unless canceled at least 24 hours before the end of the period. Manage or cancel anytime in your App Store account.")
                .font(.caption2)
        }
    }

    private var aiSection: some View {
        Section {
            Button {
                showAIConfig = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(DesignSystem.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI engine")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(env.ai.engineSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("AI")
        } footer: {
            Text("Apple Intelligence runs free on supported devices. Add your own API key for unlimited cloud AI, or spend credits for cloud moderation and valuation.")
                .font(.caption2)
        }
    }

    private var alertsSection: some View {
        Section {
            Toggle("Dibs alerts and match alerts", isOn: $notificationsEnabled)
                .onChange(of: notificationsEnabled) { _, enabled in
                    if enabled { env.requestNotifications() }
                }

            HStack {
                Text("Alert radius")
                Slider(value: $alertRadius, in: 5...50, step: 5)
                Text("\(Int(alertRadius)) mi")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
        } header: {
            Text("Alerts")
        } footer: {
            Text("Alerts are opt-in and can be turned off anytime. Free neighbors get batched alerts; Pro gets instant alerts and the 60-second quick-grab window on high-value items.")
                .font(.caption2)
        }
    }

    private var privacySection: some View {
        Section {
            HStack {
                Text("Location")
                Spacer()
                Text(locationStatus)
                    .foregroundStyle(.secondary)
            }
            Button("Open location settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Safety checklist") { showSafetyGuide = true }
        } header: {
            Text("Privacy and safety")
        } footer: {
            Text("Dibsly stores a coarse neighborhood grid (about 5 km), never your exact address. Post locations are blurred by roughly 300 meters on the map.")
                .font(.caption2)
        }
    }

    private var locationStatus: String {
        switch env.location.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return "On"
        case .denied, .restricted: return "Off"
        case .notDetermined: return "Not asked"
        @unknown default: return "Unknown"
        }
    }

    private var supportSection: some View {
        Section {
            NavigationLink {
                ContactSupportView()
            } label: {
                Label("Contact support", systemImage: "envelope.fill")
            }
            LabeledContent("Community feed", value: env.cloudStatus)
        } header: {
            Text("Support")
        } footer: {
            Text("Reports and support requests are handled within 24 hours.")
                .font(.caption2)
        }
    }

    private var legalSection: some View {
        Section {
            Link("Privacy Policy", destination: URL(string: "\(policyBase)/privacy.html")!)
            Link("Terms of Use", destination: URL(string: "\(policyBase)/terms.html")!)
            Link("Support page", destination: URL(string: "\(policyBase)/support.html")!)
        } header: {
            Text("Legal")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: vm.appVersion)
            LabeledContent("App", value: "Dibsly")
        } footer: {
            Text("Copyright © 2026 he zhou. All rights reserved.")
                .font(.caption2)
        }
    }
}

struct SafetyGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.title)
                            .foregroundStyle(DesignSystem.green)
                        Text("Safe exchange checklist")
                            .font(.title3.weight(.bold))
                    }

                    ForEach(ItemDetailViewModel.safetyChecklist, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(DesignSystem.green)
                            Text(tip)
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .dibsCard(padding: 12)
                    }

                    Text("If a neighbor asks for a deposit, shipping fee, or payment app transfer for a free item, stop and report the listing.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }
                .padding(16)
            }
            .background(DesignSystem.groupedSurface)
            .navigationTitle("Safety")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}
