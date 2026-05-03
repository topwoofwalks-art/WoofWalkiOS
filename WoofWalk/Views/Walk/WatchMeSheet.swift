import SwiftUI
import ContactsUI
import Contacts

// MARK: - Guardian model + constants

/// A guardian as captured by the walker. Name + optional phone (from
/// contacts picker) + optional WoofWalk uid (from friend picker).
/// `friendUid != nil` → guardian gets the in-app push + alarm experience.
/// `friendUid == nil && phone != nil` → guardian gets the SMS / WhatsApp
/// link experience.
struct WatchMeGuardian: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let phone: String?
    let friendUid: String?
    let photoUrl: String?

    init(name: String, phone: String? = nil, friendUid: String? = nil, photoUrl: String? = nil) {
        self.name = name
        self.phone = phone
        self.friendUid = friendUid
        self.photoUrl = photoUrl
    }
}

/// Hard cap on guardian count. Surfaced at pick time so the walker never
/// queues contacts that the `startSafetyWatch` CF would silently drop.
/// Mirrors the CF's `MAX_GUARDIAN_PHONES` + `MAX_GUARDIAN_UIDS` constants.
let watchMeGuardianMaxCount = 8

// MARK: - Safety palette

enum SafetyColors {
    static let blue = Color(red: 0.145, green: 0.388, blue: 0.922)       // 0xFF2563EB
    static let blueDark = Color(red: 0.118, green: 0.251, blue: 0.686)   // 0xFF1E40AF
    static let green = Color(red: 0.082, green: 0.502, blue: 0.239)      // 0xFF15803D
    static let amber = Color(red: 0.851, green: 0.463, blue: 0.024)      // 0xFFD97706
    static let red = Color(red: 0.863, green: 0.149, blue: 0.149)        // 0xFFDC2626
}

// MARK: - WatchMe Sheet

/// Bottom sheet that introduces and starts a Watch Me session. This is a
/// *safety* feature — the visual language is calm, deliberate, and
/// serious (shield iconography, slate-blue palette, plain English copy).
/// It does NOT borrow from the social Live Share sheet on purpose.
///
/// Mirrors Android `WatchMeSheet.kt`.
struct WatchMeSheet: View {

    let isStarting: Bool
    let isWatchActive: Bool
    let onStart: (_ guardians: [WatchMeGuardian], _ walkerNote: String, _ expectedReturnAt: Int64) -> Void
    let onStopWatch: () -> Void
    let onDismiss: () -> Void

    @State private var guardians: [WatchMeGuardian] = []
    @State private var walkerNote: String = ""
    @State private var expectedReturnAt: Date? = nil
    @State private var showContactPicker = false
    @State private var showTimePicker = false
    @State private var pendingTime = Date()
    @State private var showMaxGuardiansWarning = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header

