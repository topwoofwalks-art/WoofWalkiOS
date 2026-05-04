import SwiftUI

/// Top-of-thread confirmation card. Surfaces the agreed-on meet
/// time + location, and the conditional "Exact address unlocked"
/// reveal block once the CF flips `exactAddressRevealed = true`.
///
/// Bottom CTA — "Happy with [provider]?" — only shows once the
/// thread is `completed` so we don't push the up-sell before the
/// meet has actually happened.
struct MeetGreetConfirmedCard: View {
    let thread: MeetGreetThread
    let onBookNow: () -> Void

    @Environment(\.woofWalkTheme) private var theme

    private var dateText: String {
        guard let time = thread.confirmedTime ?? thread.proposedTime else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMM"
        return formatter.string(from: time.startDate)
    }

    private var timeText: String {
        guard let time = thread.confirmedTime ?? thread.proposedTime else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: time.startDate)
            + " · \(time.durationMin) min"
    }

    private var locationLabel: String {
        thread.confirmedTime?.locationLabel
            ?? thread.proposedTime?.locationLabel
            ?? "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header — confirmed badge + provider greeting
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.turquoise60)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Meet & Greet confirmed")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    Text("with \(thread.providerDisplayName)")
                        .font(.caption)
                        .foregroundColor(.neutral80)
                }
                Spacer()
            }

            Divider().background(Color.white.opacity(0.08))

            // Detail rows
            VStack(alignment: .leading, spacing: 12) {
                detailRow(icon: "calendar", label: "Date", value: dateText)
                detailRow(icon: "clock", label: "Time", value: timeText)
                detailRow(icon: "mappin.and.ellipse", label: "Where", value: locationLabel)
                detailRow(icon: "pawprint.fill", label: "Bringing", value: thread.clientDogName)
            }

            // Privacy reveal block — exact address only after both
            // sides confirm. The CF gates this server-side; the UI
            // just checks the flag.
            if thread.exactAddressRevealed, let address = thread.exactAddress, !address.isEmpty {
                addressRevealBlock(address: address)
            } else {
                addressLockedBlock()
            }

            // Post-meet up-sell — only after the meet is completed.
            if thread.status == .completed {
                Divider().background(Color.white.opacity(0.08))
                bookAfterCTA
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: 0x2F3033))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.turquoise60.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Address blocks

    private func addressRevealBlock(address: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "lock.open.fill")
                    .font(.caption)
                    .foregroundColor(.turquoise60)
                Text("Exact address unlocked")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.turquoise60)
            }
            Text(address)
                .font(.subheadline)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            // Phone / email — same trust gate.
            if let phone = thread.providerPhone, !phone.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "phone.fill")
                        .font(.caption2)
                        .foregroundColor(.neutral70)
                    if let url = URL(string: "tel:\(phone)") {
                        Link(phone, destination: url)
                            .font(.footnote)
                            .foregroundColor(.turquoise60)
                    } else {
                        Text(phone)
                            .font(.footnote)
                            .foregroundColor(.neutral80)
                    }
                }
            }
            if let email = thread.providerEmail, !email.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "envelope.fill")
                        .font(.caption2)
                        .foregroundColor(.neutral70)
                    Text(email)
                        .font(.footnote)
                        .foregroundColor(.neutral80)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.turquoise60.opacity(0.10))
        )
    }

    private func addressLockedBlock() -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.subheadline)
                .foregroundColor(.neutral70)
            VStack(alignment: .leading, spacing: 2) {
                Text("Exact address unlocked after your meet & greet")
                    .font(.caption)
                    .foregroundColor(.neutral80)
                Text("Your details stay private until you both confirm.")
                    .font(.caption2)
                    .foregroundColor(.neutral60)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - Detail row helper

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundColor(.turquoise60)
                .frame(width: 18, alignment: .leading)
            Text(label)
                .font(.caption)
                .foregroundColor(.neutral70)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Book-after CTA

    private var bookAfterCTA: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Happy with \(thread.providerDisplayName)?")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            Text("Book a full service with one tap.")
                .font(.caption)
                .foregroundColor(.neutral70)
            Button(action: onBookNow) {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                    Text("Book Now")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.turquoise60))
                .foregroundColor(.black)
            }
        }
    }
}
