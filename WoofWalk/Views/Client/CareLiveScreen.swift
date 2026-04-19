import SwiftUI

struct CareLiveScreen: View {
    let sessionId: String
    let serviceType: CareServiceType

    @StateObject private var viewModel: CareLiveViewModel
    @Environment(\.dismiss) private var dismiss

    init(sessionId: String, serviceType: CareServiceType) {
        self.sessionId = sessionId
        self.serviceType = serviceType
        _viewModel = StateObject(wrappedValue: CareLiveViewModel(sessionId: sessionId, serviceType: serviceType))
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
        .navigationTitle(serviceType.displayName)
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
                headerCard
                if serviceType == .boarding { dayCounterCard }
                taskCompletionCard
                moodCard
                feedingStatusCard
                if !viewModel.medications.isEmpty { medicationCard }
                if !viewModel.todayActivities.isEmpty { activityTimeline }
                if !viewModel.photos.isEmpty { photoGallery }
                contactCard
            }
            .padding(16)
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppColors.Dark.primaryContainer)
                    .frame(width: 56, height: 56)
                Image(systemName: serviceType.icon)
                    .font(.title2)
                    .foregroundColor(AppColors.Dark.onPrimaryContainer)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.sitterName)
                    .font(.body.bold())
                    .foregroundColor(AppColors.Dark.onSurface)
                Text("Caring for \(viewModel.dogName)")
                    .font(.subheadline)
                    .foregroundColor(AppColors.Dark.onSurfaceVariant)

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.success60)
                        .frame(width: 8, height: 8)
                    Text(viewModel.status == "active" ? "Active" : viewModel.status.capitalized)
                        .font(.caption.bold())
                        .foregroundColor(Color.success60)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    // MARK: - Day Counter (Boarding only)

    private var dayCounterCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Day \(viewModel.dayCount) of \(viewModel.totalDays)")
                    .font(.title3.bold())
                    .foregroundColor(AppColors.Dark.onSurface)
                Text("Boarding stay")
                    .font(.caption)
                    .foregroundColor(AppColors.Dark.onSurfaceVariant)
            }

            Spacer()

            // Day progress
            ZStack {
                Circle()
                    .stroke(AppColors.Dark.outlineVariant, lineWidth: 5)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: Double(viewModel.dayCount) / Double(viewModel.totalDays))
                    .stroke(AppColors.Dark.primary, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                Text("\(viewModel.dayCount)/\(viewModel.totalDays)")
                    .font(.caption.bold())
                    .foregroundColor(AppColors.Dark.onSurface)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.primary.opacity(0.12))
        )
    }

    // MARK: - Task Completion Ring

    private var taskCompletionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Tasks")
                .font(.headline)
                .foregroundColor(AppColors.Dark.onSurface)

            HStack(spacing: 20) {
                // Circular progress ring
                ZStack {
                    Circle()
                        .stroke(AppColors.Dark.outlineVariant, lineWidth: 8)
                        .frame(width: 80, height: 80)
                    Circle()
                        .trim(from: 0, to: viewModel.taskCompletionFraction)
                        .stroke(
                            viewModel.taskCompletionFraction >= 1.0 ? Color.success60 : AppColors.Dark.primary,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(viewModel.taskCompletionPercent)%")
                            .font(.title3.bold())
                            .foregroundColor(AppColors.Dark.onSurface)
                        Text("done")
                            .font(.caption2)
                            .foregroundColor(AppColors.Dark.onSurfaceVariant)
                    }
                }

                // Task list
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.tasks) { task in
                        HStack(spacing: 8) {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(task.isCompleted ? Color.success60 : AppColors.Dark.onSurfaceVariant)
                                .font(.subheadline)
                            Text(task.name)
                                .font(.caption)
                                .foregroundColor(
                                    task.isCompleted
                                        ? AppColors.Dark.onSurfaceVariant
                                        : AppColors.Dark.onSurface
                                )
                                .strikethrough(task.isCompleted)
                        }
                    }
                }

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    // MARK: - Mood Card

    private var moodCard: some View {
        HStack(spacing: 12) {
            Text(viewModel.moodEmoji)
                .font(.system(size: 40))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.dogName) is feeling \(viewModel.moodLabel)")
                    .font(.subheadline.bold())
                    .foregroundColor(AppColors.Dark.onSurface)
                if !viewModel.moodNote.isEmpty {
                    Text(viewModel.moodNote)
                        .font(.caption)
                        .foregroundColor(AppColors.Dark.onSurfaceVariant)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    // MARK: - Feeding Status

    private var feedingStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "fork.knife")
                    .foregroundColor(.orange60)
                Text("Feeding")
                    .font(.headline)
                    .foregroundColor(AppColors.Dark.onSurface)
            }

            if viewModel.feedings.isEmpty {
                Text("No meals scheduled yet")
                    .font(.caption)
                    .foregroundColor(AppColors.Dark.onSurfaceVariant)
            } else {
                ForEach(viewModel.feedings) { feeding in
                    HStack(spacing: 10) {
                        Image(systemName: feeding.isCompleted ? "checkmark.circle.fill" : "clock")
                            .foregroundColor(feeding.isCompleted ? Color.success60 : .orange60)
                            .font(.subheadline)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(feeding.mealName)
                                .font(.subheadline.bold())
                                .foregroundColor(AppColors.Dark.onSurface)
                            if feeding.isCompleted, let time = feeding.time {
                                Text("Fed at \(formatTime(time))")
                                    .font(.caption)
                                    .foregroundColor(AppColors.Dark.onSurfaceVariant)
                            } else {
                                Text("Pending")
                                    .font(.caption)
                                    .foregroundColor(.orange60)
                            }
                            if !feeding.notes.isEmpty {
                                Text(feeding.notes)
                                    .font(.caption2)
                                    .foregroundColor(AppColors.Dark.onSurfaceVariant)
                            }
                        }

                        Spacer()
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(feeding.isCompleted ? Color.success60.opacity(0.08) : Color.orange60.opacity(0.08))
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    // MARK: - Medication Card

    private var medicationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "pills.fill")
                    .foregroundColor(.error60)
                Text("Medication")
                    .font(.headline)
                    .foregroundColor(AppColors.Dark.onSurface)
            }

            ForEach(viewModel.medications) { med in
                HStack(spacing: 10) {
                    Image(systemName: med.isCompleted ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .foregroundColor(med.isCompleted ? Color.success60 : .error60)
                        .font(.subheadline)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(med.name)
                            .font(.subheadline.bold())
                            .foregroundColor(AppColors.Dark.onSurface)
                        Text(med.isCompleted ? "Administered" : "Pending")
                            .font(.caption)
                            .foregroundColor(med.isCompleted ? Color.success60 : .error60)
                    }

                    Spacer()

                    if let time = med.completedAt {
                        Text(formatTime(time))
                            .font(.caption)
                            .foregroundColor(AppColors.Dark.onSurfaceVariant)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(med.isCompleted ? Color.success60.opacity(0.08) : Color.error60.opacity(0.08))
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    // MARK: - Activity Timeline

    private var activityTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Activity")
                .font(.headline)
                .foregroundColor(AppColors.Dark.onSurface)

            ForEach(Array(viewModel.todayActivities.enumerated()), id: \.element.id) { index, activity in
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

                        if index < viewModel.todayActivities.count - 1 {
                            Rectangle()
                                .fill(AppColors.Dark.outlineVariant)
                                .frame(width: 2, height: 28)
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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    // MARK: - Photo Gallery

    private var photoGallery: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photos")
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

    // MARK: - Contact Card

    private var contactCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Call button
                Button {
                    if let phone = viewModel.sitterPhone, let url = URL(string: "tel:\(phone)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "phone.fill")
                            .font(.caption)
                        Text("Call")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(AppColors.Dark.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.Dark.primary, lineWidth: 1)
                    )
                }

                // Message button
                Button {
                    // Navigate to chat
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left.fill")
                            .font(.caption)
                        Text("Message")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(AppColors.Dark.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.Dark.primary)
                    )
                }
            }

            // Daily summary button
            if let summaryUrl = viewModel.dailySummaryUrl, !summaryUrl.isEmpty {
                Button {
                    if let url = URL(string: summaryUrl) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.fill")
                            .font(.caption)
                        Text("View Daily Summary")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(AppColors.Dark.onSurfaceVariant)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.Dark.outlineVariant, lineWidth: 1)
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
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
        CareLiveScreen(sessionId: "preview-123", serviceType: .boarding)
    }
    .preferredColorScheme(.dark)
}
