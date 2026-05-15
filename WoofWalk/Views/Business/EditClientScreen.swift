import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - EditClient ViewModel

/// iOS parity port of Android
/// `app/src/main/java/com/woofwalk/ui/business/clients/EditClientScreen.kt`.
///
/// Loads `businesses/{orgId}/clients/{clientId}` and lets the business
/// owner edit the editable subset: notes, preferred service, special
/// instructions, and free-form tags (chip input). Save writes the merged
/// update straight back to the same doc.
///
/// Mirrors the Android model: the BUSINESS owns the client record
/// (clients are nested under the business org), so the orgId we resolve
/// to is the authenticated business user's uid — same as the rest of
/// the iOS Business CRM (see `ClientDetailScreen`'s `db.collection(
/// "organizations").document(userId).collection("clients")`).
@MainActor
final class EditClientViewModel: ObservableObject {
    @Published var notes: String = ""
    @Published var preferredService: String = ""
    @Published var specialInstructions: String = ""
    @Published var tags: [String] = []
    @Published var pendingTag: String = ""

    @Published var isLoading: Bool = true
    @Published var isSaving: Bool = false
    @Published var error: String?
    @Published var saveCompleted: Bool = false

    // Service catalog options for the preferred-service picker. Matches
    // the BookingServiceType enum on both platforms.
    let serviceOptions: [(value: String, label: String)] = [
        ("", "None"),
        ("walk", "Dog Walking"),
        ("grooming", "Grooming"),
        ("daycare", "Daycare"),
        ("boarding", "Boarding"),
        ("training", "Training"),
        ("in_sitting", "Sitting (in-home)"),
        ("out_sitting", "Sitting (your home)"),
        ("meet_greet", "Meet & Greet")
    ]

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private let clientId: String

    init(clientId: String) {
        self.clientId = clientId
    }

    func load() {
        guard let userId = auth.currentUser?.uid else {
            error = "Not signed in"
            isLoading = false
            return
        }

        isLoading = true
        error = nil

        db.collection("organizations")
            .document(userId)
            .collection("clients")
            .document(clientId)
            .getDocument { [weak self] snapshot, err in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoading = false

                    if let err = err {
                        self.error = "Failed to load client: \(err.localizedDescription)"
                        return
                    }

                    guard let data = snapshot?.data() else {
                        self.error = "Client not found"
                        return
                    }

                    self.notes = data["notes"] as? String ?? ""
                    self.preferredService = data["preferredService"] as? String ?? ""
                    self.specialInstructions = data["specialInstructions"] as? String ?? ""

                    // Tags can come back as [String] (canonical) or as a
                    // comma-joined string (Android's legacy form field).
                    // Normalise both at load.
                    if let arr = data["tags"] as? [String] {
                        self.tags = arr.filter { !$0.isEmpty }
                    } else if let csv = data["tags"] as? String {
                        self.tags = csv.split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                    } else {
                        self.tags = []
                    }
                }
            }
    }

    func addTag() {
        let trimmed = pendingTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !tags.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            tags.append(trimmed)
        }
        pendingTag = ""
    }

    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }

    func save(onSuccess: @escaping () -> Void) {
        guard let userId = auth.currentUser?.uid else {
            error = "Not signed in"
            return
        }
        guard !isSaving else { return }

        isSaving = true
        error = nil

        let updates: [String: Any] = [
            "notes": notes,
            "preferredService": preferredService,
            "specialInstructions": specialInstructions,
            "tags": tags,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        db.collection("organizations")
            .document(userId)
            .collection("clients")
            .document(clientId)
            .setData(updates, merge: true) { [weak self] err in
                Task { @MainActor in
                    guard let self else { return }
                    self.isSaving = false

                    if let err = err {
                        self.error = "Failed to save: \(err.localizedDescription)"
                        return
                    }
                    self.saveCompleted = true
                    onSuccess()
                }
            }
    }
}

// MARK: - Screen

struct EditClientScreen: View {
    let clientId: String
    @StateObject private var viewModel: EditClientViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var tagFieldFocused: Bool

    init(clientId: String) {
        self.clientId = clientId
        _viewModel = StateObject(wrappedValue: EditClientViewModel(clientId: clientId))
    }

    var body: some View {
        Form {
            if viewModel.isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text("Loading client…")
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                if let error = viewModel.error {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.subheadline)
                        }
                    }
                }

                notesSection
                preferredServiceSection
                specialInstructionsSection
                tagsSection
            }
        }
        .navigationTitle("Edit Client")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .disabled(viewModel.isSaving)
            }
            ToolbarItem(placement: .confirmationAction) {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Button("Save") {
                        viewModel.save {
                            dismiss()
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
        .onAppear {
            if viewModel.isLoading {
                viewModel.load()
            }
        }
    }

    private var notesSection: some View {
        Section {
            TextEditor(text: $viewModel.notes)
                .frame(minHeight: 100)
        } header: {
            Text("Notes")
        } footer: {
            Text("Private business notes about this client.")
        }
    }

    private var preferredServiceSection: some View {
        Section {
            Picker("Preferred service", selection: $viewModel.preferredService) {
                ForEach(viewModel.serviceOptions, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }
        } header: {
            Text("Preferred service")
        } footer: {
            Text("The default service offered when booking for this client.")
        }
    }

    private var specialInstructionsSection: some View {
        Section {
            TextEditor(text: $viewModel.specialInstructions)
                .frame(minHeight: 80)
        } header: {
            Text("Special instructions")
        } footer: {
            Text("Things every walker / groomer should know — gate code, allergies, behaviour notes.")
        }
    }

    private var tagsSection: some View {
        Section {
            // Chips
            if !viewModel.tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(viewModel.tags, id: \.self) { tag in
                        HStack(spacing: 6) {
                            Text(tag)
                                .font(.subheadline)
                            Button {
                                viewModel.removeTag(tag)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(Color.accentColor.opacity(0.15))
                        )
                    }
                }
                .padding(.vertical, 4)
            }

            HStack {
                TextField("Add a tag…", text: $viewModel.pendingTag)
                    .focused($tagFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { viewModel.addTag() }
                Button {
                    viewModel.addTag()
                    tagFieldFocused = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
                .disabled(viewModel.pendingTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        } header: {
            Text("Special tags")
        } footer: {
            Text("e.g. VIP, Morning walks, Reactive — used to filter clients and surface alerts.")
        }
    }
}

// MARK: - FlowLayout (chips wrap)

/// Minimal SwiftUI flow layout for tag chips. Wraps children onto new
/// rows once the available width is exhausted. Pure Layout protocol —
/// no GeometryReader hacks.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalWidth = max(totalWidth, rowWidth - spacing)
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalWidth = max(totalWidth, rowWidth - spacing)
        totalHeight += rowHeight
        return CGSize(width: totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    NavigationStack {
        EditClientScreen(clientId: "preview-client")
    }
}
