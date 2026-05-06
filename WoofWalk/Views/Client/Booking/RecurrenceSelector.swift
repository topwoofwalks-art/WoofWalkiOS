import SwiftUI

/// Recurrence selector for the booking-create flow. Renders a "Repeat
/// this booking" toggle, frequency chips when enabled, and an end-by
/// picker (date OR max-occurrences). Mirrors the Android composable at
/// `app/src/main/java/com/woofwalk/ui/client/booking/RecurrenceSelector.kt`
/// — frequency options + UX patterns are intentionally identical so a
/// recurring booking created on iOS shows up on Android (and vice
/// versa) with the same chip label.
///
/// The selector is bound to a `RecurrencePattern?` — nil means the
/// booking is one-off, non-nil means the user opted in. The booking-
/// create VM serialises this into the `recurrence` payload key the
/// `createClientBooking` Cloud Function accepts.
struct RecurrenceSelector: View {
    /// The base date of the parent booking — used to compute preview
    /// dates ("Upcoming dates" list) so the user can sanity-check the
    /// schedule before they confirm.
    let baseDate: Date

    /// Two-way binding to the recurrence pattern. nil = one-off.
    @Binding var pattern: RecurrencePattern?

    @State private var endByMode: EndByMode = .noEndDate
    @State private var maxOccurrencesText: String = "8"
    @State private var showDatePicker = false

    private enum EndByMode: String, CaseIterable, Identifiable {
        case noEndDate
        case endDate
        case occurrences

        var id: String { rawValue }
        var label: String {
            switch self {
            case .noEndDate:    return "No end date"
            case .endDate:      return "On a date"
            case .occurrences:  return "After N times"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "repeat")
                    .foregroundColor(.turquoise60)
                Text("Repeat this booking")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
                Toggle("", isOn: enabledBinding)
                    .labelsHidden()
                    .tint(.turquoise60)
            }

            if pattern != nil {
                // Frequency chips
                Text("How often")
                    .font(.caption.bold())
                    .foregroundColor(.neutral60)

                HStack(spacing: 8) {
                    ForEach(RecurrenceFrequency.allCases) { freq in
                        frequencyChip(freq)
                    }
                }

                // End-by mode picker
                Text("Ends")
                    .font(.caption.bold())
                    .foregroundColor(.neutral60)
                    .padding(.top, 4)

                VStack(spacing: 8) {
                    ForEach(EndByMode.allCases) { mode in
                        endByRow(mode)
                    }
                }

                // Preview dates — first occurrence + next 4 in the series
                if let preview = previewDates(), !preview.isEmpty {
                    Divider().background(Color.neutral20).padding(.vertical, 4)

                    Text("Upcoming dates")
                        .font(.caption.bold())
                        .foregroundColor(.neutral60)

                    VStack(spacing: 4) {
                        previewDateRow(baseDate, isFirst: true)
                        ForEach(preview, id: \.self) { date in
                            previewDateRow(date, isFirst: false)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.neutral20)
        )
        .onChange(of: endByMode) { mode in
            applyEndByMode(mode)
        }
        .onChange(of: maxOccurrencesText) { newValue in
            if endByMode == .occurrences {
                let count = Int(newValue) ?? 0
                pattern?.maxOccurrences = count > 0 ? count : nil
                pattern?.endDate = nil
            }
        }
        .sheet(isPresented: $showDatePicker) {
            datePickerSheet
        }
    }

    // MARK: - Bindings

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { pattern != nil },
            set: { isOn in
                if isOn {
                    // Default to weekly + no-end-date — most common
                    // pattern. User can switch immediately.
                    pattern = RecurrencePattern(
                        frequency: .weekly,
                        interval: 1,
                        endDate: nil,
                        maxOccurrences: nil
                    )
                    endByMode = .noEndDate
                } else {
                    pattern = nil
                }
            }
        )
    }

    // MARK: - Frequency chip

    private func frequencyChip(_ freq: RecurrenceFrequency) -> some View {
        let isSelected = pattern?.frequency == freq
        return Button {
            pattern?.frequency = freq
        } label: {
            Text(freq.displayName)
                .font(.caption.bold())
                .foregroundColor(isSelected ? .white : .neutral60)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.turquoise60 : Color.neutral10)
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? Color.clear : Color.neutral30,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - End-by row

    @ViewBuilder
    private func endByRow(_ mode: EndByMode) -> some View {
        let isSelected = endByMode == mode
        Button {
            endByMode = mode
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? .turquoise60 : .neutral40)
                Text(mode.label)
                    .font(.subheadline)
                    .foregroundColor(.white)
                Spacer()

                if mode == .endDate, isSelected {
                    Button {
                        showDatePicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption)
                            Text(pattern?.endDate.map { Self.dateFormatter.string(from: $0) } ?? "Pick a date")
                                .font(.caption.bold())
                        }
                        .foregroundColor(.turquoise60)
                    }
                }

