import SwiftUI

struct MyPacksView: View {
    @StateObject private var packRepo = PackRepository()

    var body: some View {
        Group {
            if packRepo.packs.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(packRepo.packs) { pack in
                            PackCard(pack: pack)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("My Packs")
        .onAppear { packRepo.observeMyPacks() }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "shippingbox")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No packs yet")
                .font(.title3.bold())
                .foregroundColor(.secondary)
            Text("Purchase a bulk pack from a provider\nto save on recurring sessions")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Pack Card

private struct PackCard: View {
    let pack: ClientPack

    private var progress: Double {
        guard pack.totalSessions > 0 else { return 0 }
        return Double(pack.usedSessions) / Double(pack.totalSessions)
    }

    private var serviceColor: Color {
        switch pack.serviceType.lowercased() {
        case "walking", "walk": return .green
        case "grooming", "groom": return .purple
        case "training", "train": return .orange
        case "daycare": return .blue
        default: return .gray
        }
    }

    private var serviceIcon: String {
        switch pack.serviceType.lowercased() {
        case "walking", "walk": return "figure.walk"
        case "grooming", "groom": return "scissors"
        case "training", "train": return "graduationcap"
        case "daycare": return "house"
        default: return "pawprint"
        }
    }

    private var serviceLabel: String {
        switch pack.serviceType.lowercased() {
        case "walking", "walk": return "Walk"
        case "grooming", "groom": return "Grooming"
        case "training", "train": return "Training"
        case "daycare": return "Daycare"
        default: return pack.serviceType.capitalized
        }
    }

    private var isExpiringSoon: Bool {
        guard let exp = pack.expiresAt else { return false }
        let daysLeft = exp.dateValue().timeIntervalSince(Date()) / 86400
        return daysLeft >= 0 && daysLeft <= 7
    }

    private var expiryText: String? {
        guard let exp = pack.expiresAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        let dateStr = formatter.string(from: exp.dateValue())
        return pack.isExpired ? "Expired \(dateStr)" : "Expires \(dateStr)"
    }

    private var priceText: String? {
        guard pack.pricePerSession > 0 else { return nil }
        let formatted = String(format: "\u{00A3}%.2f", pack.pricePerSession)
        return "\(formatted)/session"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(serviceColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: serviceIcon)
                        .font(.system(size: 20))
                        .foregroundColor(serviceColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(pack.totalSessions)-Session \(serviceLabel) Pack")
                        .font(.headline)
                    Text("\(pack.remainingSessions) sessions remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            // Progress bar
            VStack(spacing: 6) {
                ProgressView(value: progress)
                    .tint(serviceColor)

                HStack {
                    Text("\(pack.usedSessions) used")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(pack.totalSessions) total")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Info row
            HStack {
                if let expiry = expiryText {
                    HStack(spacing: 4) {
                        if isExpiringSoon || pack.isExpired {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                        Text(expiry)
                            .font(.caption)
                            .foregroundColor(isExpiringSoon || pack.isExpired ? .red : .secondary)
                    }
                }
                Spacer()
                if let price = priceText {
                    Text(price)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }

            // Use button
            if pack.isUsable {
                Button {
                    // Navigate to booking with pack pre-selected
                } label: {
                    Text("Use on Next Booking")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(pack.isUsable ? Color(.systemBackground) : Color(.secondarySystemBackground).opacity(0.6))
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
        .opacity(pack.isUsable ? 1 : 0.7)
    }
}

#Preview {
    NavigationStack {
        MyPacksView()
    }
}
