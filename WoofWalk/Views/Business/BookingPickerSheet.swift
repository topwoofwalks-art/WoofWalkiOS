import SwiftUI

/// Phase 5 multi-select picker shown before a group-walk live share is
/// created. The walker picks the subset of households that should
/// receive the live link instead of the previous auto-fan-to-all
/// behaviour. Solo walks bypass this sheet entirely.
///
/// Each row shows the client name, the dogs in scope (best-effort —
/// `dogNames` may be empty when the booking doc only carries a single
/// `dogName` field), and a contact-availability hint. The primary CTA
/// reads "Send to N clients" so the walker sees the fan-out size at a
/// glance before committing.
///
/// Mirrors the Android Phase 5 picker shape that's landing in parallel
/// (see `WalkConsoleScreen.kt` BookingPickerSheet composable).
struct BookingPickerSheet: View {
    let candidates: [BookingShareTarget]
    let selectedIds: Set<String>
    let isLoading: Bool
    let onToggle: (String) -> Void
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var selectedCount: Int {
        candidates.filter { selectedIds.contains($0.bookingId) }.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading bookings…")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if candidates.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No bookings to share with")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    bookingList
                }
            }
            .navigationTitle("Share with")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !candidates.isEmpty {
                    confirmBar
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - List

    private var bookingList: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Pick the clients who should get the live walk link.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                ForEach(candidates) { target in
                    bookingRow(target)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func bookingRow(_ target: BookingShareTarget) -> some View {
        let isSelected = selectedIds.contains(target.bookingId)
        return Button {
            onToggle(target.bookingId)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Selection checkbox — same shape as iOS share-sheet
                // multi-pickers so the affordance reads correctly.
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? AppColors.Dark.primary : Color(.systemGray3))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(target.clientName)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)

                    if !target.dogNames.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "pawprint.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(target.dogNames.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Phone vs no-phone hint — clients without a phone
                    // can still get a copyable URL, but no WhatsApp/SMS
                    // quick-send rows. Surface here so the walker knows
                    // the fan-out shape before confirming.
                    if let phone = target.clientPhone, !phone.isEmpty {
                        Label("WhatsApp & SMS", systemImage: "phone.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Label("Copy link only", systemImage: "doc.on.doc")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected
                          ? AppColors.Dark.primary.opacity(0.08)
                          : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected
                            ? AppColors.Dark.primary.opacity(0.4)
                            : Color.clear,
                            lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Confirm bar

    private var confirmBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                onConfirm()
            } label: {
                Text(confirmLabel)
                    .font(.body.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.Dark.primary)
            .disabled(selectedCount == 0)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
    }

    private var confirmLabel: String {
        switch selectedCount {
        case 0: return "Pick at least one client"
        case 1: return "Send to 1 client"
        default: return "Send to \(selectedCount) clients"
        }
    }
}

#Preview {
    BookingPickerSheet(
        candidates: [
            BookingShareTarget(bookingId: "b1", clientName: "Sarah Kowalski",
                               clientPhone: "+447700900000",
                               dogNames: ["Bella", "Max"], perClientUrl: ""),
            BookingShareTarget(bookingId: "b2", clientName: "Tom Reeves",
                               clientPhone: nil,
                               dogNames: ["Rex"], perClientUrl: ""),
            BookingShareTarget(bookingId: "b3", clientName: "Aisha Khan",
                               clientPhone: "+447700900001",
                               dogNames: [], perClientUrl: "")
        ],
        selectedIds: ["b1", "b3"],
        isLoading: false,
        onToggle: { _ in },
        onConfirm: {},
        onCancel: {}
    )
}
