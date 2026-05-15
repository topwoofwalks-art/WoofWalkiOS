import SwiftUI
import FirebaseFunctions
import FirebaseAuth

/// Sheet that lets a client send a one-tap tip to the walker on their
/// just-completed booking. Mirrors Android
/// `ui/walk/TipSheet.kt` — quick-amount buttons (£2 / £5 / £10 / custom)
/// then a Submit that fires the `processTip` Cloud Function. Success
/// dismisses with a haptic + a brief "Thanks!" toast on the recap.
///
/// The CF (`functions/src/index.ts → processTip`) takes:
///   - `bookingId`: string (required)
///   - `amountGbp`: number (required, GBP, positive)
///   - `paymentMethodId`: string (optional — falls through to the
///     client's saved default payment method if omitted)
///
/// Server enforces `context.auth.uid === booking.clientId`, so this
/// sheet only ever needs to surface a sensible default amount + custom
/// input. Stripe Connect routing happens server-side off `booking.orgId`.
struct TipWalkerSheet: View {
    let walkerName: String
    let walkerUid: String
    let bookingId: String
    /// Suggested default tip in pence (e.g. 500 for £5). Driven by the
    /// caller — usually a fraction of the booking price. Clamped to the
    /// nearest preset for display.
    let suggestedTip: Int

    /// Closure called with the tip amount in pence after the CF returns
    /// success. Caller is responsible for closing the sheet + surfacing
    /// the "Thanks!" toast on the recap.
    let onSuccess: (Int) -> Void
    let onCancel: () -> Void

    @State private var selectedPence: Int
    @State private var isCustom: Bool = false
    @State private var customText: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    /// Preset tip amounts in pence — same set as Android (`TipSheet.kt`).
    private static let presets: [Int] = [200, 500, 1000]

    private let functions = Functions.functions(region: "europe-west2")

    init(
        walkerName: String,
        walkerUid: String,
        bookingId: String,
        suggestedTip: Int,
        onSuccess: @escaping (Int) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.walkerName = walkerName
        self.walkerUid = walkerUid
        self.bookingId = bookingId
        self.suggestedTip = suggestedTip
        self.onSuccess = onSuccess
        self.onCancel = onCancel
        // Pre-select the nearest preset to the suggested tip so the user
        // can submit in one tap on the default amount.
        let nearest = Self.presets.min(by: { abs($0 - suggestedTip) < abs($1 - suggestedTip) }) ?? 500
        _selectedPence = State(initialValue: nearest)
    }

