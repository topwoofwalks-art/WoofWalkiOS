import SwiftUI
import FirebaseAuth

/// Client-side conversation viewer for a single cash-topup request.
/// Subscribes to the request doc via `CashTopupRepository.observeRequest`.
/// No reply input — the client opens this to read the business's reply
/// and to know when the request has been fulfilled.
struct CashTopupRequestView: View {
    let requestId: String
    /// Optional callback fired when the user taps "Try booking again" on a
    /// fulfilled request. Defaults to dismissing the view.
    var onRetryBooking: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var request: CashTopupRequest?
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
                        Text("Sending your request...")
                            .font(.subheadline)
                            .foregroundColor(.neutral60)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 32)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }

            if request?.statusEnum == .fulfilled {
                fulfilledFooter
            }
        }
        .background(Color.neutral10.ignoresSafeArea())
        .navigationTitle("Cash booking request")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { startObserving() }
        .onDisappear {
            listenerTask?.cancel()
            listenerTask = nil
        }
    }

    // MARK: - Status banner

    private var statusBanner: some View {
        let label = request?.statusEnum.displayLabel ?? "Waiting"
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
            Text(label)
                .font(.subheadline.bold())
                .foregroundColor(.white)
            Spacer()
            if let orgName = request?.orgName, !orgName.isEmpty {
                Text(orgName)
                    .font(.caption)
                    .foregroundColor(.neutral60)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.neutral20)
    }

    // MARK: - Message bubble

    private func messageBubble(_ message: CashTopupMessage) -> some View {
        HStack {
            if message.isFromClient {
                Spacer(minLength: 40)
            }
            VStack(alignment: message.isFromClient ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.body)
                    .foregroundColor(message.isFromClient ? .white : .white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(message.isFromClient ? Color.turquoise60 : Color.neutral20)
                    )
                Text(message.at, style: .time)
                    .font(.caption2)
                    .foregroundColor(.neutral50)
            }
            if message.isFromBusiness {
                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Fulfilled footer

    private var fulfilledFooter: some View {
        VStack(spacing: 10) {
            Text("Their wallet is topped up — you can book your cash service now.")
                .font(.subheadline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Button {
                if let onRetry = onRetryBooking {
                    onRetry()
                } else {
                    dismiss()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try booking again")
                        .font(.body.bold())
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.success40)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.neutral20)
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
        CashTopupRequestView(requestId: "preview")
    }
    .preferredColorScheme(.dark)
}
