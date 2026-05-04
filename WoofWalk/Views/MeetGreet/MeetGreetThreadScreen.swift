import SwiftUI
import FirebaseAuth
import Combine

/// Live Meet & Greet conversation. Renders:
///
/// 1. Confirmed-card pin at the top of the scroll view (only when
///    the thread is `time_proposed` / `confirmed` / `completed`).
/// 2. Status pill in the nav bar.
/// 3. Chat thread — text bubbles for `text` messages, embedded
///    action cards for `time_proposal` / `time_confirmation`.
/// 4. Inline "Suggest a time" sheet trigger + a confirm button on
///    incoming time-proposal cards.
/// 5. Bottom composer (compose + send) — disabled if thread closed.
struct MeetGreetThreadScreen: View {
    let threadId: String

    @StateObject private var viewModel: MeetGreetThreadViewModel
    @State private var composer: String = ""
    @State private var showSuggestTimeSheet = false
    @State private var showCancelConfirm = false

    init(threadId: String) {
        self.threadId = threadId
        _viewModel = StateObject(wrappedValue: MeetGreetThreadViewModel(threadId: threadId))
    }

    var body: some View {
        VStack(spacing: 0) {
            messagesScroll
            composerBar
        }
        .background(Color(hex: 0x1C1C1C).ignoresSafeArea())
        .navigationTitle(viewModel.thread?.providerDisplayName ?? "Meet & Greet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(viewModel.thread?.providerDisplayName ?? "Meet & Greet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    if let status = viewModel.thread?.status {
                        statusPill(status)
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if viewModel.thread?.status.isOpen == true {
                        Button(role: .destructive) {
                            showCancelConfirm = true
                        } label: {
                            Label("Cancel meet & greet", systemImage: "xmark.circle")
                        }
                    }
                    if viewModel.thread?.status == .confirmed {
                        Button {
                            Task { await viewModel.markComplete() }
                        } label: {
                            Label("Mark complete", systemImage: "checkmark.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.turquoise60)
                }
            }
        }
        .sheet(isPresented: $showSuggestTimeSheet) {
            SuggestTimeSheet { startMs, durationMin, locationLabel in
                Task {
                    await viewModel.proposeTime(
                        startMs: startMs,
                        durationMin: durationMin,
                        locationLabel: locationLabel
                    )
                }
            }
        }
        .alert("Cancel meet & greet?", isPresented: $showCancelConfirm) {
            Button("Cancel meet", role: .destructive) {
                Task { await viewModel.cancel() }
            }
            Button("Keep open", role: .cancel) {}
        } message: {
            Text("This closes the conversation for both sides. You can always start a new one later.")
        }
        .alert("Couldn't send", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.errorMessage = nil }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Messages scroll

    private var messagesScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    // Top-of-thread confirmed card (also shows for
                    // time_proposed so the receiving side has a
                    // sticky reference to the proposal at a glance).
                    if let thread = viewModel.thread,
                       thread.status == .timeProposed
                        || thread.status == .confirmed
                        || thread.status == .completed {
                        MeetGreetConfirmedCard(thread: thread) {
                            // Book-after route — funnels into the
                            // existing booking flow scoped to the
                            // provider org.
                            AppNavigator.shared.navigate(
                                to: .booking(providerId: thread.providerOrgId)
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }

                    // Privacy banner — only while the thread is open
                    // and the address isn't yet revealed.
                    if let thread = viewModel.thread, !thread.exactAddressRevealed, thread.status.isOpen {
                        privacyBanner
                    }

                    // Message timeline.
                    ForEach(viewModel.messages) { message in
                        messageBubble(message)
                            .id(message.id ?? "msg-\(message.createdAt)")
                    }

                    // Loading / empty hint.
                    if viewModel.messages.isEmpty {
                        Text("Loading…")
                            .font(.caption)
                            .foregroundColor(.neutral60)
                            .padding(.top, 24)
                    }

                    Color.clear.frame(height: 4).id("BOTTOM")
                }
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.messages.count) { _ in
                withAnimation {
                    proxy.scrollTo("BOTTOM", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Privacy banner

    private var privacyBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.caption2)
                .foregroundColor(.turquoise60)
            Text("Messages are private to WoofWalk")
                .font(.caption2)
                .foregroundColor(.neutral70)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color.turquoise60.opacity(0.06))
        .padding(.horizontal, 16)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Status pill

    private func statusPill(_ status: MGStatus) -> some View {
        let (bg, fg): (Color, Color) = {
            switch status {
            case .pendingProviderResponse: return (Color.orange60.opacity(0.20), .orange60)
            case .inConversation: return (Color.turquoise60.opacity(0.20), .turquoise60)
            case .timeProposed: return (Color.orange60.opacity(0.20), .orange60)
            case .confirmed: return (Color.success60.opacity(0.20), .success60)
            case .completed: return (Color.neutral60.opacity(0.25), .neutral80)
            case .cancelled: return (Color.error60.opacity(0.20), .error60)
            }
        }()
        return Text(status.displayLabel)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(bg))
            .foregroundColor(fg)
    }

    // MARK: - Message bubble dispatcher

    @ViewBuilder
    private func messageBubble(_ message: MeetGreetMessage) -> some View {
        switch message.messageKind {
        case .text:
            textBubble(message)
        case .timeProposal:
            timeProposalCard(message)
        case .timeConfirmation:
            timeConfirmationCard(message)
        }
    }

    private var currentUid: String? { Auth.auth().currentUser?.uid }

    private func textBubble(_ message: MeetGreetMessage) -> some View {
        let isMe = message.senderUid == currentUid
        return HStack {
            if isMe { Spacer(minLength: 40) }
            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.subheadline)
                    .foregroundColor(isMe ? .black : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isMe ? Color.turquoise60 : Color(hex: 0x2F3033))
                    )
                Text(message.createdDate, style: .time)
                    .font(.caption2)
                    .foregroundColor(.neutral60)
            }
            if !isMe { Spacer(minLength: 40) }
        }
        .padding(.horizontal, 16)
    }

