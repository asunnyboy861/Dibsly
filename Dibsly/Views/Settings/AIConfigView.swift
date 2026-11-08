import SwiftUI

struct AIConfigView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var providerID: String = AIConfiguration.byoProviderID()
    @State private var baseURL: String = AIConfiguration.byoBase()
    @State private var model: String = AIConfiguration.byoModel()
    @State private var apiKey: String = AIConfiguration.byoKey() ?? ""
    @State private var message: String?
    @State private var isTesting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "apple.logo")
                            .foregroundStyle(DesignSystem.green)
                        Text("Apple Intelligence")
                        Spacer()
                        Text(env.ai.appleAvailable ? "Available" : "Unavailable")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("On-device engine")
                } footer: {
                    Text(env.ai.appleAvailable
                         ? "Available. Drafting and scoring run on this device for free and unlimited."
                         : "Not available on this device. Use Dibsly cloud AI credits or add your own key below.")
                        .font(.caption2)
                }

                Section {
                    HStack {
                        Text("Dibsly cloud AI")
                        Spacer()
                        Text(env.ai.proxyConfigured ? "Configured" : "Not configured")
                            .foregroundStyle(.secondary)
                    }
                    Text("Cloud moderation and market valuation use credits. On-device AI and your own key never spend credits.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Cloud AI")
                }

                Section {
                    Picker("Provider", selection: $providerID) {
                        ForEach(BYOProviderOption.all) { option in
                            Text(option.title).tag(option.id)
                        }
                    }
                    .onChange(of: providerID) { _, newValue in
                        let option = BYOProviderOption.option(for: newValue)
                        baseURL = option.defaultBase
                        model = option.defaultModel
                    }

                    TextField("Base URL", text: $baseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    TextField("Model", text: $model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("API key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button {
                        AIConfiguration.saveBYO(providerID: providerID, base: baseURL, model: model, key: apiKey)
                        env.ai.refreshState()
                        message = "Saved. Keys stay in the device Keychain."
                    } label: {
                        Text("Save key")
                    }

                    Button {
                        Task { await testKey() }
                    } label: {
                        HStack {
                            Text(isTesting ? "Testing..." : "Test connection")
                            Spacer()
                            if isTesting { ProgressView() }
                        }
                    }
                    .disabled(isTesting)

                    Button(role: .destructive) {
                        apiKey = ""
                        AIConfiguration.clearBYO()
                        env.ai.refreshState()
                        message = "Your key was removed."
                    } label: {
                        Text("Remove key")
                    }
                } header: {
                    Text("Bring your own API key")
                } footer: {
                    Text("Keys are stored in the iOS Keychain and never leave the device except to call the provider you choose. No key is ever committed to the app or shared with other users.")
                        .font(.caption2)
                }

                if let message {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(DesignSystem.greenDeep)
                    }
                }
            }
            .navigationTitle("AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func testKey() async {
        isTesting = true
        defer { isTesting = false }
        AIConfiguration.saveBYO(providerID: providerID, base: baseURL, model: model, key: apiKey)
        env.ai.refreshState()
        let result = await env.ai.testConnection()
        message = result.message
    }
}