    /// Effective tip amount (in pence) — driven by either the preset
    /// selection or the parsed custom input. Returns 0 when the custom
    /// text is empty/invalid so the Submit button can stay disabled.
    private var effectivePence: Int {
        if isCustom {
            // Custom input is in pounds (e.g. "7.50"). Convert to pence.
            let trimmed = customText.trimmingCharacters(in: .whitespaces)
            guard let pounds = Double(trimmed), pounds > 0 else { return 0 }
            return Int((pounds * 100).rounded())
        }
        return selectedPence
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    header

                    presetsRow

                    customButton
                    if isCustom { customField }

                    if let err = errorMessage {
                        Text(err)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    submitButton

                    Button(action: onCancel) {
                        Text("Maybe later")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 12)
                }
                .padding()
            }
            .navigationTitle("Tip your walker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onCancel)
                }
            }
        }
    }

    // MARK: - Sub-views

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "heart.fill")
                .font(.system(size: 36))
                .foregroundColor(.pink)
            Text("Thank \(walkerName)")
                .font(.title3.bold())
            Text("100% of your tip goes to the walker's business.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var presetsRow: some View {
        HStack(spacing: 10) {
            ForEach(Self.presets, id: \.self) { pence in
                presetButton(pence)
            }
        }
    }

    private func presetButton(_ pence: Int) -> some View {
        let isSelected = !isCustom && selectedPence == pence
        return Button {
            isCustom = false
            selectedPence = pence
            errorMessage = nil
        } label: {
            Text(formatPounds(pence))
                .font(.title3.bold())
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? Color.turquoise60.opacity(0.18) : Color.gray.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color.turquoise60 : Color.gray.opacity(0.3),
                                lineWidth: isSelected ? 2 : 1)
                )
                .foregroundColor(isSelected ? .turquoise60 : .primary)
        }
        .disabled(isSubmitting)
    }

    private var customButton: some View {
        Button {
            isCustom = true
            errorMessage = nil
        } label: {
            HStack {
                Image(systemName: "pencil.line")
                Text(isCustom ? "Custom amount" : "Enter custom amount")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isCustom ? Color.turquoise60.opacity(0.10) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isCustom ? Color.turquoise60 : Color.gray.opacity(0.3),
                            lineWidth: isCustom ? 2 : 1)
            )
            .foregroundColor(isCustom ? .turquoise60 : .primary)
        }
        .disabled(isSubmitting)
    }

    private var customField: some View {
        HStack(spacing: 8) {
            Text("£")
                .font(.title3.bold())
                .foregroundColor(.secondary)
            TextField("0.00", text: $customText)
                .keyboardType(.decimalPad)
                .font(.title3)
                .disableAutocorrection(true)
                .onChange(of: customText) { _, newValue in
                    // Keep only digits + at most one decimal point, max 2 dp.
                    customText = sanitiseDecimal(newValue)
                }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.08))
        )
    }

    private var submitButton: some View {
        Button {
            submit()
        } label: {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
                Text(isSubmitting
                     ? "Sending..."
                     : "Send \(formatPounds(effectivePence)) tip")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(effectivePence > 0 ? Color.turquoise60 : Color.gray.opacity(0.4))
            )
            .foregroundColor(.white)
        }
        .disabled(effectivePence <= 0 || isSubmitting)
    }

    // MARK: - Submit

    private func submit() {
        let pence = effectivePence
        guard pence > 0 else { return }
        guard !bookingId.isEmpty else {
            errorMessage = "Missing booking id — can't process tip."
            return
        }
        guard Auth.auth().currentUser != nil else {
            errorMessage = "You need to be signed in to send a tip."
            return
        }
        errorMessage = nil
        isSubmitting = true

        let payload: [String: Any] = [
            "bookingId": bookingId,
            "amountGbp": Double(pence) / 100.0
        ]

        Task { @MainActor in
            do {
                _ = try await functions.httpsCallable("processTip").call(payload)
                isSubmitting = false
                // Haptic on success — same notification feedback the
                // Android sheet plays on submit-confirm.
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                onSuccess(pence)
            } catch {
                isSubmitting = false
                errorMessage = "Couldn't send tip: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Helpers

    private func formatPounds(_ pence: Int) -> String {
        let pounds = Double(pence) / 100.0
        // Whole-pound presets render as "£5" not "£5.00".
        if pence % 100 == 0 {
            return "£\(Int(pounds))"
        }
        return String(format: "£%.2f", pounds)
    }

    private func sanitiseDecimal(_ input: String) -> String {
        // Allow up to 4 digits before the point + 2 after. Mirrors
        // Android TipSheet.kt regex `^\d{0,4}(\.\d{0,2})?$`.
        let allowed = input.filter { $0.isNumber || $0 == "." }
        guard let _ = allowed.range(of: #"^\d{0,4}(\.\d{0,2})?$"#, options: .regularExpression) else {
            // Fall back to truncating at first invalid character.
            var sanitised = ""
            var dotSeen = false
            var afterDot = 0
            var beforeDot = 0
            for ch in allowed {
                if ch == "." {
                    if dotSeen { continue }
                    dotSeen = true
                    sanitised.append(ch)
                } else if dotSeen {
                    if afterDot < 2 {
                        sanitised.append(ch); afterDot += 1
                    }
                } else {
                    if beforeDot < 4 {
                        sanitised.append(ch); beforeDot += 1
                    }
                }
            }
            return sanitised
        }
        return allowed
    }
}
