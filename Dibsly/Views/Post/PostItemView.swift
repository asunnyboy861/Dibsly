import PhotosUI
import SwiftUI
import UIKit

struct PostItemView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var vm = PostItemViewModel()
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var createdItem: Item?
    @State private var showPaywall = false
    @FocusState private var noteFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    photoSection
                    noteSection
                    draftSection
                    detailsSection
                    submitSection
                }
                .padding(16)
                .padding(.bottom, 64)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(DesignSystem.groupedSurface)
            .navigationTitle("Give something away")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { noteFocused = false }
                }
            }
            .sheet(item: $createdItem) { item in
                PostedConfirmationView(item: item)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .alert("This post can't go live", isPresented: Binding(
                get: { vm.blockMessage != nil },
                set: { if !$0 { vm.blockMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.blockReasons.joined(separator: "\n"))
            }
            .alert("One more thing", isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button("See Pro") {
                    vm.errorMessage = nil
                    showPaywall = true
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Photos")
                    .font(.subheadline.weight(.bold))
                Text("1 to 3")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 10) {
                ForEach(Array(vm.photos.enumerated()), id: \.offset) { index, image in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        Button {
                            vm.removePhoto(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.white, DesignSystem.orange)
                                .padding(5)
                        }
                        .accessibilityLabel("Remove photo")
                    }
                }

                if vm.photos.count < 3 {
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 3, matching: .images) {
                        VStack(spacing: 6) {
                            Image(systemName: "camera.fill")
                                .font(.title3)
                            Text("Add")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(DesignSystem.green)
                        .frame(width: 96, height: 96)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(DesignSystem.green.opacity(0.10))
                        )
                    }
                    .onChange(of: pickerItems) { _, newValue in
                        Task { await loadPhotos(newValue) }
                    }
                }

                Spacer()
            }
        }
        .dibsCard()
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Say what it is")
                .font(.subheadline.weight(.bold))
            Text("One sentence is enough. AI will draft the rest.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("e.g. gray sofa, pickup only on Saturday", text: $vm.rawNote, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
                .focused($noteFocused)
        }
        .dibsCard()
    }

    private var draftSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                Task {
                    let cloudAllowed = PurchaseManager.shared.isPro
                        || PurchaseManager.shared.hasCredits
                        || env.ai.byoConfigured
                    await vm.draft(with: env.ai, cloudAllowed: cloudAllowed)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text(vm.isDrafting ? "Drafting..." : "AI draft title, details and value")
                    Spacer()
                    if vm.isDrafting {
                        ProgressView()
                    }
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(DesignSystem.green)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(DesignSystem.green.opacity(0.10)))
            }
            .disabled(vm.isDrafting)
            .accessibilityLabel("Draft listing with AI")

            if vm.hasDrafted {
                Text("Drafted with \(vm.draftEngine.isEmpty ? "on-device rules" : vm.draftEngine). Edit freely.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .dibsCard()
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Listing")
                .font(.subheadline.weight(.bold))

            TextField("Title", text: $vm.title)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Listing title")

            TextField("Details and condition", text: $vm.details, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Listing details")

            HStack {
                Text("Category")
                    .font(.subheadline)
                Spacer()
                Picker("Category", selection: $vm.category) {
                    ForEach(ItemCategory.allCases) { category in
                        Label(category.title, systemImage: category.symbol).tag(category)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack {
                Text("AI estimate")
                    .font(.subheadline)
                Spacer()
                Text("$\(vm.estValueCents / 100)")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(DesignSystem.green)
            }

            Text("Free items only. No prices, deposits, shipping fees or payment apps.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .dibsCard()
    }

    private var submitSection: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    guard env.profile != nil else { return }
                    if let item = await vm.submit(env: env) {
                        createdItem = item
                        vm.reset()
                    }
                }
            } label: {
                HStack {
                    if vm.isSubmitting {
                        ProgressView().tint(.white)
                    }
                    Text(vm.isSubmitting ? "Posting..." : "Post to the neighborhood")
                }
            }
            .buttonStyle(DibsPrimaryButtonStyle())
            .disabled(!vm.canPost)

            Text("Every post passes an AI gatekeeper plus community reports.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                vm.addPhoto(image)
            }
        }
        pickerItems = []
    }
}

struct PostedConfirmationView: View {
    let item: Item
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: item.status == .live ? "checkmark.seal.fill" : "clock.badge.exclamationmark.fill")
                .font(.system(size: 64))
                .foregroundStyle(item.status == .live ? DesignSystem.green : DesignSystem.orange)
            Text(item.status == .live ? "You're live!" : "In review")
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text(item.status == .live
                 ? "\(item.title) is now visible to neighbors in your grid."
                 : "\(item.title) is in the trust and safety queue. Most reviews finish in a few seconds.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Button("Done") { dismiss() }
                .buttonStyle(DibsPrimaryButtonStyle())
                .padding(.horizontal, 32)
                .padding(.top, 10)
            Spacer()
        }
        .presentationDetents([.medium])
        .onAppear {
            if item.isHighValue && item.status == .live {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
}
