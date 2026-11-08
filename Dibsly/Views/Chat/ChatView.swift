import SwiftUI

struct ChatView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    let item: Item

    @State private var vm = ChatViewModel()
    @FocusState private var inputFocused: Bool

    private var myID: String { env.profile?.id ?? "" }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 10) {
                        safetyCard

                        ForEach(vm.messages) { message in
                            bubble(for: message)
                                .id(message.id)
                        }
                    }
                    .padding(16)
                }
                .background(DesignSystem.groupedSurface)
                .task {
                    vm.load(item: item, env: env)
                    scrollToBottom(proxy)
                }
                .onChange(of: vm.messages.count) { _, _ in
                    scrollToBottom(proxy)
                }
            }
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                inputBar
            }
        }
    }

    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(DesignSystem.green)
                Text("Safety first")
                    .font(.caption.weight(.bold))
            }
            Text("Meet in a public place, bring a friend, meet in daylight, and never pay a deposit for a free item.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(DesignSystem.green.opacity(0.10)))
    }

    @ViewBuilder
    private func bubble(for message: ChatMessage) -> some View {
        if message.isSystem {
            VStack(alignment: .leading, spacing: 3) {
                Text(message.senderName)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(DesignSystem.greenDeep)
                Text(message.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(DesignSystem.surface))
        } else {
            HStack {
                if message.senderID == myID { Spacer(minLength: 40) }
                VStack(alignment: message.senderID == myID ? .trailing : .leading, spacing: 3) {
                    Text(message.senderName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(message.text)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(message.senderID == myID ? DesignSystem.green : DesignSystem.card)
                        )
                        .foregroundStyle(message.senderID == myID ? .white : .primary)
                }
                if message.senderID != myID { Spacer(minLength: 40) }
            }
        }
    }

    private var inputBar: some View {
        VStack(spacing: 6) {
            if let warning = vm.scamWarning {
                Text(warning)
                    .font(.caption2)
                    .foregroundStyle(DesignSystem.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                TextField("Message the neighbor", text: $vm.draft, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .focused($inputFocused)
                    .accessibilityLabel("Message field")

                Button {
                    Task {
                        await vm.send(item: item, env: env)
                        inputFocused = false
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(vm.draft.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary : DesignSystem.green)
                }
                .accessibilityLabel("Send message")
                .disabled(vm.draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.regularMaterial)
        }
        .padding(.bottom, 4)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let last = vm.messages.last else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }
}
