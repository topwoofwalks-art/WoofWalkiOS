import SwiftUI
import FirebaseAuth
import FirebaseFunctions

/// RemoveListingSheet — GDPR right-to-be-forgotten flow for unclaimed
/// (scraped) business listings. iOS counterpart to the portal's
/// `RemoveListingDialog.tsx`.
///
/// Two channels, two mechanisms (deliberate — see portal comment for
/// the full rationale):
///
///   * **Email** — `requestRemoveUnclaimedListing` →
///     `confirmRemoveUnclaimedListing`. Standard server-side OTP: CF
///     generates a 6-digit code, sends via SMTP, user types it back,
///     CF deletes the listing.
///
///   * **Phone** — Firebase Phone Auth end-to-end. The client calls
///     `Auth.auth().verifyPhoneNumber(...)`; Firebase generates + sends
///     its own SMS, the user types the code, the client signs in with
///     the resulting `PhoneAuthCredential`, the auth token now carries
///     a `phone_number` claim. We then call
///     `removeUnclaimedListingByPhone` which checks the auth token's
///     phone matches the listing's on-file phone, deletes, and cleans
///     up the throwaway auth user server-side.
///
/// Auth NOT required to enter the sheet — the listing might predate
/// any user account. The phone path creates a transient Firebase Auth
/// session as a side-effect of verification; we **sign out** on every
/// failure path so stranded phone-only Auth users don't accumulate
/// (mirrors RemoveListingDialog.tsx lines 198-206).
struct RemoveListingSheet: View {
    let unclaimedId: String
    let businessName: String?

    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .pick
    @State private var channel: Channel = .email
    @State private var phoneInput: String = ""
    @State private var requestId: String?
    @State private var maskedTarget: String?
    @State private var verificationId: String?
    @State private var code: String = ""
    @State private var busy: Bool = false
    @State private var errorMessage: String?

    private let functions = Functions.functions(region: "europe-west2")