                if isWatchActive {
                    activeView
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                } else {
                    setupView
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showContactPicker) {
            ContactPickerView { name, phone in
                addContactGuardian(name: name, phone: phone)
            }
        }
        .alert("Maximum \(watchMeGuardianMaxCount) guardians per walk.", isPresented: $showMaxGuardiansWarning) {
            Button("OK", role: .cancel) {}
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: "shield.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 22))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Watch Me")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Text("Quiet, automatic, peace of mind")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.85))
                }
                Spacer()
            }
            Text(headerCopy)
                .font(.system(size: 14))
                .lineSpacing(4)
                .foregroundColor(.white.opacity(0.95))
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [SafetyColors.blueDark, SafetyColors.blue],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private var headerCopy: String {
        if isWatchActive {
            return "You're being watched. Your guardians can see live location, route and check-ins. Tap end below when you've arrived safely."
        } else {
            return "Walking alone or somewhere unfamiliar? Pick someone to keep an eye on you. They'll get a private link with your live route, check-ins and an alert if anything looks off."
        }
    }

    // MARK: - Active state

    private var activeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Watch is active")
                .font(.system(size: 16, weight: .semibold))
            Text("Stop the watch when you've reached your destination. Your guardians will be told you arrived safely.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            Spacer().frame(height: 12)

            Button(action: { onStopWatch(); onDismiss() }) {
                Text("I've arrived safely")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(SafetyColors.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button(action: onDismiss) {
                Text("Keep watching")
                    .font(.system(size: 14))
                    .foregroundColor(SafetyColors.blue)
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
        }
    }

    // MARK: - Setup state

    private var setupView: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Who should keep an eye on you?")
            Spacer().frame(height: 8)

            if !guardians.isEmpty {
                guardianChipsList
                Spacer().frame(height: 8)
            }

            // Friend picker primary path. WoofWalk friends get the in-app
            // push + alarm experience. Listed first because it's the
            // better safety experience.
            Button(action: { /* TODO: friend picker — wire when friend list VM is available */ }) {
                HStack(spacing: 10) {
                    Image(systemName: "shield.fill")
                    Text("Pick a WoofWalk friend")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(SafetyColors.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(true)  // Friend picker not yet ported — phone path still works.
            .opacity(0.5)

            Spacer().frame(height: 8)

            // Contact picker secondary path. Anyone in your phone book
            // gets the SMS / WhatsApp link experience.
            Button(action: { showContactPicker = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.plus")
                    Text("Or pick a phone contact")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(SafetyColors.blue)
                .frame(maxWidth: .infinity, minHeight: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(SafetyColors.blue.opacity(0.4), lineWidth: 1.5)
                )
            }

            Spacer().frame(height: 4)
            Text("Friends get a live push + alarm. Contacts get an SMS link. We only see what you pick.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Spacer().frame(height: 20)
            sectionLabel("Expected back by (optional)")
            Spacer().frame(height: 8)
            etaPicker

            Spacer().frame(height: 20)
            sectionLabel("Note for your guardian (optional)")
            Spacer().frame(height: 8)
            ZStack(alignment: .topLeading) {
                if walkerNote.isEmpty {
                    Text("e.g. Heading along the canal, back by 9pm")
                        .font(.system(size: 14))
                        .foregroundColor(Color(.tertiaryLabel))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $walkerNote)
                    .font(.system(size: 14))
                    .frame(minHeight: 64, maxHeight: 96)
                    .padding(4)
                    .scrollContentBackground(.hidden)
                    .onChange(of: walkerNote) { newValue in
                        if newValue.count > 140 { walkerNote = String(newValue.prefix(140)) }
                    }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator), lineWidth: 1)
            )

            Spacer().frame(height: 24)

            Button(action: {
                let etaMs: Int64 = expectedReturnAt.map { Int64($0.timeIntervalSince1970 * 1000) } ?? 0
                onStart(guardians, walkerNote.trimmingCharacters(in: .whitespaces), etaMs)
            }) {
                ZStack {
                    if isStarting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        HStack(spacing: 10) {
                            Image(systemName: "shield.fill")
                            Text("Start Watch & send link")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background((guardians.isEmpty || isStarting) ? SafetyColors.blue.opacity(0.5) : SafetyColors.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(guardians.isEmpty || isStarting)

            Spacer().frame(height: 6)
            Text("You'll choose how to send the link (text, WhatsApp, etc.) — we never message anyone for you.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private var guardianChipsList: some View {
        VStack(spacing: 6) {
            ForEach(guardians) { guardian in
                HStack {
                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                        .foregroundColor(SafetyColors.blueDark)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(guardian.name)
                            .font(.system(size: 14))
                            .foregroundColor(SafetyColors.blueDark)
                        if let phone = guardian.phone, !phone.isEmpty {
                            Text(phone)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Button(action: { removeGuardian(guardian) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(SafetyColors.blueDark)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(SafetyColors.blue.opacity(0.1))
                .clipShape(Capsule())
            }
        }
    }

    private var etaPicker: some View {
        HStack(spacing: 4) {
            Button(action: { showTimePicker = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "clock")
                        .foregroundColor(SafetyColors.blue)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(etaLabel)
                            .font(.system(size: 15, weight: expectedReturnAt == nil ? .regular : .semibold))
                            .foregroundColor(expectedReturnAt == nil ? .secondary : .primary)
                        if expectedReturnAt == nil {
                            Text("Guardians get a heads-up if you're past due")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.separator), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if expectedReturnAt != nil {
                Button("Clear") { expectedReturnAt = nil }
                    .font(.system(size: 13))
                    .foregroundColor(SafetyColors.blue)
            }
        }
        .sheet(isPresented: $showTimePicker) {
            VStack {
                DatePicker("Expected back by", selection: $pendingTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding()
                Button("Done") {
                    // Roll over to tomorrow if the picked time is already past.
                    var target = Calendar.current.date(
                        bySettingHour: Calendar.current.component(.hour, from: pendingTime),
                        minute: Calendar.current.component(.minute, from: pendingTime),
                        second: 0,
                        of: Date()
                    ) ?? Date()
                    if target < Date() {
                        target = Calendar.current.date(byAdding: .day, value: 1, to: target) ?? target
                    }
                    expectedReturnAt = target
                    showTimePicker = false
                }
                .padding()
            }
            .presentationDetents([.medium])
        }
    }

    private var etaLabel: String {
        guard let eta = expectedReturnAt else { return "Tap to set ETA" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: eta)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.secondary)
            .kerning(0.4)
    }

    // MARK: - Guardian management

    private func addContactGuardian(name: String, phone: String) {
        // Hard cap matches the CF's MAX_GUARDIAN_PHONES (8).
        if guardians.count >= watchMeGuardianMaxCount {
            showMaxGuardiansWarning = true
            return
        }

        // Dedup by normalised phone number — name match alone misses
        // duplicates where the user picks the same contact under a
        // slightly different label, and lets a malicious paste queue
        // dozens of SMS to the same number.
        let normalised = normalisePhone(phone)
        let alreadyAdded = guardians.contains { existing in
            (existing.phone.map(normalisePhone) == normalised) ||
            existing.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }
        if !alreadyAdded {
            guardians.append(WatchMeGuardian(name: name, phone: phone))
        }
    }

    private func removeGuardian(_ guardian: WatchMeGuardian) {
        guardians.removeAll { $0.id == guardian.id }
    }

    private func normalisePhone(_ raw: String) -> String {
        return raw.filter { $0.isNumber || $0 == "+" }
    }
}

// MARK: - Contact picker bridge

/// UIKit bridge for `CNContactPickerViewController`. We intentionally use
/// the system picker (no `Contacts` permission required — the picker hands
/// back only the rows the user explicitly chooses).
struct ContactPickerView: UIViewControllerRepresentable {
    let onPick: (_ name: String, _ phone: String) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: (_ name: String, _ phone: String) -> Void

        init(onPick: @escaping (String, String) -> Void) { self.onPick = onPick }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
            guard let phoneNumber = contactProperty.value as? CNPhoneNumber else { return }
            let contact = contactProperty.contact
            let name = [contact.givenName, contact.familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
                .ifEmpty(default: phoneNumber.stringValue)
            onPick(name, phoneNumber.stringValue)
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            // Fallback for iOS picks where the user taps a contact rather
            // than a specific phone-row. Take the first phone number.
            guard let phone = contact.phoneNumbers.first?.value.stringValue else { return }
            let name = [contact.givenName, contact.familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
                .ifEmpty(default: phone)
            onPick(name, phone)
        }
    }
}

private extension String {
    func ifEmpty(default fallback: String) -> String {
        return self.isEmpty ? fallback : self
    }
}
