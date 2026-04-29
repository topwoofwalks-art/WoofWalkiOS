import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// Emergency contacts editor — paired with the Watch SOS button.
/// Wearer adds up to 5 contacts (name, phone, email, optional WoofWalk
/// uid). When the Watch SOS fires, the `onSosAlertCreate` Cloud
/// Function FCM-pushes every contact whose `uid` is set, and queues
/// non-WoofWalk contacts (phone/email only) for an SMS fan-out
/// integration that lands in v1.1.
///
/// Storage: `users/{uid}.emergencyContacts: EmergencyContact[]`.
struct EmergencyContactsView: View {
    @StateObject private var vm = EmergencyContactsViewModel()
    @State private var showAdd = false

    var body: some View {
        Form {
            if vm.contacts.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No emergency contacts yet")
                            .font(.headline)
                        Text("Add up to 5 people who'll be notified if you trigger an SOS from your Apple Watch or in-app. Notifications go to anyone with a WoofWalk account; SMS for non-app contacts is coming in a follow-up release.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Section {
                    ForEach(vm.contacts) { contact in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(contact.name.isEmpty ? "Unnamed contact" : contact.name)
                                    .font(.body.bold())
                                Spacer()
                                if contact.uid != nil {
                                    Label("In app", systemImage: "checkmark.seal.fill")
                                        .labelStyle(.iconOnly)
                                        .foregroundColor(.green)
                                        .font(.caption)
                                }
                            }
                            if let relation = contact.relation, !relation.isEmpty {
                                Text(relation)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if let phone = contact.phone, !phone.isEmpty {
                                Text(phone)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if let email = contact.email, !email.isEmpty {
                                Text(email)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { indices in
                        vm.delete(at: indices)
                    }
                }
            }

            if vm.contacts.count < 5 {
                Section {
                    Button {
                        showAdd = true
                    } label: {
                        Label("Add contact", systemImage: "person.crop.circle.badge.plus")
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("How SOS works", systemImage: "info.circle")
                        .font(.subheadline.bold())
                    Text("Hold the SOS button on your Apple Watch (or use the in-app SOS) for 2 seconds. Your live location is recorded and we send a push to every emergency contact who has a WoofWalk account. They get a Google Maps link they can tap to see where you are.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Emergency Contacts")
        .navigationBarTitleDisplayMode(.inline)
        .task { vm.start() }
        .onDisappear { vm.stop() }
        .sheet(isPresented: $showAdd) {
            AddEmergencyContactSheet { contact in
                vm.add(contact)
                showAdd = false
            } onCancel: {
                showAdd = false
            }
        }
    }
}

private struct AddEmergencyContactSheet: View {
    var onSave: (EmergencyContact) -> Void
    var onCancel: () -> Void

    @State private var name = ""
    @State private var relation = ""
    @State private var phone = ""
    @State private var email = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Relation (optional)", text: $relation)
                        .textInputAutocapitalization(.words)
                }
                Section("How to reach them") {
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    TextField("Email (optional)", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                Section {
                    Text("If this contact also uses WoofWalk, we'll match them automatically by phone or email and push them an in-app alert. Otherwise the contact is recorded for SMS delivery in a future release.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("New Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty,
                              !(phone.isEmpty && email.isEmpty)
                        else { return }
                        onSave(EmergencyContact(
                            name: trimmed,
                            relation: relation.trimmingCharacters(in: .whitespaces).nilIfEmpty,
                            phone: phone.trimmingCharacters(in: .whitespaces).nilIfEmpty,
                            email: email.trimmingCharacters(in: .whitespaces).nilIfEmpty,
                            uid: nil
                        ))
                    }
                    .bold()
                }
            }
        }
    }
}

// MARK: - Model

struct EmergencyContact: Identifiable, Codable {
    var id: String = UUID().uuidString
    var name: String
    var relation: String?
    var phone: String?
    var email: String?
    /// Resolved uid if this contact has a WoofWalk account. Set by
    /// the matching CF on save; nil for purely-external contacts.
    var uid: String?
}

@MainActor
final class EmergencyContactsViewModel: ObservableObject {
    @Published var contacts: [EmergencyContact] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func start() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        listener = db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                let raw = snap?.data()?["emergencyContacts"] as? [[String: Any]] ?? []
                self.contacts = raw.compactMap { entry in
                    guard let name = entry["name"] as? String else { return nil }
                    return EmergencyContact(
                        id: (entry["id"] as? String) ?? UUID().uuidString,
                        name: name,
                        relation: entry["relation"] as? String,
                        phone: entry["phone"] as? String,
                        email: entry["email"] as? String,
                        uid: entry["uid"] as? String
                    )
                }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    func add(_ contact: EmergencyContact) {
        // Try to resolve the contact's WoofWalk account by email first
        // (more reliable than phone). Best-effort — if no match, leave
        // uid nil and the SOS CF will queue them for external delivery.
        Task {
            var resolved = contact
            if let email = contact.email, !email.isEmpty {
                let snap = try? await db.collection("users")
                    .whereField("email", isEqualTo: email)
                    .limit(to: 1)
                    .getDocuments()
                if let doc = snap?.documents.first {
                    resolved.uid = doc.documentID
                }
            }
            if resolved.uid == nil, let phone = contact.phone, !phone.isEmpty {
                let snap = try? await db.collection("users")
                    .whereField("phone", isEqualTo: phone)
                    .limit(to: 1)
                    .getDocuments()
                if let doc = snap?.documents.first {
                    resolved.uid = doc.documentID
                }
            }

            await MainActor.run {
                self.contacts.append(resolved)
                self.save()
            }
        }
    }

    func delete(at offsets: IndexSet) {
        contacts.remove(atOffsets: offsets)
        save()
    }

    private func save() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let payload = contacts.map { c in
            [
                "id": c.id,
                "name": c.name,
                "relation": c.relation as Any,
                "phone": c.phone as Any,
                "email": c.email as Any,
                "uid": c.uid as Any,
            ] as [String: Any]
        }
        db.collection("users").document(uid).setData([
            "emergencyContacts": payload,
        ], merge: true)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
