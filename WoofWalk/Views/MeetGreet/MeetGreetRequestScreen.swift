import SwiftUI
import FirebaseAuth
import Combine

/// First step in the Meet & Greet flow. Client picks their dog,
/// writes a short intro, and selects a ROUGH AREA chip — never an
/// address. The CF stores the rough area on the thread so the
/// provider has enough context to decide whether to engage.
///
/// On send: navigates to the resulting thread screen via
/// `AppNavigator`.
struct MeetGreetRequestScreen: View {
    let providerOrgId: String
    let providerName: String?

    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel = MeetGreetRequestViewModel()

    init(providerOrgId: String, providerName: String? = nil) {
        self.providerOrgId = providerOrgId
        self.providerName = providerName
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                introHeader
                dogPicker
                introMessageField
                roughAreaPicker
                privacyNote
                sendButton
                Spacer(minLength: 12)
            }
            .padding(20)
        }
        .background(Color(hex: 0x1C1C1C).ignoresSafeArea())
        .navigationTitle("Meet & Greet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundColor(.turquoise60)
            }
        }
        .task { await viewModel.loadDogs() }
        .alert("Couldn't send", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.errorMessage = nil }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var introHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(providerName.map { "Say hi to \($0)" } ?? "Start a Meet & Greet")
                .font(.title2.bold())
                .foregroundColor(.white)
            Text("A free 15-minute chat before you commit to a booking. No payment, no contact details swapped — just a friendly intro.")
                .font(.subheadline)
                .foregroundColor(.neutral70)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Dog picker

    private var dogPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Which dog?")
            if viewModel.dogs.isEmpty && !viewModel.isLoadingDogs {
                Text("Add a dog to your profile first.")
                    .font(.caption)
                    .foregroundColor(.neutral70)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: 0x2F3033))
                    )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.dogs) { dog in
                            dogChip(dog)
                        }
                    }
                }
            }
        }
    }

    private func dogChip(_ dog: UnifiedDog) -> some View {
        let isSelected = viewModel.selectedDogId == dog.id
        return Button {
            viewModel.selectedDogId = dog.id
        } label: {
            HStack(spacing: 8) {
                if let photoUrl = dog.photoUrl, let url = URL(string: photoUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.neutral40
                    }
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "pawprint.fill")
                        .foregroundColor(.turquoise60)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
                Text(dog.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(isSelected ? .black : .white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(isSelected ? Color.turquoise60 : Color(hex: 0x2F3033))
            )
        }
    }

    // MARK: - Intro message

    private var introMessageField: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Quick intro")
            TextEditor(text: $viewModel.introMessage)
                .scrollContentBackground(.hidden)
                .background(Color(hex: 0x2F3033))
                .foregroundColor(.white)
                .font(.subheadline)
                .frame(minHeight: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if viewModel.introMessage.isEmpty {
                        Text("Hi! I'd love to bring [dog] for a quick meet & greet — a little nervous around new people, so just want to say hi first.")
                            .font(.subheadline)
                            .foregroundColor(.neutral60)
                            .padding(.horizontal, 14)
                            .padding(.top, 14)
                            .allowsHitTesting(false)
                    }
                }
            Text("\(viewModel.introMessage.count) / 1000")
                .font(.caption2)
                .foregroundColor(.neutral60)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - Rough area chips

    private var roughAreaPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Where roughly?")
            Text("A neighbourhood is fine — never an exact address.")
                .font(.caption)
                .foregroundColor(.neutral70)

            // Default chips — common UK rough-area phrasings.
            // Falls back to a free-text field if none fit.
            let chips = MeetGreetRequestViewModel.defaultRoughAreaChips
            FlowLayout(spacing: 8) {
                ForEach(chips, id: \.self) { chip in
                    chipButton(label: chip, isSelected: viewModel.roughArea == chip) {
                        viewModel.roughArea = chip
                    }
                }
                // Free-text "Other" toggle
                chipButton(
                    label: viewModel.roughArea.isEmpty || chips.contains(viewModel.roughArea)
                        ? "Other…"
                        : viewModel.roughArea,
                    isSelected: !viewModel.roughArea.isEmpty && !chips.contains(viewModel.roughArea)
                ) {
                    viewModel.showCustomRoughArea = true
                }
            }
            if viewModel.showCustomRoughArea {
                TextField("e.g. Jesmond", text: $viewModel.roughArea)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(hex: 0x2F3033))
                    .clipShape(Capsule())
                    .foregroundColor(.white)
            }
        }
    }

    private func chipButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? Color.turquoise60 : Color(hex: 0x2F3033))
                )
        }
    }

    // MARK: - Privacy note

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .foregroundColor(.turquoise60)
            VStack(alignment: .leading, spacing: 2) {
                Text("Your details stay private")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                Text("WoofWalk hides your contact details until you both agree to meet.")
                    .font(.caption2)
                    .foregroundColor(.neutral70)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.turquoise60.opacity(0.08))
        )
    }

    // MARK: - Send button

    private var sendButton: some View {
        Button {
            Task {
                if let threadId = await viewModel.send(providerOrgId: providerOrgId) {
                    dismiss()
                    // Hop straight into the new thread.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        AppNavigator.shared.navigate(to: .meetGreetThread(threadId: threadId))
                    }
                }
            }
        } label: {
            HStack {
                if viewModel.isSending {
                    ProgressView()
                        .tint(.black)
                } else {
                    Image(systemName: "pawprint.fill")
                    Text("Send Request")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule().fill(viewModel.canSend ? Color.turquoise60 : Color.neutral40))
            .foregroundColor(.black)
        }
        .disabled(!viewModel.canSend || viewModel.isSending)
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
final class MeetGreetRequestViewModel: ObservableObject {
    @Published var dogs: [UnifiedDog] = []
    @Published var selectedDogId: String?
    @Published var introMessage: String = ""
    @Published var roughArea: String = ""
    @Published var showCustomRoughArea: Bool = false
    @Published var isLoadingDogs: Bool = false
    @Published var isSending: Bool = false
    @Published var errorMessage: String?

    private let dogRepository = DogRepository()
    private let repository = MeetGreetRepository.shared

    /// Default rough-area chips — UK neighbourhood-style phrasings.
    /// Free-text "Other…" lets the user fill in a specific area.
    static let defaultRoughAreaChips = [
        "My neighbourhood",
        "Town centre",
        "Near the park",
        "Local high street",
        "5 mins drive away",
    ]

    var canSend: Bool {
        selectedDogId != nil
            && !introMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !roughArea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && introMessage.count <= 1000
            && roughArea.count <= 100
    }

    func loadDogs() async {
        isLoadingDogs = true
        defer { isLoadingDogs = false }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let fetched = try await dogRepository.fetchDogs(forUserId: uid)
            self.dogs = fetched
            // Default-select the first dog if none picked yet.
            if selectedDogId == nil { selectedDogId = fetched.first?.id }
        } catch {
            errorMessage = "Couldn't load your dogs: \(error.localizedDescription)"
        }
    }

    /// Sends the request and returns the resulting threadId on success.
    func send(providerOrgId: String) async -> String? {
        guard canSend, let dogId = selectedDogId else { return nil }
        isSending = true
        defer { isSending = false }
        do {
            let result = try await repository.createRequest(
                providerOrgId: providerOrgId,
                dogId: dogId,
                introMessage: introMessage.trimmingCharacters(in: .whitespacesAndNewlines),
                roughArea: roughArea.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            return result.threadId
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

// MARK: - Simple flow layout for chips
// iOS 16+ has `Layout`; this is a lightweight wrapping HStack.

private struct FlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                rowWidth = size.width + spacing
                rowHeight = size.height
            } else {
                rowWidth += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
