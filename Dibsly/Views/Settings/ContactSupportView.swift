import SwiftUI

enum SupportSubject: String, CaseIterable, Identifiable {
    case general = "General"
    case feature = "Feature Suggestion"
    case bug = "Bug Report"
    case usage = "Usage Question"
    case performance = "Performance Issue"
    case ui = "UI Improvement"
    case other = "Other"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .general: return "bubble.left.fill"
        case .feature: return "lightbulb.fill"
        case .bug: return "ant.fill"
        case .usage: return "questionmark.circle.fill"
        case .performance: return "gauge.with.dots.needle.67percent"
        case .ui: return "paintpalette.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

struct ContactSupportView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var subject: SupportSubject = .general
    @State private var customSubject: String = ""
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var message: String = ""
    @State private var isSending: Bool = false
    @State private var resultMessage: String?
    @State private var resultIsSuccess: Bool = false

    private let maxMessage = 1000

    private var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("@") && trimmed.contains(".") && trimmed.count > 5
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        isEmailValid &&
        !message.trimmingCharacters(in: .whitespaces).isEmpty &&
        (subject != .other || !customSubject.trimmingCharacters(in: .whitespaces).isEmpty) &&
        !isSending
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    subjectSection
                    fieldsSection
                    submitSection
                }
                .padding(18)
            }
            .background(DesignSystem.groupedSurface)
            .navigationTitle("Contact support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var subjectSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What is this about?")
                .font(.subheadline.weight(.bold))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(SupportSubject.allCases.filter { $0 != .other }) { option in
                    subjectTile(option)
                }
            }

            subjectTile(.other)

            if subject == .other {
                TextField("Tell us the topic", text: $customSubject)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Custom subject")
            }
        }
        .dibsCard()
    }

    private func subjectTile(_ option: SupportSubject) -> some View {
        Button {
            subject = option
        } label: {
            VStack(spacing: 6) {
                Image(systemName: option.symbol)
                    .font(.system(size: 18, weight: .semibold))
                Text(option.rawValue)
                    .font(.caption2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 74)
            .foregroundStyle(subject == option ? Color.white : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(subject == option ? DesignSystem.green : DesignSystem.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(subject == option ? DesignSystem.green : DesignSystem.separator, lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if subject == option {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.rawValue)
    }

    private var fieldsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            fieldLabel("Name")
            TextField("Your name", text: $name)
                .textFieldStyle(.roundedBorder)
                .textContentType(.name)
                .accessibilityLabel("Your name")

            fieldLabel("Email")
            TextField("yourname@example.com", text: $email)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("Your email")
            if !email.isEmpty && !isEmailValid {
                Text("Enter a valid email address.")
                    .font(.caption2)
                    .foregroundStyle(DesignSystem.orange)
            }

            HStack {
                fieldLabel("Message")
                Spacer()
                Text("\(message.count) / \(maxMessage)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            TextEditor(text: $message)
                .frame(minHeight: 130)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 10).fill(DesignSystem.surface))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(DesignSystem.separator, lineWidth: 1))
                .onChange(of: message) { _, newValue in
                    if newValue.count > maxMessage {
                        message = String(newValue.prefix(maxMessage))
                    }
                }
                .accessibilityLabel("Feedback message")
        }
        .dibsCard()
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
    }

    private var submitSection: some View {
        VStack(spacing: 10) {
            Button {
                Task { await submit() }
            } label: {
                HStack {
                    if isSending { ProgressView().tint(.white) }
                    Text(isSending ? "Sending..." : "Submit")
                }
            }
            .buttonStyle(DibsPrimaryButtonStyle())
            .disabled(!canSubmit)

            if let resultMessage {
                Text(resultMessage)
                    .font(.caption)
                    .foregroundStyle(resultIsSuccess ? DesignSystem.greenDeep : DesignSystem.orange)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(
                        (resultIsSuccess ? DesignSystem.green : DesignSystem.orange).opacity(0.10)
                    ))
            }

            Text("We only use your email to respond to this feedback.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func submit() async {
        guard canSubmit else { return }
        isSending = true
        defer { isSending = false }
        do {
            try await ContactSupportService.shared.submit(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                subject: subject == .other ? customSubject.trimmingCharacters(in: .whitespacesAndNewlines) : subject.rawValue,
                message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                appName: "Dibsly"
            )
            resultIsSuccess = true
            resultMessage = "Thank you! Your feedback has been sent. We reply within 24 hours."
            name = ""
            email = ""
            message = ""
            customSubject = ""
        } catch {
            resultIsSuccess = false
            resultMessage = error.localizedDescription
        }
    }
}