    enum Phase: String { case pick, enterPhone, verifyEmail, verifyPhone, done }
    enum Channel { case email, phone }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.neutral10.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let name = businessName, !name.isEmpty {
                            Text(name)
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.neutral90)
                        }

                        switch phase {
                        case .pick:
                            pickChannelView
                        case .enterPhone:
                            enterPhoneView
                        case .verifyEmail:
                            verifyEmailView
                        case .verifyPhone:
                            verifyPhoneView
                        case .done:
                            doneView
                        }

                        if let err = errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.error60)
                                .padding(.top, 4)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Remove this listing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.turquoise60)
                }
            }
        }
    }

    // MARK: - Phase: pick

    private var pickChannelView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Listings on the public directory are scraped from open business data and sometimes appear without consent. To remove this listing we need to verify you're the owner — choose how:")
                .font(.body)
                .foregroundColor(.neutral80)

            HStack(spacing: 10) {
                channelChip(label: "Email on file", isSelected: channel == .email) {
                    channel = .email
                }
                channelChip(label: "Phone (SMS)", isSelected: channel == .phone) {
                    channel = .phone
                }
            }

            primaryButton(title: busy ? "Working…" : "Continue") {
                Task { await onContinueFromPick() }
            }
            .disabled(busy)
        }
    }

    private func channelChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.turquoise60 : Color.neutral20)
                .foregroundColor(isSelected ? .neutral10 : .neutral90)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.turquoise60 : Color.neutral40, lineWidth: 1)
                )
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Phase: enter phone

    private var enterPhoneView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enter the phone number registered for this listing.")
                .font(.body)
                .foregroundColor(.neutral80)

            Text("We'll send a code to that number to verify ownership. UK numbers starting with 07 work; other formats need the country code (+44…).")
                .font(.caption)
                .foregroundColor(.neutral70)

            TextField("07xxx xxxxxx", text: $phoneInput)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .padding(10)
                .background(Color.neutral20)
                .cornerRadius(8)
                .foregroundColor(.neutral90)

            HStack {
                secondaryButton(title: "Back") {
                    phase = .pick
                    errorMessage = nil
                }
                primaryButton(title: busy ? "Sending…" : "Send code") {
                    Task { await sendPhoneCode() }
                }
                .disabled(busy || phoneInput.trimmingCharacters(in: .whitespaces).count < 7)
            }
        }
    }

    // MARK: - Phase: verify email

    private var verifyEmailView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let target = maskedTarget {
                Text("We sent a code to \(target).")
                    .font(.body)
                    .foregroundColor(.neutral80)
            }
            Text("Codes expire after 24 hours. After 5 failed attempts the request locks.")
                .font(.caption)
                .foregroundColor(.neutral70)

            codeInputField

            HStack {
                secondaryButton(title: "Resend") {
                    phase = .pick
                    code = ""
                    errorMessage = nil
                }
                primaryButton(title: busy ? "Removing…" : "Confirm removal") {
                    Task { await confirmEmail() }
                }
                .disabled(busy || code.count != 6)
            }
        }
    }

    // MARK: - Phase: verify phone

    private var verifyPhoneView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("We sent a 6-digit code by SMS to \(phoneInput).")
                .font(.body)
                .foregroundColor(.neutral80)
            Text("If it doesn't arrive within a minute, go back and try again.")
                .font(.caption)
                .foregroundColor(.neutral70)

            codeInputField

            HStack {
                secondaryButton(title: "Back") {
                    phase = .enterPhone
                    code = ""
                    errorMessage = nil
                }
                primaryButton(title: busy ? "Removing…" : "Confirm removal") {
                    Task { await confirmPhone() }
                }
                .disabled(busy || code.count != 6)
            }
        }
    }

    private var codeInputField: some View {
        TextField("6-digit code", text: $code)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .multilineTextAlignment(.center)
            .font(.system(size: 22, weight: .semibold, design: .monospaced))
            .padding(12)
            .background(Color.neutral20)
            .foregroundColor(.neutral90)
            .cornerRadius(8)
            .onChange(of: code) { newVal in
                let filtered = newVal.filter { $0.isNumber }
                let trimmed = String(filtered.prefix(6))
                if trimmed != newVal { code = trimmed }
            }
    }

    // MARK: - Phase: done

    private var doneView: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundColor(.success60)
            Text("Listing removed.")
                .font(.headline)
                .foregroundColor(.neutral90)
            Text("It may take a few minutes to disappear from search results.")
                .font(.caption)
                .foregroundColor(.neutral70)
                .multilineTextAlignment(.center)
            primaryButton(title: "Close") { dismiss() }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    // MARK: - Buttons

    private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.error60)
                .foregroundColor(.neutral10)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.neutral20)
                .foregroundColor(.neutral90)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.neutral40, lineWidth: 1)
                )
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Flow handlers

    private func onContinueFromPick() async {
        errorMessage = nil
        switch channel {
        case .email:
            busy = true
            defer { busy = false }
            do {
                let result = try await functions
                    .httpsCallable("requestRemoveUnclaimedListing")
                    .call(["unclaimedId": unclaimedId])
                guard let data = result.data as? [String: Any] else {
                    errorMessage = "Server returned an unexpected response"
                    return
                }
                requestId = data["requestId"] as? String
                maskedTarget = data["target"] as? String
                phase = .verifyEmail
            } catch {
                errorMessage = (error as NSError).localizedDescription
            }
        case .phone:
            phase = .enterPhone
        }
    }

    private func sendPhoneCode() async {
        errorMessage = nil

        // Refuse if user is already signed in with a non-phone account
        // — Phone Auth would replace their session. Mirrors portal
        // RemoveListingDialog.tsx lines 141-145.
        if let current = Auth.auth().currentUser, current.phoneNumber == nil {
            errorMessage = "You are signed into another WoofWalk account. Sign out and try again, or verify via email."
            return
        }

        let formatted = formatPhoneNumber(phoneInput)
        busy = true
        defer { busy = false }

        do {
            let id = try await PhoneAuthProvider.provider()
                .verifyPhoneNumber(formatted, uiDelegate: nil)
            verificationId = id
            phase = .verifyPhone
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }

    private func confirmEmail() async {
        guard let rid = requestId, !code.isEmpty else { return }
        busy = true
        defer { busy = false }
        errorMessage = nil
        do {
            _ = try await functions
                .httpsCallable("confirmRemoveUnclaimedListing")
                .call([
                    "requestId": rid,
                    "code": code.trimmingCharacters(in: .whitespaces)
                ])
            phase = .done
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }

    private func confirmPhone() async {
        guard let vid = verificationId, code.count == 6 else { return }
        busy = true
        defer { busy = false }
        errorMessage = nil

        var didConfirm = false
        do {
            // Step 1 — finish the Phone Auth flow. This signs the
            // device in as a phone-only Firebase user; the ID token
            // now carries the `phone_number` claim.
            let credential = PhoneAuthProvider.provider()
                .credential(withVerificationID: vid, verificationCode: code.trimmingCharacters(in: .whitespaces))
            _ = try await Auth.auth().signIn(with: credential)
            didConfirm = true

            // Step 2 — call the CF, which checks the phone matches the
            // listing and deletes. CF cleans up the throwaway auth
            // user on success. On failure (wrong phone, expired
            // listing, etc) the CF throws and the auth user persists
            // — we sign out below.
            let result = try await functions
                .httpsCallable("removeUnclaimedListingByPhone")
                .call(["unclaimedId": unclaimedId])

            // Always sign out the throwaway phone-only Auth user after
            // the CF replies — even on success, since the CF only
            // best-effort cleans up the auth user. Same belt-and-
            // braces as the portal version.
            try? Auth.auth().signOut()

            guard let data = result.data as? [String: Any],
                  let success = data["success"] as? Bool, success else {
                errorMessage = "Server rejected the removal"
                return
            }
            phase = .done
        } catch {
            // Critical: every failure path of the phone flow must
            // signOut() so stranded phone-only Auth users don't
            // accumulate. The CF-side cleanup only fires on success.
            if didConfirm {
                try? Auth.auth().signOut()
            }
            errorMessage = (error as NSError).localizedDescription
        }
    }

    /// Best-effort UK phone formatting. Numbers starting with `+` pass
    /// through; numbers starting with `0` get the leading 0 swapped
    /// for `+44`; everything else passes through unmodified (the
    /// server / Firebase handles the rest).
    private func formatPhoneNumber(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("+") { return trimmed }
        if trimmed.hasPrefix("0") {
            return "+44" + String(trimmed.dropFirst())
        }
        return trimmed
    }
}