    /// Inline time-proposal card. The OTHER side gets a "Confirm"
    /// button; the proposer just sees their own suggestion.
    private func timeProposalCard(_ message: MeetGreetMessage) -> some View {
        let canConfirm = message.senderUid != currentUid
            && viewModel.thread?.status == .timeProposed
        let proposed = message.proposedTime
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.turquoise60)
                Text("Time suggested")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.neutral80)
                Spacer()
            }
            if let proposed {
                Text(formatProposed(proposed))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Text(proposed.locationLabel)
                    .font(.subheadline)
                    .foregroundColor(.neutral80)
            }
            if canConfirm {
                Button {
                    Task { await viewModel.confirmTime() }
                } label: {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Confirm")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.turquoise60))
                    .foregroundColor(.black)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: 0x2F3033))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    private func timeConfirmationCard(_ message: MeetGreetMessage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.turquoise60)
                Text("Meet & Greet confirmed")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
            }
            if let confirmed = message.confirmedTime {
                Text(formatProposed(confirmed))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Text(confirmed.locationLabel)
                    .font(.subheadline)
                    .foregroundColor(.neutral80)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.turquoise60.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.turquoise60.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    private func formatProposed(_ time: MGTime) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM, HH:mm"
        return "\(formatter.string(from: time.startDate)) · \(time.durationMin) min"
    }

    // MARK: - Composer

    private var composerBar: some View {
        let isOpen = viewModel.thread?.status.isOpen ?? false
        return HStack(spacing: 10) {
            Button {
                showSuggestTimeSheet = true
            } label: {
                Image(systemName: "calendar.badge.plus")
                    .font(.title3)
                    .foregroundColor(.turquoise60)
                    .padding(8)
            }
            .disabled(!isOpen || viewModel.thread?.status == .confirmed)

            TextField("Message", text: $composer, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(hex: 0x2F3033))
                .clipShape(Capsule())
                .foregroundColor(.white)
                .disabled(!isOpen)

            Button {
                let text = composer.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                composer = ""
                Task { await viewModel.send(text: text) }
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(canSend ? .black : .neutral60)
                    .padding(10)
                    .background(Circle().fill(canSend ? Color.turquoise60 : Color.neutral40))
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(hex: 0x1C1C1C))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.5),
            alignment: .top
        )
    }

    private var canSend: Bool {
        let trimmed = composer.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && (viewModel.thread?.status.isOpen ?? false)
    }
}