                if mode == .occurrences, isSelected {
                    HStack(spacing: 6) {
                        TextField("8", text: $maxOccurrencesText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .frame(width: 50)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.neutral10)
                            )
                            .foregroundColor(.white)
                        Text("times")
                            .font(.caption)
                            .foregroundColor(.neutral60)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Preview dates

    private func previewDateRow(_ date: Date, isFirst: Bool) -> some View {
        HStack {
            Text(Self.dateFormatter.string(from: date))
                .font(.caption)
                .foregroundColor(isFirst ? .white : .neutral60)
            Spacer()
            if isFirst {
                Text("FIRST")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color.turquoise60)
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isFirst ? Color.turquoise60.opacity(0.15) : Color.neutral10)
        )
    }

    /// Generate up to 4 preview dates after the base date, applying the
    /// currently-selected pattern. Mirrors Android's
    /// `generatePreviewDates`. Returns nil when no pattern is set.
    private func previewDates() -> [Date]? {
        guard let pattern = pattern else { return nil }
        let cal = Calendar.current
        var dates: [Date] = []
        var current = baseDate
        let endDate = pattern.endDate
        let cap = pattern.maxOccurrences ?? 4
        let maxPreview = min(cap > 0 ? cap - 1 : 4, 4)

        for _ in 0..<maxPreview {
            let next: Date?
            switch pattern.frequency {
            case .daily:
                next = cal.date(byAdding: .day, value: max(1, pattern.interval), to: current)
            case .weekly:
                next = cal.date(byAdding: .weekOfYear, value: max(1, pattern.interval), to: current)
            case .biweekly:
                next = cal.date(byAdding: .weekOfYear, value: 2 * max(1, pattern.interval), to: current)
            case .monthly:
                next = cal.date(byAdding: .month, value: max(1, pattern.interval), to: current)
            }
            guard let candidate = next else { break }
            if let endDate = endDate, candidate > endDate { break }
            dates.append(candidate)
            current = candidate
        }
        return dates
    }

    // MARK: - End-by mode plumbing

    private func applyEndByMode(_ mode: EndByMode) {
        guard pattern != nil else { return }
        switch mode {
        case .noEndDate:
            pattern?.endDate = nil
            pattern?.maxOccurrences = nil
        case .endDate:
            pattern?.maxOccurrences = nil
            // Default to 8 weeks out if user hasn't picked yet — gives
            // them a sensible visible date to start from.
            if pattern?.endDate == nil {
                pattern?.endDate = Calendar.current.date(
                    byAdding: .weekOfYear,
                    value: 8,
                    to: baseDate
                )
            }
        case .occurrences:
            pattern?.endDate = nil
            let count = Int(maxOccurrencesText) ?? 8
            pattern?.maxOccurrences = count > 0 ? count : 8
        }
    }

    // MARK: - Date picker sheet

    @ViewBuilder
    private var datePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                DatePicker(
                    "End by",
                    selection: Binding(
                        get: { pattern?.endDate ?? minimumEndDate },
                        set: { newDate in
                            pattern?.endDate = newDate
                            pattern?.maxOccurrences = nil
                        }
                    ),
                    in: minimumEndDate...,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .tint(.turquoise60)
                .padding()

                Spacer()
            }
            .navigationTitle("Series ends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showDatePicker = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var minimumEndDate: Date {
        // The earliest valid end-date is one full step after the base
        // date — picking anything before that would mean a series with
        // exactly one occurrence (use a one-off booking instead).
        guard let pattern = pattern else { return baseDate }
        let cal = Calendar.current
        switch pattern.frequency {
        case .daily:
            return cal.date(byAdding: .day, value: 1, to: baseDate) ?? baseDate
        case .weekly:
            return cal.date(byAdding: .weekOfYear, value: 1, to: baseDate) ?? baseDate
        case .biweekly:
            return cal.date(byAdding: .weekOfYear, value: 2, to: baseDate) ?? baseDate
        case .monthly:
            return cal.date(byAdding: .month, value: 1, to: baseDate) ?? baseDate
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d, yyyy"
        return f
    }()
}
