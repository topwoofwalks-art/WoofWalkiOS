import SwiftUI

/// Business-side reply view for a single cash-topup request.
/// Lets an org member read the conversation, send a reply (optionally
/// flipping status to `resolved`), or explicitly mark the request resolved
/// without a reply.
struct CashTopupReplyView: View {
    let requestId: String

    @Environment(\.dismiss) private var dismiss
    @State private var request: CashTopupRequest?
    @State private var replyText: String = ""
    @State private var markResolved: Bool = false
    @State private var isSending: Bool = false
    @State private var isResolving: Bool = false
    @State private var errorMessage: String?
    @State private var listenerTask: Task<Void, Never>?

    private let repo = CashTopupRepository()

    var body: some View {
        VStack(spacing: 0) {
            statusBanner

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if let messages = request?.messages, !messages.isEmpty {
                        ForEach(messages) { message in
                            messageBubble(message)
                        }
                    } else {
                        Text("Loading conversation...")
                            .font(.subheadline)
                            .foregroundColor(.neutral60)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 32)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }

            replyComposer
        }
        .background(Color.neutral10.ignoresSafeArea())
        .navigationTitle("Reply to client")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await resolveOnly() }
                } label: {
                    if isResolving {
                        ProgressView().tint(.white)
                    } else {
                        Text("Mark resolved")
                            .font(.subheadline.bold())
                    }
                }
                .disabled(isResolving || (request?.statusEnum == .resolved || request?.statusEnum == .fulfilled))
            }
        }
        .onAppear { startObserving() }
        .onDisappear {
            listenerTask?.cancel()
            listenerTask = nil
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Status banner

    private var statusBanner: some View {
        let label = request?.statusEnum.displayLabel ?? "Loading"
        let color: Color
        switch request?.statusEnum ?? .pending {
        case .pending:    color = .orange
        case .replied:    color = .turquoise60
        case .resolved:   color = .neutral60
        case .fulfilled:  color = .success40
        }
        return HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                if let clientName = request?.clientName, !clientName.isEmpty {
                    Text(clientName)
                        .font(.caption)
                        .foregroundColor(.neutral60)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.neutral20)
    }

    // MARK: - Bubbles (mirror client viewer; right-aligned for the side
    // sending — i.e. business messages are right-aligned here.)

    private func messageBubble(_ message: CashTopupMessage) -> some View {
        let alignRight = message.isFromBusiness
        return HStack {
            if alignRight {
                Spacer(minLength: 40)
            }
            VStack(alignment: alignRight ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(alignRight ? Color.turquoise60 : Color.neutral20)
                    )
                Text(message.at, style: .time)
                    .font(.caption2)
                    .foregroundColor(.neutral50)
            }
            if !alignRight {
                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Reply composer

    private var replyComposer: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Type your reply…", text: $replyText, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.neutral20)
                    )
                    .foregroundColor(.white)

                Button {
                    Task { await sendReply() }
                } label: {
                    if isSending {
                        ProgressView().tint(.white)
                            .frame(width: 44, height: 44)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.body)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(canSend ? Color.turquoise60 : Color.neutral30)
                            )
                    }
                }
                .disabled(!canSend || isSending)
            }

            Toggle("Mark as resolved when sent", isOn: $markResolved)
                .toggleStyle(.switch)
                .tint(.success40)
                .font(.caption)
                .foregroundColor(.neutral60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.neutral20)
    }

    private var canSend: Bool {
        !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    private func sendReply() async {
        let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSending = true
        defer { isSending = false }

        do {
            _ = try await repo.replyToCashTopupRequest(
                requestId: requestId,
                text: text,
                markResolved: markResolved
            )
            await MainActor.run {
                self.replyText = ""
                if self.markResolved {
                    self.dismiss()
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func resolveOnly() async {
        isResolving = true
        defer { isResolving = false }
        do {
            try await repo.resolveCashTopupRequest(requestId: requestId)
            await MainActor.run { self.dismiss() }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Listener

    private func startObserving() {
        listenerTask?.cancel()
        listenerTask = Task { @MainActor in
            for await snapshot in repo.observeRequest(id: requestId) {
                self.request = snapshot
            }
        }
    }
}

#Preview {
    NavigationStack {
        CashTopupReplyView(requestId: "preview")
    }
    .preferredColorScheme(.dark)
}