// MARK: - Suggest-time sheet

private struct SuggestTimeSheet: View {
    let onPropose: (Int64, Int, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date = Date().addingTimeInterval(60 * 60 * 24)
    @State private var durationMin: Int = 15
    @State private var locationLabel: String = ""

    private let durations = [15, 30, 45, 60]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sectionLabel("When?")
                    DatePicker(
                        "",
                        selection: $date,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    .tint(.turquoise60)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: 0x2F3033))
                    )

                    sectionLabel("How long?")
                    HStack(spacing: 8) {
                        ForEach(durations, id: \.self) { mins in
                            Button { durationMin = mins } label: {
                                Text("\(mins) min")
                                    .font(.footnote.weight(.medium))
                                    .foregroundColor(durationMin == mins ? .black : .white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(durationMin == mins
                                                  ? Color.turquoise60
                                                  : Color(hex: 0x2F3033))
                                    )
                            }
                        }
                    }

                    sectionLabel("Where?")
                    TextField("e.g. Crook town park", text: $locationLabel)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color(hex: 0x2F3033))
                        .clipShape(Capsule())
                        .foregroundColor(.white)
                    Text("A public, easy-to-find spot — never an exact address.")
                        .font(.caption2)
                        .foregroundColor(.neutral70)

                    Button {
                        let startMs = Int64(date.timeIntervalSince1970 * 1000)
                        onPropose(startMs, durationMin, locationLabel.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    } label: {
                        Text("Send suggestion")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(canSend ? Color.turquoise60 : Color.neutral40))
                            .foregroundColor(.black)
                    }
                    .disabled(!canSend)
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .background(Color(hex: 0x1C1C1C).ignoresSafeArea())
            .navigationTitle("Suggest a time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.turquoise60)
                }
            }
        }
    }

    private var canSend: Bool {
        !locationLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(.neutral80)
            .textCase(.uppercase)
    }
}

// MARK: - View model

@MainActor
final class MeetGreetThreadViewModel: ObservableObject {
    @Published var thread: MeetGreetThread?
    @Published var messages: [MeetGreetMessage] = []
    @Published var errorMessage: String?

    private let threadId: String
    private let repository = MeetGreetRepository.shared
    private var threadCancellable: AnyCancellable?
    private var messagesCancellable: AnyCancellable?

    init(threadId: String) {
        self.threadId = threadId
        startObserving()
    }

    private func startObserving() {
        threadCancellable = repository.observeThread(threadId: threadId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let err) = completion {
                        self?.errorMessage = err.localizedDescription
                    }
                },
                receiveValue: { [weak self] thread in
                    self?.thread = thread
                }
            )

        messagesCancellable = repository.observeMessages(threadId: threadId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let err) = completion {
                        self?.errorMessage = err.localizedDescription
                    }
                },
                receiveValue: { [weak self] msgs in
                    self?.messages = msgs
                }
            )
    }

    func send(text: String) async {
        do {
            try await repository.sendMessage(threadId: threadId, text: text)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func proposeTime(startMs: Int64, durationMin: Int, locationLabel: String) async {
        do {
            try await repository.proposeTime(
                threadId: threadId,
                startMs: startMs,
                durationMin: durationMin,
                locationLabel: locationLabel
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmTime() async {
        do {
            try await repository.confirmTime(threadId: threadId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancel() async {
        do {
            try await repository.cancel(threadId: threadId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markComplete() async {
        do {
            try await repository.complete(threadId: threadId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
