import SwiftUI

/// Phase 5 client-side recap section. Renders above (or alongside) the
/// existing booking-detail / walk-completion surfaces when a business
/// walker shared a live walk for this client's booking. Mirrors the
/// portal's RecapHero + Photos gallery + WalkerNote + BrandedThanks
/// shapes from `LiveTrackingPublicPage.tsx` (commit f06e847).
///
/// Lifecycle:
/// - Mounted with a `bookingId`. On appear, the embedded ViewModel
///   fetches the matching live-share recap from
///   `BusinessLiveShareRepository.fetchRecapForBooking`.
/// - If no share exists, or the share has no human content (no
///   photos, no walker note), the section renders nothing — the
///   booking-detail screen below it is the canonical view.
/// - If a share exists, renders Hero → Walker note → Photos gallery
///   → Branded thanks. Matches the portal's order so a client moving
///   between web and app gets the same memory keepsake layout.
@MainActor
final class BusinessLiveShareRecapViewModel: ObservableObject {
    @Published private(set) var recap: BusinessLiveShareRecap?
    @Published private(set) var isLoading: Bool = false

    private let repo: BusinessLiveShareRepository
    private var loadedBookingId: String?

    init(repo: BusinessLiveShareRepository = .shared) {
        self.repo = repo
    }

    /// Idempotent for the same `bookingId` — re-calls within the same
    /// VM lifetime are no-ops, so attaching this view to a parent that
    /// re-renders isn't a perf trap.
    func load(bookingId: String) {
        guard bookingId != loadedBookingId else { return }
        loadedBookingId = bookingId
        isLoading = true
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let result = try await self.repo.fetchRecapForBooking(bookingId: bookingId)
                self.recap = result
            } catch {
                // Soft-fail — the rest of the booking-detail screen
                // is still useful if the recap can't load.
                print("[BusinessLiveShareRecap] fetch failed for \(bookingId): \(error)")
                self.recap = nil
            }
            self.isLoading = false
        }
    }
}

struct BusinessLiveShareRecapSection: View {
    let bookingId: String

    @StateObject private var viewModel = BusinessLiveShareRecapViewModel()

    var body: some View {
        Group {
            if let recap = viewModel.recap, recap.hasContent {
                content(recap: recap)
            } else {
                EmptyView()
            }
        }
        .onAppear { viewModel.load(bookingId: bookingId) }
    }

    // MARK: - Content

    private func content(recap: BusinessLiveShareRecap) -> some View {
        VStack(spacing: 12) {
            if recap.walkEnded {
                RecapHero(recap: recap)
            }
            if let note = recap.walkerNote, !note.isEmpty {
                WalkerNoteCard(note: note)
            }
            if !recap.photos.isEmpty {
                RecapPhotosGallery(photos: recap.photos, accent: accentColor(for: recap))
            }
            if recap.walkEnded {
                BrandedThanksCard(recap: recap)
            }
        }
    }

    private func accentColor(for recap: BusinessLiveShareRecap) -> Color {
        if let hex = recap.orgBrandColour, let parsed = Color(hex6: hex) {
            return parsed
        }
        return AppColors.Dark.primary
    }
}

// MARK: - RecapHero

private struct RecapHero: View {
    let recap: BusinessLiveShareRecap

    private var dogName: String {
        recap.primaryDogName ?? "Your dog"
    }

    private var finishedAtCopy: String {
        // Prefer the walker's actual end-tap timestamp; fall back to
        // the scheduled end if the share was reaped before lastUpdated
        // bumped. Both are millis-since-epoch.
        let candidate = recap.lastUpdatedAt ?? recap.scheduledEndAt
        guard let millis = candidate, millis > 0 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000.0)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return " at \(formatter.string(from: date))"
    }

    private var accent: Color {
        if let hex = recap.orgBrandColour, let parsed = Color(hex6: hex) {
            return parsed
        }
        return AppColors.Dark.primary
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("🏡")
                .font(.system(size: 44))
            Text("\(dogName) is home")
                .font(.title3.bold())
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            if let walker = recap.walkerDisplayName, !walker.isEmpty {
                Text("\(walker) finished the walk\(finishedAtCopy).")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accent.opacity(0.0), lineWidth: 0)
        )
        // Brand-coloured top border — matches portal RecapHero.
        .overlay(
            VStack(spacing: 0) {
                Rectangle()
                    .fill(accent)
                    .frame(height: 4)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .allowsHitTesting(false)
        )
    }
}

// MARK: - Walker note

private struct WalkerNoteCard: View {
    let note: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "quote.bubble.fill")
                .foregroundColor(AppColors.Dark.primary)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text("From your walker")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                Text("\u{201C}\(note)\u{201D}")
                    .font(.body)
                    .foregroundColor(.primary)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Photos gallery

private struct RecapPhotosGallery: View {
    let photos: [BusinessLiveSharePhoto]
    let accent: Color

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Memories from the walk")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                Spacer()
                Text("\(photos.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(photos) { photo in
                    photoCell(photo)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGray6))
        )
    }

    private func photoCell(_ photo: BusinessLiveSharePhoto) -> some View {
        let urlString = photo.thumbnailUrl ?? photo.storageUrl
        let url = URL(string: urlString)
        return VStack(alignment: .leading, spacing: 4) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(ProgressView())
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        )
                @unknown default:
                    Rectangle().fill(Color(.systemGray5))
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(accent.opacity(0.25), lineWidth: 2)
            )
            if let caption = photo.caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Branded thanks

private struct BrandedThanksCard: View {
    let recap: BusinessLiveShareRecap

    private var accent: Color {
        if let hex = recap.orgBrandColour, let parsed = Color(hex6: hex) {
            return parsed
        }
        return AppColors.Dark.primary
    }

    private var brandName: String {
        if let name = recap.orgName, !name.isEmpty { return name }
        if let walker = recap.walkerDisplayName, !walker.isEmpty { return walker }
        return "your walker"
    }

    var body: some View {
        HStack(spacing: 12) {
            logoView
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text("Thanks from \(brandName)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                Text("See you next walk.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var logoView: some View {
        if let urlString = recap.orgLogoUrl, !urlString.isEmpty,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    fallbackLogo
                }
            }
        } else {
            fallbackLogo
        }
    }

    private var fallbackLogo: some View {
        ZStack {
            Rectangle()
                .fill(accent.opacity(0.18))
            Text("🐾")
                .font(.title2)
        }
    }
}

// MARK: - Color hex helper

private extension Color {
    /// Parse a "#RRGGBB" / "RRGGBB" hex string into a Color. Returns
    /// nil for malformed inputs so callers can fall back to the app
    /// accent. Mirrors the portal's tolerant brand-colour parsing.
    init?(hex6 raw: String) {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}
