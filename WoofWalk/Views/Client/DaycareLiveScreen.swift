import SwiftUI

struct DaycareLiveScreen: View {
    let sessionId: String

    @StateObject private var viewModel: DaycareLiveViewModel
    @Environment(\.dismiss) private var dismiss

    init(sessionId: String) {
        self.sessionId = sessionId
        _viewModel = StateObject(wrappedValue: DaycareLiveViewModel(sessionId: sessionId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.error {
                errorView(error)
            } else {
                mainContent
            }
        }
        .background(AppColors.Dark.background)
        .navigationTitle("Daycare")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(AppColors.Dark.onSurface)
                }
            }
        }
        .toolbarBackground(AppColors.Dark.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .overlay(alignment: .bottom) {
            if let message = viewModel.snackbarMessage {
                snackbar(message: message)
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(AppColors.Dark.primary)
            Text("Loading session...")
                .font(.subheadline)
                .foregroundColor(AppColors.Dark.onSurfaceVariant)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(AppColors.Dark.onSurfaceVariant)
            Text(message)
                .font(.body)
                .foregroundColor(AppColors.Dark.onSurfaceVariant)
            Button("Go Back") { dismiss() }
                .font(.subheadline.bold())
                .foregroundColor(AppColors.Dark.onPrimary)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Capsule().fill(AppColors.Dark.primary))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                moodBanner
                sessionProgressBar
                if viewModel.isNapping { napCard }
                activityFeed
                if !viewModel.playSummaries.isEmpty { playSummaryCards }
                if !viewModel.photos.isEmpty { photoStream }
                if !viewModel.socialisationNotes.isEmpty { socialisationCard }
                pickupButton
            }
            .padding(16)
            .padding(.bottom, 60) // space for snackbar
        }
    }

    // MARK: - Mood Banner

    private var moodBanner: some View {
        HStack(spacing: 14) {
            Text(viewModel.moodEmoji)
                .font(.system(size: 48))

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.dogName)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                Text("Feeling \(viewModel.moodLabel)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                if !viewModel.moodNote.isEmpty {
                    Text(viewModel.moodNote)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.75))
                }
            }

            Spacer()

            VStack(spacing: 2) {
                Text(viewModel.statusDisplayText)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.2)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(viewModel.moodBannerColor)
        )
    }

    // MARK: - Session Progress Bar

    private var sessionProgressBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Session Progress")
                    .font(.subheadline.bold())
                    .foregroundColor(AppColors.Dark.onSurface)
                Spacer()
                Text("\(viewModel.sessionProgressPercent)%")
                    .font(.caption.bold())
                    .foregroundColor(AppColors.Dark.primary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppColors.Dark.outlineVariant)
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppColors.Dark.primary)
                        .frame(width: geometry.size.width * viewModel.sessionProgressFraction, height: 10)
                }
            }
            .frame(height: 10)

            HStack {
                if let checkIn = viewModel.checkInTime {
                    Text("Checked in \(formatTime(checkIn))")
                        .font(.caption2)
                        .foregroundColor(AppColors.Dark.onSurfaceVariant)
                }
                Spacer()
                if let pickup = viewModel.expectedPickupTime {
                    Text("Pickup \(formatTime(pickup))")
                        .font(.caption2)
                        .foregroundColor(AppColors.Dark.onSurfaceVariant)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    // MARK: - Nap Card

    private var napCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 32))
                .foregroundColor(Color(hex: 0x5C6BC0))

            VStack(alignment: .leading, spacing: 4) {
                Text("Shhh... sleeping")
                    .font(.body.bold())
                    .foregroundColor(AppColors.Dark.onSurface)
                Text("\(viewModel.dogName) has been napping for \(viewModel.napDurationString)")
                    .font(.caption)
                    .foregroundColor(AppColors.Dark.onSurfaceVariant)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: 0x5C6BC0).opacity(0.12))
        )
    }

    // MARK: - Activity Feed

    private var activityFeed: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Feed")
                .font(.headline)
                .foregroundColor(AppColors.Dark.onSurface)

            if viewModel.activities.isEmpty {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(AppColors.Dark.onSurfaceVariant)
                    Text("No activities recorded yet")
                        .font(.subheadline)
                        .foregroundColor(AppColors.Dark.onSurfaceVariant)
                }
                .padding(.vertical, 8)
            } else {
                ForEach(Array(viewModel.activities.prefix(10).enumerated()), id: \.element.id) { index, activity in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            ZStack {
                                Circle()
                                    .fill(activity.iconColor)
                                    .frame(width: 28, height: 28)
                                Image(systemName: activity.icon)
                                    .font(.caption2)
                                    .foregroundColor(.white)
                            }

                            if index < min(9, viewModel.activities.count - 1) {
                                Rectangle()
                                    .fill(AppColors.Dark.outlineVariant)
                                    .frame(width: 2, height: 24)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(activity.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(AppColors.Dark.onSurface)
                                Spacer()
                                Text(formatTime(activity.timestamp))
                                    .font(.caption2)
                                    .foregroundColor(AppColors.Dark.onSurfaceVariant)
                            }
                            if !activity.description.isEmpty {
                                Text(activity.description)
                                    .font(.caption)
                                    .foregroundColor(AppColors.Dark.onSurfaceVariant)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    // MARK: - Play Summary Cards

    private var playSummaryCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tennisball.fill")
                    .foregroundColor(.turquoise60)
                Text("Play Time")
                    .font(.headline)
                    .foregroundColor(AppColors.Dark.onSurface)
            }

            ForEach(viewModel.playSummaries) { play in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(play.groupName)
                            .font(.subheadline.bold())
                            .foregroundColor(AppColors.Dark.onSurface)
                        Spacer()
                        Text("\(play.duration) min")
                            .font(.caption.bold())
                            .foregroundColor(AppColors.Dark.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(AppColors.Dark.primary.opacity(0.15)))
                    }

                    if !play.playmates.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(play.playmates, id: \.self) { mate in
                                    Text(mate)
                                        .font(.caption2)
                                        .foregroundColor(AppColors.Dark.onSurfaceVariant)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule().fill(AppColors.Dark.outlineVariant.opacity(0.5))
                                        )
                                }
                            }
                        }
                    }

                    if !play.notes.isEmpty {
                        Text(play.notes)
                            .font(.caption)
                            .foregroundColor(AppColors.Dark.onSurfaceVariant)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.Dark.primaryContainer.opacity(0.3))
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    // MARK: - Photo Stream

    private var photoStream: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photo Stream")
                .font(.headline)
                .foregroundColor(AppColors.Dark.onSurface)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.photos) { photo in
                        VStack(spacing: 4) {
                            AsyncImage(url: URL(string: photo.url)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 140, height: 140)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                case .failure:
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppColors.Dark.outlineVariant)
                                        .frame(width: 140, height: 140)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundColor(AppColors.Dark.onSurfaceVariant)
                                        )
                                default:
                                    ProgressView()
                                        .frame(width: 140, height: 140)
                                }
                            }

                            if !photo.caption.isEmpty {
                                Text(photo.caption)
                                    .font(.caption2)
                                    .foregroundColor(AppColors.Dark.onSurfaceVariant)
                                    .lineLimit(1)
                                    .frame(width: 140)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    // MARK: - Socialisation Card

    private var socialisationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "dog.fill")
                    .foregroundColor(Color.success60)
                Text("Socialisation Notes")
                    .font(.headline)
                    .foregroundColor(AppColors.Dark.onSurface)
            }

            ForEach(viewModel.socialisationNotes) { note in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "pawprint.fill")
                        .font(.caption)
                        .foregroundColor(Color.success60)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.text)
                            .font(.subheadline)
                            .foregroundColor(AppColors.Dark.onSurface)
                        if let dog = note.dogInteracted {
                            Text("With \(dog)")
                                .font(.caption)
                                .foregroundColor(AppColors.Dark.primary)
                        }
                        Text(formatTime(note.timestamp))
                            .font(.caption2)
                            .foregroundColor(AppColors.Dark.onSurfaceVariant)
                    }

                    Spacer()
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.success60.opacity(0.08))
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    // MARK: - Pickup Button

    private var pickupButton: some View {
        Button {
            viewModel.requestPickup()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: viewModel.pickupRequested ? "checkmark.circle.fill" : "car.fill")
                Text(viewModel.pickupRequested ? "Pickup Requested" : "I'm On My Way")
                    .font(.subheadline.bold())
            }
            .foregroundColor(viewModel.pickupRequested ? AppColors.Dark.onSurfaceVariant : AppColors.Dark.onPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(viewModel.pickupRequested ? AppColors.Dark.surfaceVariant : AppColors.Dark.primary)
            )
        }
        .disabled(viewModel.pickupRequested)
    }

    // MARK: - Snackbar

    private func snackbar(message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.neutral30)
            )
            .padding(.bottom, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation { viewModel.snackbarMessage = nil }
                }
            }
    }

    // MARK: - Helpers

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DaycareLiveScreen(sessionId: "preview-123")
    }
    .preferredColorScheme(.dark)
}
